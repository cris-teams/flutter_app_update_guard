import 'package:flutter_app_update_guard/src/models/dependency_info.dart';
import 'package:flutter_app_update_guard/src/project/lockfile_reader.dart';
import 'package:flutter_app_update_guard/src/project/project_detector.dart';
import 'package:flutter_app_update_guard/src/project/pubspec_reader.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectDetector', () {
    test('detects project paths when pubspec.yaml exists', () {
      final paths = ProjectDetector.detect('test/fixtures/sample_flutter_project');
      expect(paths.rootPath, contains('sample_flutter_project'));
      expect(paths.pubspecPath, endsWith('pubspec.yaml'));
      expect(paths.lockfilePath, endsWith('pubspec.lock'));
    });

    test('throws GuardException when pubspec.yaml is missing', () {
      expect(() => ProjectDetector.detect('test/fixtures'), throwsException);
    });
  });

  group('PubspecReader', () {
    test('parses sample_flutter_project successfully', () {
      final data = PubspecReader.read('test/fixtures/sample_flutter_project/pubspec.yaml');
      expect(data.projectName, equals('sample_flutter_project'));
      expect(data.dartSdkConstraint, equals('>=3.0.0 <4.0.0'));
      expect(data.flutterSdkConstraint, equals('>=3.10.0'));

      // Check dependency declarations
      final deps = data.dependencies;
      expect(deps.any((d) => d.name == 'flutter' && d.kind == DependencyKind.sdk), isTrue);
      expect(deps.any((d) => d.name == 'dio' && d.kind == DependencyKind.hosted && d.constraint == '^5.0.0'), isTrue);
      expect(deps.any((d) => d.name == 'provider' && d.kind == DependencyKind.hosted && d.constraint == '^6.1.2'), isTrue);
    });

    test('parses sample_dart_project successfully', () {
      final data = PubspecReader.read('test/fixtures/sample_dart_project/pubspec.yaml');
      expect(data.projectName, equals('sample_dart_project'));
      expect(data.dartSdkConstraint, equals('>=3.0.0 <4.0.0'));
      expect(data.flutterSdkConstraint, isNull);

      final deps = data.dependencies;
      expect(deps.length, equals(1));
      expect(deps.first.name, equals('path'));
      expect(deps.first.kind, equals(DependencyKind.hosted));
      expect(deps.first.constraint, equals('^1.8.0'));
    });

    test('throws exception on invalid pubspec format', () {
      expect(
        () => PubspecReader.read('test/fixtures/invalid_pubspec_project/pubspec.yaml'),
        throwsException,
      );
    });
  });

  group('LockfileReader', () {
    test('parses lockfile successfully', () {
      final lockMap = LockfileReader.read('test/fixtures/sample_flutter_project/pubspec.lock');
      expect(lockMap.containsKey('dio'), isTrue);
      expect(lockMap['dio']!.version.toString(), equals('5.0.0'));
      expect(lockMap['dio']!.kind, equals(DependencyKind.hosted));

      expect(lockMap.containsKey('flutter'), isTrue);
      expect(lockMap['flutter']!.kind, equals(DependencyKind.sdk));
    });

    test('parses mixed dependency types correctly', () {
      final lockMap = LockfileReader.read('test/fixtures/mixed_dependencies_project/pubspec.lock');
      expect(lockMap['local_package']!.kind, equals(DependencyKind.path));
      expect(lockMap['custom_package']!.kind, equals(DependencyKind.git));
      expect(lockMap['dio']!.kind, equals(DependencyKind.hosted));
    });
  });
}
