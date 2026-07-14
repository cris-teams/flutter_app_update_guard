import 'dart:io';
import 'package:flutter_app_update_guard/src/cli/command_runner.dart';
import 'package:flutter_app_update_guard/src/cli/process_command_runner.dart';
import 'package:test/test.dart';
import 'fake_command_runner.dart';

void main() {
  group('ProcessCommandRunner', () {
    test('executes actual system commands successfully', () async {
      const runner = ProcessCommandRunner();
      final result = await runner.run(
        'dart',
        ['--version'],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, equals(0));
      expect(
        result.stdout.contains('Dart') || result.stderr.contains('Dart'),
        isTrue,
        reason: 'Version output: stdout="${result.stdout}" stderr="${result.stderr}"',
      );
      expect(result.timedOut, isFalse);
    });

    test('terminates and marks timed out when execution duration exceeds limit', () async {
      const runner = ProcessCommandRunner();
      final result = await runner.run(
        Platform.isWindows ? 'timeout' : 'sleep',
        Platform.isWindows ? ['2'] : ['2'],
        workingDirectory: Directory.current.path,
        timeout: const Duration(milliseconds: 200),
      );

      expect(result.timedOut, isTrue);
      expect(result.exitCode, equals(-1));
    });
  });

  group('FakeCommandRunner', () {
    test('returns pre-configured result correctly', () async {
      const mockResult = CommandResult(
        executable: 'dart',
        arguments: ['test'],
        exitCode: 42,
        stdout: 'fake out',
        stderr: 'fake err',
        duration: Duration.zero,
        timedOut: false,
      );

      final runner = FakeCommandRunner.withResult(mockResult);
      final result = await runner.run('dart', ['test'], workingDirectory: '.');

      expect(result.exitCode, equals(42));
      expect(result.stdout, equals('fake out'));
      expect(result.stderr, equals('fake err'));
    });
  });
}
