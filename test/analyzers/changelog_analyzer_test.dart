import 'package:flutter_app_update_guard/src/analyzers/changelog_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('ChangelogAnalyzer', () {
    test('detects breaking keywords in changelog body text', () {
      const changelog = '''
        ## 2.0.0
        
        * BREAKING CHANGE: Minimum Dart SDK is now 3.0.0.
        * Removed support for old APIs.
        * Deprecated oldClient helper.
        * Migration steps from 1.x are detailed below.
      ''';

      final result = ChangelogAnalyzer.analyzeContent(changelog);

      expect(result.available, isTrue);
      expect(result.indicators, contains('breaking'));
      expect(result.indicators, contains('removed'));
      expect(result.indicators, contains('deprecated'));
      expect(result.indicators, contains('migration'));
      expect(result.indicators, contains('minimum Dart SDK'));
    });

    test('returns empty indicators list when no keywords are present', () {
      const changelog = '''
        ## 1.1.2
        
        * Bug fixes and performance improvements.
        * Refactored inner request loops.
      ''';

      final result = ChangelogAnalyzer.analyzeContent(changelog);

      expect(result.available, isTrue);
      expect(result.indicators, isEmpty);
    });

    test('analyzeLocal resolves to unavailable when home dir is empty or package not in cache', () async {
      final result = await ChangelogAnalyzer.analyzeLocal('non_existing_pkg_xyz', '99.9.9');
      expect(result.available, isFalse);
      expect(result.indicators, isEmpty);
    });
  });
}
