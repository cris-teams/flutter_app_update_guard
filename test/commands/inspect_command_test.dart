import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_app_update_guard/src/commands/inspect_command.dart';
import 'package:flutter_app_update_guard/src/config/guard_config.dart';
import 'package:flutter_app_update_guard/src/models/pub_package_info.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import '../fake_pub_client.dart';

void main() {
  group('InspectCommandExecutor', () {
    late Directory tempProjectDir;
    late FakePubClient fakePubClient;

    setUp(() {
      tempProjectDir = Directory.systemTemp.createTempSync('inspect_test_');

      File(p.join(tempProjectDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: inspect_test_app
        environment:
          sdk: '>=3.0.0 <4.0.0'
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
          latestPublished: DateTime.parse('2026-04-10T12:00:00Z'),
          isDiscontinued: false,
        ),
      });
    });

    tearDown(() {
      if (tempProjectDir.existsSync()) {
        tempProjectDir.deleteSync(recursive: true);
      }
    });

    test('inspects package successfully and renders expected JSON metrics', () async {
      final executor = InspectCommandExecutor(pubClient: fakePubClient);
      
      // Capture print stdout
      final prints = <String>[];
      await runZoned(() async {
        await executor.execute(
          workingDir: tempProjectDir.path,
          packageName: 'dio',
          format: 'json',
          showFiles: false,
          config: GuardConfig.defaultConfig(),
        );
      }, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          prints.add(line);
        },
      ));

      expect(prints.length, equals(1));
      final jsonMap = json.decode(prints.first) as Map<String, dynamic>;
      expect(jsonMap['packageName'], equals('dio'));
      expect(jsonMap['currentVersion'], equals('5.0.0'));
      expect(jsonMap['latestVersion'], equals('6.0.0'));
      expect(jsonMap['updateType'], equals('major'));
      expect(jsonMap['constraint'], equals('^5.0.0'));
    });
  });
}
