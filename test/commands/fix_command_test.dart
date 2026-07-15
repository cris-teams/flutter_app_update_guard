import 'dart:io';
import 'package:flutter_app_update_guard/src/cli/command_runner.dart';
import 'package:flutter_app_update_guard/src/commands/fix_command.dart';
import 'package:flutter_app_update_guard/src/config/guard_config.dart';
import 'package:flutter_app_update_guard/src/models/pub_package_info.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import '../cli/fake_command_runner.dart';
import '../fake_pub_client.dart';

void main() {
  group('FixCommandExecutor', () {
    late Directory tempProjectDir;
    late FakePubClient fakePubClient;
    late List<String> commandsRun;

    setUp(() {
      tempProjectDir = Directory.systemTemp.createTempSync('fix_exec_test_');
      commandsRun = [];

      File(p.join(tempProjectDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: my_fix_app
        dependencies:
          dio: ^5.0.0
          path: ^1.8.0
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
          path:
            dependency: "direct main"
            description:
              name: path
              url: "https://pub.dev"
            source: hosted
            version: "1.8.0"
      ''');
    });

    tearDown(() {
      if (tempProjectDir.existsSync()) {
        tempProjectDir.deleteSync(recursive: true);
      }
    });

    test('updates safe package version constraints and runs pub get', () async {
      // dio has a minor update (5.1.0) which is safe
      // path has a major update (2.0.0) which is blocked by default policy
      fakePubClient = FakePubClient({
        'dio': PubPackageInfo(
          name: 'dio',
          latestVersion: Version(5, 1, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
        'path': PubPackageInfo(
          name: 'path',
          latestVersion: Version(2, 0, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
      });

      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        commandsRun.add('$exec ${args.join(' ')}');
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: 0,
          stdout: 'Command executed successfully',
          stderr: '',
          duration: const Duration(milliseconds: 10),
          timedOut: false,
        );
      });

      final executor = FixCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final exitCode = await executor.execute(
        workingDir: tempProjectDir.path,
        config: GuardConfig.defaultConfig(), // allowMajorUpdates is false by default
        dryRun: false,
      );

      expect(exitCode, equals(0));

      final content = File(p.join(tempProjectDir.path, 'pubspec.yaml')).readAsStringSync();
      // dio should be upgraded to ^5.1.0
      expect(content, contains('dio: ^5.1.0'));
      // path should NOT be upgraded since it is a major update
      expect(content, contains('path: ^1.8.0'));

      // Verify that pub get was run
      expect(commandsRun, hasLength(1));
      expect(commandsRun.first, contains('pub get'));
    });

    test('does not modify pubspec.yaml nor run pub get with dry-run', () async {
      fakePubClient = FakePubClient({
        'dio': PubPackageInfo(
          name: 'dio',
          latestVersion: Version(5, 1, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
      });

      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        commandsRun.add('$exec ${args.join(' ')}');
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: 0,
          stdout: 'Success',
          stderr: '',
          duration: const Duration(milliseconds: 10),
          timedOut: false,
        );
      });

      final executor = FixCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final exitCode = await executor.execute(
        workingDir: tempProjectDir.path,
        config: GuardConfig.defaultConfig(),
        dryRun: true,
      );

      expect(exitCode, equals(0));

      final content = File(p.join(tempProjectDir.path, 'pubspec.yaml')).readAsStringSync();
      // Should remain unchanged
      expect(content, contains('dio: ^5.0.0'));
      // No commands should be run
      expect(commandsRun, isEmpty);
    });

    test('skips updates that violate security/risk policies', () async {
      // dio has a minor update, but is discontinued or has critical risk level
      fakePubClient = FakePubClient({
        'dio': PubPackageInfo(
          name: 'dio',
          latestVersion: Version(5, 1, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: true, // discontinued violation
        ),
      });

      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        commandsRun.add('$exec ${args.join(' ')}');
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: 0,
          stdout: 'Success',
          stderr: '',
          duration: const Duration(milliseconds: 10),
          timedOut: false,
        );
      });

      final executor = FixCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final exitCode = await executor.execute(
        workingDir: tempProjectDir.path,
        config: GuardConfig.defaultConfig(), // failOnDiscontinued is true by default
        dryRun: false,
      );

      expect(exitCode, equals(0));

      final content = File(p.join(tempProjectDir.path, 'pubspec.yaml')).readAsStringSync();
      // Should NOT be updated because it is discontinued
      expect(content, contains('dio: ^5.0.0'));
      expect(commandsRun, isEmpty);
    });

    test('respects original exact constraint format when exact parameter is false', () async {
      File(p.join(tempProjectDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: my_fix_app
        dependencies:
          dio: 5.0.0
          path: ^1.8.0
      ''');

      fakePubClient = FakePubClient({
        'dio': PubPackageInfo(
          name: 'dio',
          latestVersion: Version(5, 1, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
      });

      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: 0,
          stdout: 'Success',
          stderr: '',
          duration: const Duration(milliseconds: 10),
          timedOut: false,
        );
      });

      final executor = FixCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final exitCode = await executor.execute(
        workingDir: tempProjectDir.path,
        config: GuardConfig.defaultConfig(),
        dryRun: false,
        exact: false,
      );

      expect(exitCode, equals(0));

      final content = File(p.join(tempProjectDir.path, 'pubspec.yaml')).readAsStringSync();
      // dio had exact constraint "5.0.0", so it should update to exact "5.1.0"
      expect(content, contains('dio: 5.1.0'));
      // path had caret "^1.8.0", and no update was made to it, but it should stay ^1.8.0
      expect(content, contains('path: ^1.8.0'));
    });

    test('forces exact constraint format for all packages when exact parameter is true', () async {
      File(p.join(tempProjectDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: my_fix_app
        dependencies:
          dio: ^5.0.0
          path: ^1.8.0
      ''');

      fakePubClient = FakePubClient({
        'dio': PubPackageInfo(
          name: 'dio',
          latestVersion: Version(5, 1, 0),
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
      });

      final fakeRunner = FakeCommandRunner((exec, args, workingDir) async {
        return CommandResult(
          executable: exec,
          arguments: args,
          exitCode: 0,
          stdout: 'Success',
          stderr: '',
          duration: const Duration(milliseconds: 10),
          timedOut: false,
        );
      });

      final executor = FixCommandExecutor(
        pubClient: fakePubClient,
        commandRunner: fakeRunner,
      );

      final exitCode = await executor.execute(
        workingDir: tempProjectDir.path,
        config: GuardConfig.defaultConfig(),
        dryRun: false,
        exact: true,
      );

      expect(exitCode, equals(0));

      final content = File(p.join(tempProjectDir.path, 'pubspec.yaml')).readAsStringSync();
      // dio had caret "^5.0.0", but exact is true, so it must update to exact "5.1.0" without caret
      expect(content, contains('dio: 5.1.0'));
    });
  });
}
