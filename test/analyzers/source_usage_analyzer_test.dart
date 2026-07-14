import 'dart:io';
import 'package:flutter_app_update_guard/src/analyzers/source_usage_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SourceUsageAnalyzer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('source_usage_test_');
      
      // Create subdirectory structure
      Directory(p.join(tempDir.path, 'lib')).createSync();
      Directory(p.join(tempDir.path, 'lib', 'generated')).createSync();
      Directory(p.join(tempDir.path, 'test')).createSync();
      Directory(p.join(tempDir.path, 'example')).createSync();

      // Write sample Dart files
      File(p.join(tempDir.path, 'lib', 'api.dart')).writeAsStringSync('''
        import 'package:dio/dio.dart';
        import 'package:meta/meta.dart';
        void main() {}
      ''');

      File(p.join(tempDir.path, 'lib', 'generated', 'api.g.dart')).writeAsStringSync('''
        import 'package:dio/dio.dart';
      ''');

      File(p.join(tempDir.path, 'test', 'api_test.dart')).writeAsStringSync('''
        import 'package:dio/dio.dart';
        export 'package:meta/meta.dart';
        void main() {}
      ''');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('scans imports/exports and groups them correctly', () async {
      final result = await SourceUsageAnalyzer.scan(tempDir.path);

      expect(result.containsKey('dio'), isTrue);
      final dioUsage = result['dio']!;
      expect(dioUsage.productionFiles, equals(['lib/api.dart']));
      expect(dioUsage.testFiles, equals(['test/api_test.dart']));
      expect(dioUsage.totalFiles, equals(2)); // lib/generated/api.g.dart is ignored as generated

      expect(result.containsKey('meta'), isTrue);
      final metaUsage = result['meta']!;
      expect(metaUsage.productionFiles, equals(['lib/api.dart']));
      expect(metaUsage.testFiles, equals(['test/api_test.dart'])); // matching export
    });

    test('excludes export declarations if includeExports is false', () async {
      final result = await SourceUsageAnalyzer.scan(tempDir.path, includeExports: false);

      final metaUsage = result['meta']!;
      expect(metaUsage.productionFiles, equals(['lib/api.dart']));
      expect(metaUsage.testFiles, isEmpty); // export ignored
    });

    test('respects custom glob exclusions', () async {
      // Re-enable generated scanner but exclude whole directory using globs
      final result = await SourceUsageAnalyzer.scan(
        tempDir.path,
        ignoreGenerated: false,
        excludePatterns: ['lib/generated/**'],
      );

      final dioUsage = result['dio']!;
      expect(dioUsage.productionFiles, equals(['lib/api.dart'])); // generated still excluded by glob
    });
  });
}
