import 'dart:async';
import 'dart:io';
import 'package:flutter_app_update_guard/src/cli/command_runner.dart';
import 'package:flutter_app_update_guard/src/cli/exit_codes.dart';
import 'package:flutter_app_update_guard/src/commands/doctor_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../cli/fake_command_runner.dart';

void main() {
  group('DoctorCommandExecutor', () {
    late Directory tempDir;
    late FakeCommandRunner successRunner;
    late FakeCommandRunner failureRunner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('doctor_test_');

      successRunner = FakeCommandRunner.withResult(
        CommandResult(
          executable: 'flutter',
          arguments: ['--version'],
          exitCode: 0,
          stdout: 'Flutter 3.22.0 • channel stable',
          stderr: '',
          duration: Duration.zero,
          timedOut: false,
        ),
      );

      failureRunner = FakeCommandRunner.withResult(
        CommandResult(
          executable: 'flutter',
          arguments: ['--version'],
          exitCode: 1,
          stdout: '',
          stderr: 'not found',
          duration: Duration.zero,
          timedOut: false,
        ),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('passes successfully when all files and dependencies are valid', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: doctor_test_app
        environment:
          sdk: '>=3.0.0 <4.0.0'
        dependencies:
          flutter:
            sdk: flutter
      ''');
      File(p.join(tempDir.path, 'pubspec.lock')).writeAsStringSync('''
        packages:
          flutter:
            dependency: "direct main"
            source: sdk
            version: "0.0.0"
      ''');

      final executor = DoctorCommandExecutor(commandRunner: successRunner);
      final prints = <String>[];

      final exitCode = await runZoned(() async {
        return await executor.execute(
          workingDir: tempDir.path,
          configPath: p.join(tempDir.path, 'flutter_app_update_guard.yaml'), // Not found, using default
        );
      }, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          prints.add(line);
        },
      ));

      expect(exitCode, equals(ExitCodes.success));
      expect(prints.any((l) => l.contains('Dart SDK:')), isTrue);
      expect(prints.any((l) => l.contains('Flutter SDK:')), isTrue);
      expect(prints.any((l) => l.contains('pubspec.yaml: Found')), isTrue);
      expect(prints.any((l) => l.contains('pubspec.lock: Found')), isTrue);
      expect(prints.any((l) => l.contains('All checks passed successfully!')), isTrue);
    });

    test('fails when pubspec.yaml is missing', () async {
      // Empty directory
      final executor = DoctorCommandExecutor(commandRunner: successRunner);
      final prints = <String>[];

      final exitCode = await runZoned(() async {
        return await executor.execute(
          workingDir: tempDir.path,
          configPath: p.join(tempDir.path, 'flutter_app_update_guard.yaml'),
        );
      }, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          prints.add(line);
        },
      ));

      expect(exitCode, equals(ExitCodes.invalidConfig));
      expect(prints.any((l) => l.contains('pubspec.yaml: Not found')), isTrue);
      expect(prints.any((l) => l.contains('Some checks failed')), isTrue);
    });

    test('fails when configuration file is invalid YAML', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: doctor_test_app
        environment:
          sdk: '>=3.0.0 <4.0.0'
      ''');
      File(p.join(tempDir.path, 'pubspec.lock')).writeAsStringSync('''
        packages: {}
      ''');

      final configPath = p.join(tempDir.path, 'flutter_app_update_guard.yaml');
      File(configPath).writeAsStringSync('invalid_yaml: : [unbalanced');

      final executor = DoctorCommandExecutor(commandRunner: successRunner);
      final prints = <String>[];

      final exitCode = await runZoned(() async {
        return await executor.execute(
          workingDir: tempDir.path,
          configPath: configPath,
        );
      }, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          prints.add(line);
        },
      ));

      expect(exitCode, equals(ExitCodes.invalidConfig));
      expect(prints.any((l) => l.contains('Status: Parsing failed') || l.contains('Status: Invalid YAML')), isTrue);
      expect(prints.any((l) => l.contains('Some checks failed')), isTrue);
    });
  });
}
