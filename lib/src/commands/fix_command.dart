import 'dart:io';
import 'package:path/path.dart' as p;

import '../analyzers/version_classifier.dart';
import '../analyzers/workspace_analyzer.dart';
import '../cli/command_runner.dart';
import '../cli/exit_codes.dart';
import '../config/guard_config.dart';
import '../exceptions/guard_exception.dart';
import '../models/dependency_report.dart';
import '../models/risk_models.dart';
import '../project/project_detector.dart';
import '../project/pubspec_modifier.dart';
import '../project/pubspec_reader.dart';
import '../pub/pub_client.dart';
import 'check_command.dart';

/// Command executor to automatically update safe dependencies and run pub get.
class FixCommandExecutor {
  final PubClient pubClient;
  final CommandRunner commandRunner;

  const FixCommandExecutor({
    required this.pubClient,
    required this.commandRunner,
  });

  /// Executes the fix logic on the target directory.
  Future<int> execute({
    required String workingDir,
    required GuardConfig config,
    bool workspaceMode = false,
    bool dryRun = false,
    bool exact = false,
    bool verbose = false,
  }) async {
    // 1. Determine target projects to fix
    final targetDirs = <String>[];
    if (workspaceMode) {
      final projects = WorkspaceAnalyzer.discoverProjects(
        workingDir,
        maxDepth: config.workspace.maxDepth,
        excludePatterns: config.workspace.exclude.toList(),
      );
      for (final proj in projects) {
        targetDirs.add(p.join(workingDir, proj.relativePath));
      }
    } else {
      targetDirs.add(workingDir);
    }

    bool anyModified = false;

    for (final dir in targetDirs) {
      final modified = await _fixProject(
        workingDir: dir,
        config: config,
        dryRun: dryRun,
        exact: exact,
        verbose: verbose,
      );
      if (modified) {
        anyModified = true;
      }
    }

    if (dryRun) {
      print('\n[Dry Run] Completed. No files were modified.');
    } else {
      if (anyModified) {
        print('\nFix execution completed successfully.');
      } else {
        print('\nNo modifications were needed.');
      }
    }

    return ExitCodes.success;
  }

  /// Fixes a single project directory. Returns true if any updates were applied/proposed.
  Future<bool> _fixProject({
    required String workingDir,
    required GuardConfig config,
    required bool dryRun,
    required bool exact,
    required bool verbose,
  }) async {
    // Detect project files
    final paths = ProjectDetector.detect(workingDir);
    
    // Evaluate current risk status of dependencies
    final checker = CheckCommandExecutor(pubClient: pubClient);
    final report = await checker.execute(
      workingDir: workingDir,
      config: config,
      verbose: verbose,
    );

    final toUpdate = <DependencyReport>[];
    final skippedWithReason = <DependencyReport, String>{};

    for (final r in report.dependencies) {
      if (r.isSkipped) continue;

      // Only check packages with updates
      if (r.updateType == UpdateType.none || r.latestVersion == null) {
        continue;
      }

      final risk = r.risk;

      // Rule 1: Prohibited risk level in risk.failOn
      if (config.risk.failOn.contains(risk.level)) {
        skippedWithReason[r] = "Prohibited risk level '${risk.level.name}' (score: ${risk.score})";
        continue;
      }

      // Rule 2: Policy allow_prerelease
      if (!config.policies.allowPrerelease && r.updateType == UpdateType.prerelease) {
        // If current locked version is not a pre-release
        if (r.dependency.lockedVersion == null || !r.dependency.lockedVersion!.isPreRelease) {
          skippedWithReason[r] = "Pre-release updates not allowed";
          continue;
        }
      }

      // Rule 3: Policy allow_major_updates
      if (!config.policies.allowMajorUpdates && r.updateType == UpdateType.major) {
        skippedWithReason[r] = "Major updates not allowed";
        continue;
      }

      // Rule 4: Policy fail_on_discontinued
      if (config.policies.failOnDiscontinued &&
          risk.reasons.any((reason) => reason.code == 'DISCONTINUED' || reason.code == 'DISCONTINUED_PACKAGE')) {
        skippedWithReason[r] = "Package is discontinued";
        continue;
      }

      // Rule 5: Policy fail_on_sdk_incompatible
      if (config.policies.failOnSdkIncompatible &&
          risk.reasons.any((reason) =>
              reason.code == 'SDK_INCOMPATIBLE' ||
              reason.code == 'DART_SDK_INCOMPATIBLE' ||
              reason.code == 'FLUTTER_SDK_INCOMPATIBLE')) {
        skippedWithReason[r] = "SDK incompatible";
        continue;
      }

      toUpdate.add(r);
    }

    final relativeDir = p.relative(workingDir);
    final displayDir = relativeDir == '.' || relativeDir.isEmpty ? 'Root Project' : relativeDir;

    if (toUpdate.isEmpty) {
      print('\n[$displayDir] No safe dependency updates available.');
      if (skippedWithReason.isNotEmpty) {
        print('Skipped updates due to security policies:');
        for (final entry in skippedWithReason.entries) {
          final r = entry.key;
          print('  - ${r.dependency.name}: ${r.dependency.lockedVersion} -> ${r.latestVersion} (${entry.value})');
        }
      }
      return false;
    }

    print('\n[$displayDir] Found ${toUpdate.length} safe package updates:');
    for (final r in toUpdate) {
      print('  - ${r.dependency.name}: ${r.dependency.lockedVersion} -> ${r.latestVersion}');
    }

    if (skippedWithReason.isNotEmpty) {
      print('Skipped unsafe/prohibited updates:');
      for (final entry in skippedWithReason.entries) {
        final r = entry.key;
        print('  - ${r.dependency.name}: ${r.dependency.lockedVersion} -> ${r.latestVersion} (${entry.value})');
      }
    }

    if (dryRun) {
      return true;
    }

    // Apply updates to pubspec.yaml
    for (final r in toUpdate) {
      final currentConstraint = r.dependency.constraint;
      String newConstraint;
      if (exact) {
        newConstraint = '${r.latestVersion}';
      } else {
        final hasCaret = currentConstraint != null && currentConstraint.startsWith('^');
        final isExact = currentConstraint != null && RegExp(r'^\d').hasMatch(currentConstraint);
        
        if (hasCaret) {
          newConstraint = '^${r.latestVersion}';
        } else if (isExact) {
          newConstraint = '${r.latestVersion}';
        } else {
          newConstraint = '^${r.latestVersion}';
        }
      }
      
      PubspecModifier.updateDependency(paths.pubspecPath, r.dependency.name, newConstraint);
    }

    print('Updated pubspec.yaml constraints.');

    // Run pub get
    final pubspecData = PubspecReader.read(paths.pubspecPath);
    final hasFlutter = pubspecData.dependencies.any((d) => d.name == 'flutter' || d.name == 'flutter_test');
    final executable = hasFlutter ? 'flutter' : 'dart';

    print('Running "$executable pub get" in $workingDir...');
    final result = await commandRunner.run(
      executable,
      ['pub', 'get'],
      workingDirectory: workingDir,
    );

    if (result.exitCode == 0) {
      print('Successfully ran "$executable pub get".');
    } else {
      stderr.writeln('Error: "$executable pub get" failed with exit code ${result.exitCode}');
      if (result.stderr.isNotEmpty) {
        stderr.writeln(result.stderr);
      }
      throw GuardException('pub get failed', exitCode: ExitCodes.simulationFailed);
    }

    return true;
  }
}
