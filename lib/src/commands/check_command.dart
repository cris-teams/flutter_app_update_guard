import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import '../analyzers/version_classifier.dart';
import '../config/guard_config.dart';
import '../exceptions/guard_exception.dart';
import '../models/dependency_info.dart';
import '../models/dependency_report.dart';
import '../models/project_report.dart';
import '../models/risk_models.dart';
import '../project/lockfile_reader.dart';
import '../project/project_detector.dart';
import '../project/pubspec_reader.dart';
import '../pub/pub_client.dart';
import '../risk/risk_engine.dart';
import '../risk/risk_rule.dart';

/// Runner orchestrating the update safety verification.
class CheckCommandExecutor {
  final PubClient pubClient;

  const CheckCommandExecutor({required this.pubClient});

  /// Executes the check logic on the target directory.
  Future<ProjectReport> execute({
    required String workingDir,
    required GuardConfig config,
    bool verbose = false,
  }) async {
    // 1. Detect project files
    final paths = ProjectDetector.detect(workingDir);

    // 2. Read pubspec.yaml
    final pubspecData = PubspecReader.read(paths.pubspecPath);

    // 3. Read pubspec.lock
    final lockMap = LockfileReader.read(paths.lockfilePath);

    // 4. Resolve dependencies
    final resolvedDependencies = <DependencyInfo>[];
    for (final raw in pubspecData.dependencies) {
      final lockEntry = lockMap[raw.name];

      // Determine dependency kind from lockfile if available, fallback to pubspec
      final kind = lockEntry?.kind ?? raw.kind;
      final lockedVersion = lockEntry?.version;

      resolvedDependencies.add(DependencyInfo(
        name: raw.name,
        kind: kind,
        section: raw.section,
        constraint: raw.constraint,
        lockedVersion: lockedVersion,
      ));
    }

    final reports = <DependencyReport>[];

    // 5. Evaluate dependencies (in parallel for performance)
    final evaluationTasks = resolvedDependencies.map((dep) async {
      // Handle skip: non-hosted dependencies
      if (!dep.isHosted) {
        return DependencyReport(
          dependency: dep,
          updateType: UpdateType.none,
          risk: DependencyRisk.safe(),
          isSkipped: true,
          skipReason: 'Not a hosted pub.dev dependency (${dep.kind.name})',
          sdkCompatibility: SdkCompatibility.unknown,
        );
      }

      // Handle skip: ignored packages
      if (config.ignore.packages.contains(dep.name)) {
        return DependencyReport(
          dependency: dep,
          updateType: UpdateType.none,
          risk: DependencyRisk.safe(),
          isSkipped: true,
          skipReason: 'Ignored in configuration file',
          sdkCompatibility: SdkCompatibility.unknown,
        );
      }

      // Handle skip: dependency missing version in lockfile
      if (dep.lockedVersion == null) {
        return DependencyReport(
          dependency: dep,
          updateType: UpdateType.none,
          risk: DependencyRisk.safe(),
          isSkipped: true,
          skipReason: 'No locked version found in pubspec.lock. Run "dart pub get".',
          sdkCompatibility: SdkCompatibility.unknown,
        );
      }

      try {
        // Query pub.dev
        final info = await pubClient.getPackage(dep.name);

        // Classify update type
        final updateType = VersionClassifier.classify(dep.lockedVersion!, info.latestVersion);

        // Analyze SDK compatibility
        final sdkCompatibility = _evaluateSdkCompatibility(
          projectDart: pubspecData.dartSdkConstraint,
          projectFlutter: pubspecData.flutterSdkConstraint,
          pkgDart: info.dartSdkConstraint,
          pkgFlutter: info.flutterSdkConstraint,
        );

        // Build evaluation context and run risk engine
        final context = DependencyContext(
          dependency: dep,
          packageInfo: info,
          config: config,
          projectDartSdkConstraint: pubspecData.dartSdkConstraint,
          projectFlutterSdkConstraint: pubspecData.flutterSdkConstraint,
        );

        final riskEngine = RiskEngine.fromConfig(config);
        final risk = riskEngine.evaluate(context);

        return DependencyReport(
          dependency: dep,
          latestVersion: info.latestVersion,
          updateType: updateType,
          risk: risk,
          isSkipped: false,
          sdkCompatibility: sdkCompatibility,
        );
      } on GuardException catch (e) {
        // If package not found on pub.dev, don't crash, skip it
        if (verbose) {
          stderr.writeln('Warning: Failed to evaluate package ${dep.name}. ${e.message}');
        }
        return DependencyReport(
          dependency: dep,
          updateType: UpdateType.none,
          risk: DependencyRisk.safe(),
          isSkipped: true,
          skipReason: 'API lookup error: ${e.message}',
          sdkCompatibility: SdkCompatibility.unknown,
        );
      } catch (e) {
        if (verbose) {
          stderr.writeln('Warning: Unexpected error evaluating package ${dep.name}: $e');
        }
        return DependencyReport(
          dependency: dep,
          updateType: UpdateType.none,
          risk: DependencyRisk.safe(),
          isSkipped: true,
          skipReason: 'API lookup error',
          sdkCompatibility: SdkCompatibility.unknown,
        );
      }
    });

    final results = await Future.wait(evaluationTasks);
    reports.addAll(results);

    // 6. Evaluate project policies and warnings
    final policyViolations = <String>[];
    final warnings = <String>[];
    int criticalCount = 0;

    for (final r in reports) {
      if (r.isSkipped) continue;

      final riskLevel = r.risk.level;

      // Fail on specific risk level configuration
      if (config.risk.failOn.contains(riskLevel)) {
        policyViolations.add(
          "Package '${r.dependency.name}' has prohibited risk level '${riskLevel.name}' (score: ${r.risk.score})",
        );
      }

      // Warn on specific risk level configuration
      if (config.risk.warnOn.contains(riskLevel)) {
        warnings.add(
          "Package '${r.dependency.name}' has warned risk level '${riskLevel.name}' (score: ${r.risk.score})",
        );
      }

      if (riskLevel == RiskLevel.critical) {
        criticalCount++;
      }

      // Policy: fail_on_discontinued
      if (config.policies.failOnDiscontinued && (r.risk.reasons.any((reason) => reason.code == 'DISCONTINUED_PACKAGE'))) {
        policyViolations.add("Package '${r.dependency.name}' has discontinued policy violation");
      }

      // Policy: allow_prerelease
      if (!config.policies.allowPrerelease && r.updateType == UpdateType.prerelease) {
        policyViolations.add("Package '${r.dependency.name}' has prohibited pre-release update");
      }

      // Policy: allow_major_updates
      if (!config.policies.allowMajorUpdates && r.updateType == UpdateType.major) {
        policyViolations.add("Package '${r.dependency.name}' has prohibited major version update");
      }
    }

    // Policy: max_critical_dependencies
    if (criticalCount > config.policies.maxCriticalDependencies) {
      policyViolations.add(
        'Critical risk dependency count ($criticalCount) exceeds the limit of ${config.policies.maxCriticalDependencies}',
      );
    }

    return ProjectReport(
      projectName: pubspecData.projectName,
      generatedAt: DateTime.now(),
      dependencies: reports,
      policyViolations: policyViolations,
      warnings: warnings,
    );
  }

  SdkCompatibility _evaluateSdkCompatibility({
    String? projectDart,
    String? projectFlutter,
    String? pkgDart,
    String? pkgFlutter,
  }) {
    final bool hasDartMetadata = projectDart != null && pkgDart != null;
    final bool hasFlutterMetadata = projectFlutter != null && pkgFlutter != null;

    if (!hasDartMetadata && !hasFlutterMetadata) {
      return SdkCompatibility.unknown;
    }

    try {
      if (hasDartMetadata) {
        final proj = VersionConstraint.parse(projectDart);
        final pkg = VersionConstraint.parse(pkgDart);
        if (proj.intersect(pkg).isEmpty) {
          return SdkCompatibility.incompatible;
        }
      }

      if (hasFlutterMetadata) {
        final proj = VersionConstraint.parse(projectFlutter);
        final pkg = VersionConstraint.parse(pkgFlutter);
        if (proj.intersect(pkg).isEmpty) {
          return SdkCompatibility.incompatible;
        }
      }

      return SdkCompatibility.compatible;
    } catch (_) {
      return SdkCompatibility.unknown;
    }
  }
}
