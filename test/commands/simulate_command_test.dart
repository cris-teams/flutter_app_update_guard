import 'dart:io';
import 'package:flutter_app_update_guard/src/cli/command_runner.dart';
import 'package:flutter_app_update_guard/src/commands/simulate_command.dart';
import 'package:flutter_app_update_guard/src/config/guard_config.dart';
import 'package:flutter_app_update_guard/src/models/pub_package_info.dart';
import 'package:flutter_app_update_guard/src/project/pubspec_modifier.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import '../cli/fake_command_runner.dart';
import '../fake_pub_client.dart';

void main() {
  group('PubspecModifier', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pubspec_mod_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('updates simple package version constraints safely', () {
      final yamlPath = p.join(tempDir.path, 'pubspec.yaml');
      File(yamlPath).writeAsStringSync('''
        name: my_test_app
        dependencies:
          dio: ^5.0.0 # some comment
          path: ^1.8.0
      ''');

      PubspecModifier.updateDependency(yamlPath, 'dio', '^6.0.0');

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('dio: ^6.0.0 # some comment'));
      expect(content, contains('path: ^1.8.0')); // unchanged
    });

    test('updates hosted map package version constraints safely', () {
      final yamlPath = p.join(tempDir.path, 'pubspec.yaml');
      File(yamlPath).writeAsStringSync('''
        name: my_test_app
        dependencies:
          dio:
            hosted: https://pub.dev
            version: ^5.0.0
          path: ^1.8.0
      ''');

      PubspecModifier.updateDependency(yamlPath, 'dio', '^6.0.0');

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('version: ^6.0.0'));
      expect(content, contains('path: ^1.8.0')); // unchanged
    });
  });

  group('SimulateCommandExecutor', () {
    late Directory tempProjectDir;
    late FakePubClient fakePubClient;

    setUp(() {
      tempProjectDir = Directory.systemTemp.createTempSync('sim_exec_test_');

      File(p.join(tempProjectDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: my_sim_app
        dependencies:
          dio: ^5.0.0
      ''');

      File(p.join(tempProjectDir.path, 'pubspec.lock')).writeAsStringSync('''
        packages:
          dio:
            dependency: "direct main"
            description:
              name: dio
              url: "https://pub.dev"
            source: hosted
            version: "5.0.0"
      ''');

      fakePubClient = FakePubClient({
        'dio': PubPackageInfo(
          name: 'dio',
          latestVersion: Version(6, 0, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
      });
    });

    tearDown(() {
      if (tempProjectDir.existsSync()) {
        tempProjectDir.deleteSync(recursive: true);
      }
    });

    test('runs simulation flow successfully when commands return 0 exit code', () async {
      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: 0, // all command passes
          stdout: 'Command executed successfully',
          stderr: '',
          duration: const Duration(milliseconds: 100),
          timedOut: false,
        );
      });

      final executor = SimulateCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final result = await executor.simulate(
        workingDir: tempProjectDir.path,
        packageName: 'dio',
        config: GuardConfig.defaultConfig(),
        runTestsOverride: true,
      );

      expect(result.success, isTrue);
      expect(result.targetVersion, equals('6.0.0'));
      expect(result.pubGetResult.exitCode, equals(0));
      expect(result.analyzeResult?.exitCode, equals(0));
      expect(result.testResult?.exitCode, equals(0));
    });

    test('fails simulation flow when analyze command fails', () async {
      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        final exitCode = args.contains('analyze') ? 1 : 0;
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: exitCode,
          stdout: exitCode == 0 ? 'Success' : 'Error in analysis',
          stderr: '',
          duration: const Duration(milliseconds: 50),
          timedOut: false,
        );
      });

      final executor = SimulateCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final result = await executor.simulate(
        workingDir: tempProjectDir.path,
        packageName: 'dio',
        config: GuardConfig.defaultConfig(),
      );

      expect(result.success, isFalse);
      expect(result.pubGetResult.exitCode, equals(0));
      expect(result.analyzeResult?.exitCode, equals(1));
    });
  });
}
