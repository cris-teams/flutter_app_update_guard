import 'dart:io';
import 'package:path/path.dart' as p;
import '../cli/command_runner.dart';
import '../cli/exit_codes.dart';
import '../config/guard_config.dart';
import '../exceptions/guard_exception.dart';
import '../models/simulation_result.dart';
import '../project/lockfile_reader.dart';
import '../project/project_detector.dart';
import '../project/pubspec_modifier.dart';
import '../project/pubspec_reader.dart';
import '../pub/pub_client.dart';

/// Service orchestrating dependency upgrade simulations inside sandboxed temp directories.
class SimulateCommandExecutor {
  final PubClient pubClient;
  final CommandRunner commandRunner;

  const SimulateCommandExecutor({
    required this.pubClient,
    required this.commandRunner,
  });

  /// Runs the simulation workflow for [packageName].
  Future<SimulationResult> simulate({
    required String workingDir,
    required String packageName,
    String? targetVersion,
    required GuardConfig config,
    bool? runTestsOverride,
    bool? keepTempOverride,
    Duration? timeout,
    bool verbose = false,
  }) async {
    // 1. Detect project files & resolve package current state
    final paths = ProjectDetector.detect(workingDir);
    final pubspecData = PubspecReader.read(paths.pubspecPath);
    final lockMap = LockfileReader.read(paths.lockfilePath);

    final lockEntry = lockMap[packageName];
    if (lockEntry == null) {
      throw GuardException(
        "Package '$packageName' is not currently resolved in pubspec.lock. Please run 'pub get' first.",
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    final currentVersionStr = lockEntry.version.toString();

    // 2. Resolve target version
    String resolvedTargetVersion;
    if (targetVersion != null) {
      resolvedTargetVersion = targetVersion;
    } else {
      try {
        final info = await pubClient.getPackage(packageName);
        resolvedTargetVersion = info.latestVersion.toString();
      } catch (e) {
        throw GuardException(
          "Failed to fetch latest version for package '$packageName' from pub.dev",
          exitCode: ExitCodes.apiError,
          details: e,
        );
      }
    }

    // 3. Determine if it is a Flutter project
    final hasFlutter = pubspecData.dependencies.any((d) => d.name == 'flutter' || d.name == 'flutter_test');
    final executable = hasFlutter ? 'flutter' : 'dart';

    // 4. Create temporary workspace
    final tempDir = Directory.systemTemp.createTempSync('update_guard_sim_');
    if (verbose) {
      print('Created temporary directory for simulation: ${tempDir.path}');
    }

    // 5. Copy project files safely (without following symlinks out of project, and avoiding massive cache dirs)
    try {
      _copyProjectFiles(paths.rootPath, tempDir.path);
    } catch (e) {
      _safeCleanup(tempDir);
      throw GuardException(
        'Failed to copy project files to temporary workspace',
        exitCode: ExitCodes.internalError,
        details: e,
      );
    }

    try {
      // 6. Sửa dependency constraint trong bản copy
      final tempPubspec = p.join(tempDir.path, 'pubspec.yaml');
      PubspecModifier.updateDependency(tempPubspec, packageName, resolvedTargetVersion);

      // 7. Chạy pub get
      final pubGetResult = await commandRunner.run(
        executable,
        ['pub', 'get'],
        workingDirectory: tempDir.path,
        timeout: timeout ?? Duration(seconds: config.simulation.timeoutSeconds),
      );

      CommandResult? analyzeResult;
      CommandResult? testResult;

      bool success = pubGetResult.exitCode == 0;

      // 8. Chạy analyze if pub get succeeded
      if (success && config.simulation.runAnalyze) {
        analyzeResult = await commandRunner.run(
          executable,
          ['analyze'],
          workingDirectory: tempDir.path,
          timeout: timeout ?? Duration(seconds: config.simulation.timeoutSeconds),
        );
        success = analyzeResult.exitCode == 0;
      }

      // 9. Chạy test if analyze succeeded and requested
      final shouldRunTests = runTestsOverride ?? config.simulation.runTests;
      if (success && shouldRunTests) {
        testResult = await commandRunner.run(
          executable,
          ['test'],
          workingDirectory: tempDir.path,
          timeout: timeout ?? Duration(seconds: config.simulation.timeoutSeconds),
        );
        success = testResult.exitCode == 0;
      }

      // 10. Determine if we keep the temp directory
      final keepTemp = keepTempOverride ?? (config.simulation.keepTempOnFailure && !success);

      if (!keepTemp) {
        _safeCleanup(tempDir);
      }

      return SimulationResult(
        packageName: packageName,
        currentVersion: currentVersionStr,
        targetVersion: resolvedTargetVersion,
        pubGetResult: pubGetResult,
        analyzeResult: analyzeResult,
        testResult: testResult,
        success: success,
        tempDirectoryKept: keepTemp,
        tempDirectory: keepTemp ? tempDir.path : null,
      );
    } catch (e) {
      _safeCleanup(tempDir);
      rethrow;
    }
  }

  void _copyProjectFiles(String source, String dest) {
    final srcDir = Directory(source);
    final canonicalSource = p.canonicalize(srcDir.absolute.path);

    // List of directories to skip
    final skipDirs = {'.dart_tool', 'build', '.git', '.idea', '.vscode', '.fvm', '.symlinks'};

    void copyRecursive(Directory currentDir, String targetParent) {
      final name = p.basename(currentDir.path);
      if (skipDirs.contains(name)) return;

      final destDir = Directory(p.join(targetParent, name));
      destDir.createSync(recursive: true);

      for (final entity in currentDir.listSync(recursive: false, followLinks: false)) {
        final canonicalEntity = p.canonicalize(entity.path);
        // Safety guard: do not follow absolute symlinks pointing outside project root
        if (!canonicalEntity.startsWith(canonicalSource)) {
          continue;
        }

        if (entity is Directory) {
          copyRecursive(entity, destDir.path);
        } else if (entity is File) {
          final destFile = File(p.join(destDir.path, p.basename(entity.path)));
          entity.copySync(destFile.path);
        }
      }
    }

    // Copy top-level files and allowed sub-directories
    for (final entity in srcDir.listSync(recursive: false, followLinks: false)) {
      final canonicalEntity = p.canonicalize(entity.path);
      if (!canonicalEntity.startsWith(canonicalSource)) {
        continue;
      }

      final name = p.basename(entity.path);
      if (entity is File) {
        // Only copy files like pubspec.yaml, pubspec.lock, config, etc.
        if (name == 'pubspec.yaml' || name == 'pubspec.lock' || name.endsWith('.yaml') || name.endsWith('.json')) {
          final destFile = File(p.join(dest, name));
          entity.copySync(destFile.path);
        }
      } else if (entity is Directory) {
        if (!skipDirs.contains(name)) {
          copyRecursive(entity, dest);
        }
      }
    }
  }

  void _safeCleanup(Directory tempDir) {
    try {
      final canonicalPath = p.canonicalize(tempDir.absolute.path);
      final canonicalSystemTemp = p.canonicalize(Directory.systemTemp.absolute.path);

      // Verify that path is indeed inside system temp before executing recursive deletes
      if (canonicalPath.startsWith(canonicalSystemTemp) && canonicalPath != canonicalSystemTemp) {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    } catch (_) {
      // Suppress cleanup failures to prevent masking execution results
    }
  }
}
