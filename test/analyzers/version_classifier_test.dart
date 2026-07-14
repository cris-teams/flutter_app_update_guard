import 'package:flutter_app_update_guard/src/analyzers/version_classifier.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('VersionClassifier', () {
    test('same version maps to none', () {
      final current = Version.parse('1.0.0');
      final target = Version.parse('1.0.0');
      expect(VersionClassifier.classify(current, target), UpdateType.none);
    });

    test('patch upgrade maps to patch', () {
      final current = Version.parse('1.0.0');
      final target = Version.parse('1.0.1');
      expect(VersionClassifier.classify(current, target), UpdateType.patch);
    });

    test('minor upgrade maps to minor', () {
      final current = Version.parse('1.0.0');
      final target = Version.parse('1.1.0');
      expect(VersionClassifier.classify(current, target), UpdateType.minor);
    });

    test('major upgrade maps to major', () {
      final current = Version.parse('1.0.0');
      final target = Version.parse('2.0.0');
      expect(VersionClassifier.classify(current, target), UpdateType.major);
    });

    test('target prerelease maps to prerelease', () {
      final current = Version.parse('1.0.0');
      final target = Version.parse('2.0.0-beta.1');
      expect(VersionClassifier.classify(current, target), UpdateType.prerelease);
    });

    test('upgrade from prerelease to release maps to release update type', () {
      final current = Version.parse('1.0.0-beta.1');
      final target = Version.parse('1.0.0');
      // Technically, 1.0.0-beta.1 to 1.0.0 is resolving the prerelease, which is patch/none
      // Let's verify: 1.0.0 major == 1.0.0-beta.1 major, minor == minor, patch == patch.
      // But target is not pre-release. 
      expect(VersionClassifier.classify(current, target), UpdateType.patch);
    });

    test('build metadata upgrades are classified as patch', () {
      final current = Version.parse('1.0.0+1');
      final target = Version.parse('1.0.0+2');
      expect(VersionClassifier.classify(current, target), UpdateType.patch);
    });

    test('build metadata same are classified as none', () {
      final current = Version.parse('1.0.0+1');
      final target = Version.parse('1.0.0+1');
      expect(VersionClassifier.classify(current, target), UpdateType.none);
    });
  });
}
