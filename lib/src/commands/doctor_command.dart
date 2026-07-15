import 'dart:io';
import 'package:yaml/yaml.dart';

import '../cli/command_runner.dart';
import '../cli/exit_codes.dart';

/// Executor running diagnostics for the environment and configuration.
class DoctorCommandExecutor {
  final CommandRunner commandRunner;

  const DoctorCommandExecutor({required this.commandRunner});

  /// Executes all doctor checks and prints the diagnostics.
  /// Returns `0` if all critical checks pass, or a non-zero exit code if any critical issues are found.
  Future<int> execute({
    required String workingDir,
    required String configPath,
  }) async {
    print('Flutter App Update Guard - Doctor\n');

    bool allPassed = true;

    // 1. Dart SDK Check
    print('[✓] Dart SDK:');
    print('    Version: ${Platform.version}');

    // 2. Project Files & Structure Check
    final pubspecFile = File(Platform.isWindows ? '$workingDir\\pubspec.yaml' : '$workingDir/pubspec.yaml');
    final lockFile = File(Platform.isWindows ? '$workingDir\\pubspec.lock' : '$workingDir/pubspec.lock');

    bool hasPubspec = pubspecFile.existsSync();
    bool hasLock = lockFile.existsSync();

    if (hasPubspec) {
      print('[✓] Project Workspace:');
      print('    Root: $workingDir');
      print('    pubspec.yaml: Found');
    } else {
      print('[✗] Project Workspace:');
      print('    Root: $workingDir');
      print('    pubspec.yaml: Not found (Critical: This tool must be run inside a Dart/Flutter project)');
      allPassed = false;
    }

    if (hasLock) {
      print('    pubspec.lock: Found');
    } else if (hasPubspec) {
      print('    pubspec.lock: Not found (Warning: Run "dart pub get" first to generate the lockfile)');
      allPassed = false;
    }

    // 3. Flutter SDK Check (Optional, depending on if it is a Flutter project)
    bool isFlutterProject = false;
    if (hasPubspec) {
      try {
        final content = pubspecFile.readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          final deps = yaml['dependencies'];
          final devDeps = yaml['dev_dependencies'];
          if ((deps is Map && deps.containsKey('flutter')) ||
              (devDeps is Map && devDeps.containsKey('flutter_test'))) {
            isFlutterProject = true;
          }
        }
      } catch (_) {
        // Skip yaml parsing errors here, handled in config check
      }
    }

    try {
      final flutterResult = await commandRunner.run(
        'flutter',
        ['--version'],
        workingDirectory: workingDir,
        timeout: const Duration(seconds: 5),
      );
      if (flutterResult.exitCode == 0) {
        final versionLine = flutterResult.stdout.split('\n').firstWhere(
              (line) => line.contains('Flutter'),
              orElse: () => flutterResult.stdout,
            );
        print('[✓] Flutter SDK:');
        print('    Version: ${versionLine.trim()}');
      } else {
        if (isFlutterProject) {
          print('[✗] Flutter SDK:');
          print('    Status: Installed but exited with code ${flutterResult.exitCode}');
          allPassed = false;
        } else {
          print('[-] Flutter SDK: Not found (Not required for non-Flutter project)');
        }
      }
    } catch (_) {
      if (isFlutterProject) {
        print('[✗] Flutter SDK:');
        print('    Status: Not found in PATH (Required for Flutter projects to simulate upgrades)');
        allPassed = false;
      } else {
        print('[-] Flutter SDK: Not found in PATH (Not required for non-Flutter project)');
      }
    }

    // 4. Internet & pub.dev Connection Check
    try {
      final result = await InternetAddress.lookup('pub.dev').timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        print('[✓] Internet Connection:');
        print('    pub.dev DNS resolution: Connected');
      } else {
        print('[✗] Internet Connection:');
        print('    pub.dev DNS resolution: Failed (Empty response)');
        allPassed = false;
      }
    } catch (e) {
      print('[✗] Internet Connection:');
      print('    pub.dev DNS resolution: Offline or unreachable ($e)');
      allPassed = false;
    }

    // 5. Configuration File Check
    final configFile = File(configPath);
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          print('[✓] Configuration File:');
          print('    Path: $configPath');
          print('    Status: Valid YAML structure');
        } else {
          print('[✗] Configuration File:');
          print('    Path: $configPath');
          print('    Status: Invalid YAML structure (Root must be a map)');
          allPassed = false;
        }
      } catch (e) {
        print('[✗] Configuration File:');
        print('    Path: $configPath');
        print('    Status: Parsing failed ($e)');
        allPassed = false;
      }
    } else {
      print('[✓] Configuration File:');
      print('    Path: $configPath');
      print('    Status: Not found (Using default settings)');
    }

    print('\nStatus: ${allPassed ? 'All checks passed successfully!' : 'Some checks failed. Please review issues above.'}');
    return allPassed ? ExitCodes.success : ExitCodes.invalidConfig;
  }
}
