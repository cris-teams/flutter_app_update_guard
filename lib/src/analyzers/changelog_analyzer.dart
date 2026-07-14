import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/changelog_analysis.dart';

/// Service analyzing changelog files for potential breaking change indicators.
class ChangelogAnalyzer {
  static const List<String> _keywords = [
    'breaking',
    'removed',
    'deprecated',
    'migration',
    'renamed',
    'minimum Dart SDK',
    'minimum Flutter version',
    'no longer supports',
  ];

  /// Analyzes the changelog for [packageName] at [version].
  /// Checks local `.pub-cache` paths. Returns unavailable result if not found.
  static Future<ChangelogAnalysis> analyzeLocal(String packageName, String version) async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      return const ChangelogAnalysis(available: false, indicators: []);
    }

    final pathsToTry = [
      p.join(home, '.pub-cache', 'hosted', 'pub.dev', '$packageName-$version', 'CHANGELOG.md'),
      p.join(home, '.pub-cache', 'hosted', 'pub.dartlang.org', '$packageName-$version', 'CHANGELOG.md'),
    ];

    for (final path in pathsToTry) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          final content = await file.readAsString();
          return analyzeContent(content, source: path);
        } catch (_) {
          // Fall through
        }
      }
    }

    return const ChangelogAnalysis(available: false, indicators: []);
  }

  /// Analyzes a raw changelog string content.
  static ChangelogAnalysis analyzeContent(String content, {String? source}) {
    final foundIndicators = <String>[];
    final contentLower = content.toLowerCase();

    for (final kw in _keywords) {
      if (contentLower.contains(kw.toLowerCase())) {
        foundIndicators.add(kw);
      }
    }

    return ChangelogAnalysis(
      available: true,
      indicators: foundIndicators,
      source: source,
    );
  }
}
