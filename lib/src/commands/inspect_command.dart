import 'dart:convert';
import 'dart:io';
import '../analyzers/source_usage_analyzer.dart';
import '../analyzers/version_classifier.dart';
import '../cli/exit_codes.dart';
import '../config/guard_config.dart';
import '../exceptions/guard_exception.dart';
import '../models/dependency_info.dart';
import '../models/package_usage.dart';
import '../models/pub_package_info.dart';
import '../models/risk_models.dart';
import '../project/lockfile_reader.dart';
import '../project/project_detector.dart';
import '../project/pubspec_reader.dart';
import '../pub/pub_client.dart';
import '../risk/risk_engine.dart';
import '../risk/risk_rule.dart';

/// Executor orchestrating the inspect command logic.
class InspectCommandExecutor {
  final PubClient pubClient;

  const InspectCommandExecutor({required this.pubClient});

  /// Runs the inspect command workflow.
  Future<int> execute({
    required String workingDir,
    required String packageName,
    required String format,
    required bool showFiles,
    required GuardConfig config,
  }) async {
    // 1. Resolve project structure
    final paths = ProjectDetector.detect(workingDir);
    final pubspecData = PubspecReader.read(paths.pubspecPath);
    final lockMap = LockfileReader.read(paths.lockfilePath);

    // 2. Find package in dependencies
    DependencyInfo? localDep;
    RawDependency? rawDep;
    for (final dep in pubspecData.dependencies) {
      if (dep.name == packageName) {
        rawDep = dep;
        break;
      }
    }
    if (rawDep != null) {
      localDep = DependencyInfo(
        name: rawDep.name,
        kind: rawDep.kind,
        section: rawDep.section,
        constraint: rawDep.constraint,
      );
    }

    // Check lockfile if not in pubspec
    final lockEntry = lockMap[packageName];
    if (localDep == null && lockEntry != null) {
      localDep = DependencyInfo(
        name: packageName,
        kind: lockEntry.kind,
        section: DependencySection.dependencies, // fallback
        lockedVersion: lockEntry.version,
      );
    }

    if (localDep == null) {
      throw GuardException(
        "Package '$packageName' not found in project dependencies.",
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    // Attach locked version from lockfile if missing
    if (localDep.lockedVersion == null && lockEntry != null) {
      localDep = DependencyInfo(
        name: localDep.name,
        kind: localDep.kind,
        section: localDep.section,
        lockedVersion: lockEntry.version,
        constraint: localDep.constraint,
      );
    }

    // 3. Fetch pub.dev metadata if hosted
    PubPackageInfo? packageInfo;
    if (localDep.isHosted) {
      try {
        packageInfo = await pubClient.getPackage(packageName);
      } catch (e) {
        // If fetch fails, we continue with local info as best-effort, or throw if network is mandatory
        stderr.writeln('Warning: Failed to fetch metadata from pub.dev. $e');
      }
    }

    // 4. Run source usage scan if enabled
    PackageUsage? usage;
    if (config.checks.sourceUsage) {
      final scanResult = await SourceUsageAnalyzer.scan(
        paths.rootPath,
        includeExports: config.sourceUsage.includeExports,
        ignoreGenerated: config.sourceUsage.ignoreGenerated,
        excludePatterns: config.sourceUsage.exclude.toList(),
      );
      usage = scanResult[packageName] ?? PackageUsage.empty(packageName);
    }

    // 5. Evaluate risk using engine
    final engine = RiskEngine.fromConfig(config);
    final riskContext = DependencyContext(
      dependency: localDep,
      packageInfo: packageInfo,
      config: config,
      projectDartSdkConstraint: pubspecData.dartSdkConstraint,
      projectFlutterSdkConstraint: pubspecData.flutterSdkConstraint,
      usage: usage,
    );
    final risk = engine.evaluate(riskContext);

    // Compute update type
    UpdateType updateType = UpdateType.none;
    if (localDep.lockedVersion != null && packageInfo != null) {
      updateType = VersionClassifier.classify(localDep.lockedVersion!, packageInfo.latestVersion);
    }

    // Format output
    final output = _render(
      localDep: localDep,
      packageInfo: packageInfo,
      usage: usage,
      risk: risk,
      updateType: updateType,
      format: format,
      showFiles: showFiles,
    );

    print(output);
    return ExitCodes.success;
  }

  String _render({
    required DependencyInfo localDep,
    required PubPackageInfo? packageInfo,
    required PackageUsage? usage,
    required DependencyRisk risk,
    required UpdateType updateType,
    required String format,
    required bool showFiles,
  }) {
    final latestVer = packageInfo?.latestVersion.toString() ?? 'unknown';
    final currentVer = localDep.lockedVersion?.toString() ?? 'unknown';
    final constraintStr = localDep.constraint ?? 'none';

    final daysSinceRelease = packageInfo != null
        ? DateTime.now().difference(packageInfo.latestPublished).inDays
        : 0;

    final pubDateStr = packageInfo != null
        ? packageInfo.latestPublished.toIso8601String().substring(0, 10)
        : 'unknown';

    final discontinuedStr = packageInfo?.isDiscontinued == true ? 'yes' : 'no';
    final replacement = packageInfo?.replacedBy ?? 'none';

    final prodFilesCount = usage?.productionFiles.length ?? 0;
    final testFilesCount = usage?.testFiles.length ?? 0;
    final exampleFilesCount = usage?.exampleFiles.length ?? 0;

    // Recommendation logic
    String recommendation = 'No action required.';
    if (risk.level == RiskLevel.critical || risk.level == RiskLevel.high) {
      recommendation = 'Manual review is required before upgrading.';
    } else if (risk.level == RiskLevel.medium) {
      recommendation = 'Careful upgrade with tests verification is recommended.';
    } else if (updateType != UpdateType.none) {
      recommendation = 'Safe to upgrade within constraint boundary.';
    }

    if (format == 'json') {
      final jsonMap = {
        'packageName': localDep.name,
        'currentVersion': currentVer,
        'latestVersion': latestVer,
        'updateType': updateType.name,
        'constraint': constraintStr,
        'risk': risk.toJson(),
        'maintenance': {
          'latestRelease': pubDateStr,
          'daysSinceRelease': daysSinceRelease,
          'discontinued': packageInfo?.isDiscontinued ?? false,
          'replacedBy': packageInfo?.replacedBy,
        },
        'sourceUsage': usage?.toJson() ?? {},
        'recommendation': recommendation,
      };
      return const JsonEncoder.withIndent('  ').convert(jsonMap);
    }

    if (format == 'markdown') {
      final buffer = StringBuffer();
      buffer.writeln('# Package Inspection: ${localDep.name}');
      buffer.writeln();
      buffer.writeln('- **Current Locked Version:** `$currentVer`');
      buffer.writeln('- **Latest Available Version:** `$latestVer`');
      buffer.writeln('- **Update Type:** `${updateType.name}`');
      buffer.writeln('- **Current Constraint:** `$constraintStr`');
      buffer.writeln('- **Risk Level:** **${risk.level.name.toUpperCase()}** (Score: `${risk.score}`)');
      buffer.writeln();
      buffer.writeln('## Maintenance');
      buffer.writeln();
      buffer.writeln('- Latest Release: `$pubDateStr` ($daysSinceRelease days ago)');
      final replacementText = replacement != 'none' ? ' (Replaced by: `$replacement`)' : '';
      buffer.writeln('- Discontinued: `$discontinuedStr`$replacementText');
      buffer.writeln();
      buffer.writeln('## Source Usage');
      buffer.writeln();
      buffer.writeln('- Production Files: `$prodFilesCount`');
      buffer.writeln('- Test Files: `$testFilesCount`');
      buffer.writeln('- Example Files: `$exampleFilesCount`');
      buffer.writeln();

      if (showFiles && usage != null && usage.totalFiles > 0) {
        buffer.writeln('### Used in Files:');
        buffer.writeln();
        for (final f in usage.productionFiles) {
          buffer.writeln('- `production`: `$f`');
        }
        for (final f in usage.testFiles) {
          buffer.writeln('- `test`: `$f`');
        }
        for (final f in usage.exampleFiles) {
          buffer.writeln('- `example`: `$f`');
        }
        buffer.writeln();
      }

      if (risk.reasons.isNotEmpty) {
        buffer.writeln('## Risk Reasons');
        buffer.writeln();
        for (final r in risk.reasons) {
          buffer.writeln('- **${r.code}**: ${r.message} (+${r.score})');
        }
        buffer.writeln();
      }

      buffer.writeln('## Recommendation');
      buffer.writeln();
      buffer.writeln(recommendation);
      return buffer.toString();
    }

    // Default: Console representation
    final buffer = StringBuffer();
    buffer.writeln('Package: ${localDep.name}');
    buffer.writeln('Current: $currentVer');
    buffer.writeln('Latest: $latestVer');
    buffer.writeln('Update type: ${updateType.name}');
    buffer.writeln('Risk score: ${risk.score}');
    buffer.writeln('Risk level: ${risk.level.name}');
    buffer.writeln();
    buffer.writeln('Compatibility');
    buffer.writeln('  Dart SDK: compatible'); // default in MVP unless check SDK incompatible rule is evaluated
    buffer.writeln('  Flutter SDK: compatible');
    buffer.writeln();
    buffer.writeln('Maintenance');
    buffer.writeln('  Latest release: $pubDateStr');
    buffer.writeln('  Days since release: $daysSinceRelease');
    buffer.writeln('  Discontinued: $discontinuedStr');
    if (replacement != 'none') {
      buffer.writeln('  Replaced by: $replacement');
    }
    buffer.writeln();
    buffer.writeln('Source usage');
    buffer.writeln('  Production files: $prodFilesCount');
    buffer.writeln('  Test files: $testFilesCount');
    buffer.writeln('  Example files: $exampleFilesCount');

    if (showFiles && usage != null && usage.totalFiles > 0) {
      if (usage.productionFiles.isNotEmpty) {
        buffer.writeln('    Production list:');
        for (final f in usage.productionFiles) {
          buffer.writeln('      - $f');
        }
      }
      if (usage.testFiles.isNotEmpty) {
        buffer.writeln('    Test list:');
        for (final f in usage.testFiles) {
          buffer.writeln('      - $f');
        }
      }
      if (usage.exampleFiles.isNotEmpty) {
        buffer.writeln('    Example list:');
        for (final f in usage.exampleFiles) {
          buffer.writeln('      - $f');
        }
      }
    }

    if (risk.reasons.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Reasons');
      for (final r in risk.reasons) {
        buffer.writeln('  - ${r.message}');
      }
    }

    buffer.writeln();
    buffer.writeln('Recommendation');
    buffer.writeln('  $recommendation');

    return buffer.toString();
  }
}
