import 'dart:io';

import 'package:flutter_app_update_guard/src/cli/app_runner.dart';
import 'package:flutter_app_update_guard/src/cli/exit_codes.dart';
import 'package:flutter_app_update_guard/src/models/pub_package_info.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import '../fake_pub_client.dart';

void main() {
  group('AppRunner Integration', () {
    test('help flag returns success code 0', () async {
      final runner = AppRunner(const ['--help']);
      final code = await runner.run();
      expect(code, equals(ExitCodes.success));
    });

    test('invalid command returns invalidConfig code 2', () async {
      final runner = AppRunner(const ['invalid_command']);
      final code = await runner.run();
      expect(code, equals(ExitCodes.invalidConfig));
    });

    test('missing pubspec returns pubspecNotFound code 4', () async {
      final tempDir = Directory.systemTemp.createTempSync('update_guard_test');
      try {
        final runner = AppRunner(const ['check'], pubClient: FakePubClient(const {}));
        final code = await IOOverrides.runZoned(
          () => runner.run(),
          getCurrentDirectory: () => tempDir,
        );
        expect(code, equals(ExitCodes.pubspecNotFound));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('check command runs successfully when no violations exist', () async {
      final fakeClient = FakePubClient({
        'path': PubPackageInfo(
          name: 'path',
          latestVersion: Version.parse('1.8.0'), // matches current locked in sample_dart_project
          latestPublished: DateTime.now(),
          isDiscontinued: false,
        ),
      });

      final runner = AppRunner(const ['check', '--quiet'], pubClient: fakeClient);
      final targetDir = Directory('test/fixtures/sample_dart_project').absolute;
      final code = await IOOverrides.runZoned(
        () => runner.run(),
        getCurrentDirectory: () => targetDir,
      );

      expect(code, equals(ExitCodes.success));
    });

    test('check command returns policyViolation code 1 if policy fail', () async {
      final fakeClient = FakePubClient({
        'path': PubPackageInfo(
          name: 'path',
          latestVersion: Version.parse('2.0.0'), // triggers prohibited major upgrade since default is allow_major = true but wait! Let's check config fail conditions
          latestPublished: DateTime.now(),
          isDiscontinued: true, // triggers fail_on_discontinued = true
        ),
      });

      final runner = AppRunner(const ['check', '--quiet'], pubClient: fakeClient);
      final targetDir = Directory('test/fixtures/sample_dart_project').absolute;
      final code = await IOOverrides.runZoned(
        () => runner.run(),
        getCurrentDirectory: () => targetDir,
      );

      expect(code, equals(ExitCodes.policyViolation));
    });
  });
}

