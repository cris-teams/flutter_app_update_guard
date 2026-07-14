import 'dart:io';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import '../models/package_usage.dart';

/// Service analyzing Dart files to scan for package import/export declarations.
class SourceUsageAnalyzer {
  static final RegExp _importRegExp = RegExp('import\\s+[\'"]package:([^/]+)/');
  static final RegExp _exportRegExp = RegExp('export\\s+[\'"]package:([^/]+)/');

  /// Scans the target project root directory for package usage.
  /// Throws nothing, skips files that cannot be read, and writes diagnostics if [verbose] is true.
  static Future<Map<String, PackageUsage>> scan(
    String projectRoot, {
    bool includeExports = true,
    bool ignoreGenerated = true,
    List<String> excludePatterns = const [],
    bool verbose = false,
  }) async {
    final root = Directory(p.canonicalize(p.absolute(projectRoot)));
    if (!root.existsSync()) {
      return const <String, PackageUsage>{};
    }

    final targetDirs = ['lib', 'bin', 'test', 'integration_test', 'example'];
    final excludes = excludePatterns.map((pat) => Glob(pat)).toList();

    // Map of package names to their files lists
    final usageMap = <String, Set<String>>{};
    
    // Track file lists per directory group
    for (final dirName in targetDirs) {
      final dir = Directory(p.join(root.path, dirName));
      if (!dir.existsSync()) continue;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final filePath = entity.path;

        if (!filePath.endsWith('.dart')) continue;

        // Create a normalized relative path with forward slashes
        final relativePath = p.relative(filePath, from: root.path).replaceAll('\\', '/');

        // Check glob excludes
        bool isExcluded = false;
        for (final glob in excludes) {
          if (glob.matches(relativePath)) {
            isExcluded = true;
            break;
          }
        }
        if (isExcluded) continue;

        // Check generated files
        if (ignoreGenerated) {
          final fileName = p.basename(filePath);
          final isGen = fileName.endsWith('.g.dart') ||
              fileName.endsWith('.freezed.dart') ||
              fileName.endsWith('.mocks.dart') ||
              fileName.endsWith('.gr.dart') ||
              fileName.endsWith('.config.dart');
          if (isGen) continue;
        }

        // Process file contents
        try {
          final content = await entity.readAsString();
          final packagesUsed = <String>{};

          // Find imports
          for (final match in _importRegExp.allMatches(content)) {
            final pkgName = match.group(1);
            if (pkgName != null) {
              packagesUsed.add(pkgName);
            }
          }

          // Find exports
          if (includeExports) {
            for (final match in _exportRegExp.allMatches(content)) {
              final pkgName = match.group(1);
              if (pkgName != null) {
                packagesUsed.add(pkgName);
              }
            }
          }

          for (final pkg in packagesUsed) {
            usageMap.putIfAbsent(pkg, () => <String>{}).add(relativePath);
          }
        } catch (e) {
          if (verbose) {
            stderr.writeln('Warning: Failed to read file: $relativePath. $e');
          }
        }
      }
    }

    // Convert Set map to sorted PackageUsage models
    final result = <String, PackageUsage>{};

    for (final entry in usageMap.entries) {
      final pkgName = entry.key;
      final files = entry.value;

      final prod = <String>[];
      final test = <String>[];
      final integration = <String>[];
      final example = <String>[];

      for (final f in files) {
        if (f.startsWith('test/')) {
          test.add(f);
        } else if (f.startsWith('integration_test/')) {
          integration.add(f);
        } else if (f.startsWith('example/')) {
          example.add(f);
        } else {
          prod.add(f);
        }
      }

      // Sort lists alphabetically for determinism
      prod.sort();
      test.sort();
      integration.sort();
      example.sort();

      result[pkgName] = PackageUsage(
        packageName: pkgName,
        productionFiles: prod,
        testFiles: test,
        integrationTestFiles: integration,
        exampleFiles: example,
      );
    }

    return result;
  }
}
