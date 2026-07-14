import 'dart:io';
import 'package:flutter_app_update_guard/src/analyzers/workspace_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('WorkspaceAnalyzer', () {
    late Directory rootDir;

    setUp(() {
      rootDir = Directory.systemTemp.createTempSync('workspace_analyzer_test_');

      // Create folder structures
      Directory(p.join(rootDir.path, 'apps', 'mobile')).createSync(recursive: true);
      Directory(p.join(rootDir.path, 'packages', 'api')).createSync(recursive: true);
      Directory(p.join(rootDir.path, 'packages', 'legacy')).createSync(recursive: true);

      // Write pubspecs
      File(p.join(rootDir.path, 'apps', 'mobile', 'pubspec.yaml')).writeAsStringSync('''
        name: mobile_app
        environment:
          sdk: '>=3.0.0 <4.0.0'
        dependencies:
          dio: ^5.0.0
          meta: ^1.9.0
      ''');

      File(p.join(rootDir.path, 'packages', 'api', 'pubspec.yaml')).writeAsStringSync('''
        name: api_client
        environment:
          sdk: '>=3.0.0 <4.0.0'
        dependencies:
          dio: '>=5.0.0 <6.0.0'
      ''');

      File(p.join(rootDir.path, 'packages', 'legacy', 'pubspec.yaml')).writeAsStringSync('''
        name: legacy_lib
        environment:
          sdk: '>=3.0.0 <4.0.0'
        dependencies:
          dio: ^4.0.0
      ''');
    });

    tearDown(() {
      if (rootDir.existsSync()) {
        rootDir.deleteSync(recursive: true);
      }
    });

    test('discovers subprojects correctly', () {
      final projects = WorkspaceAnalyzer.discoverProjects(rootDir.path, maxDepth: 5);

      expect(projects.length, equals(3));
      expect(projects.map((e) => e.name), containsAll(['mobile_app', 'api_client', 'legacy_lib']));
    });

    test('respects workspace exclude patterns', () {
      final projects = WorkspaceAnalyzer.discoverProjects(
        rootDir.path,
        maxDepth: 5,
        excludePatterns: ['packages/legacy/**'],
      );

      expect(projects.length, equals(2));
      expect(projects.map((e) => e.name), containsAll(['mobile_app', 'api_client']));
      expect(projects.map((e) => e.name), isNot(contains('legacy_lib')));
    });

    test('detects constraint mismatches but ignores equivalent ranges', () {
      final projects = WorkspaceAnalyzer.discoverProjects(rootDir.path);
      final mismatches = WorkspaceAnalyzer.findMismatches(projects, rootDir.path);

      // We expect a mismatch for 'dio' because of ^4.0.0 vs ^5.0.0/range.
      // But we should NOT flag a mismatch for 'meta' (only in 1 project) or 'dio' equivalent range.
      expect(mismatches.length, equals(1));
      final dioMismatch = mismatches.first;
      expect(dioMismatch.packageName, equals('dio'));
      expect(dioMismatch.constraintsByProject.length, equals(3));
      expect(dioMismatch.constraintsByProject['apps/mobile'], equals('^5.0.0'));
      expect(dioMismatch.constraintsByProject['packages/api'], equals('>=5.0.0 <6.0.0'));
      expect(dioMismatch.constraintsByProject['packages/legacy'], equals('^4.0.0'));
    });

    test('ignores mismatch if different projects use equivalent ranges and legacy is excluded', () {
      final projects = WorkspaceAnalyzer.discoverProjects(
        rootDir.path,
        excludePatterns: ['packages/legacy/**'],
      );
      final mismatches = WorkspaceAnalyzer.findMismatches(projects, rootDir.path);

      // Apps/mobile (dio: ^5.0.0) and packages/api (dio: >=5.0.0 <6.0.0) are equivalent.
      // Since legacy is excluded, no mismatch should be flagged.
      expect(mismatches, isEmpty);
    });
  });
}
