import 'package:flutter_app_update_guard/src/config/config_loader.dart';
import 'package:flutter_app_update_guard/src/config/guard_config.dart';
import 'package:flutter_app_update_guard/src/models/dependency_info.dart';
import 'package:flutter_app_update_guard/src/models/pub_package_info.dart';
import 'package:flutter_app_update_guard/src/models/risk_models.dart';
import 'package:flutter_app_update_guard/src/risk/risk_engine.dart';
import 'package:flutter_app_update_guard/src/risk/risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/constraint_compatibility_risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/discontinued_risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/major_version_risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/minor_version_risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/prerelease_risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/sdk_compatibility_risk_rule.dart';
import 'package:flutter_app_update_guard/src/risk/rules/stale_package_risk_rule.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  final defaultConfig = GuardConfig.defaultConfig();

  group('MajorVersionRiskRule', () {
    test('returns reason with score 30 on major version upgrade', () {
      final dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
        lockedVersion: Version.parse('1.0.0'),
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('2.0.0'),
        latestPublished: DateTime.now(),
        isDiscontinued: false,
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      final reason = const MajorVersionRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(30));
      expect(reason.code, equals('MAJOR_UPGRADE'));
    });

    test('returns null if same major version', () {
      final dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
        lockedVersion: Version.parse('1.0.0'),
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('1.1.0'),
        latestPublished: DateTime.now(),
        isDiscontinued: false,
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      expect(const MajorVersionRiskRule().evaluate(ctx), isNull);
    });
  });

  group('MinorVersionRiskRule', () {
    test('returns reason with score 10 on minor version upgrade', () {
      final dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
        lockedVersion: Version.parse('1.0.0'),
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('1.1.0'),
        latestPublished: DateTime.now(),
        isDiscontinued: false,
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      final reason = const MinorVersionRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(10));
      expect(reason.code, equals('MINOR_UPGRADE'));
    });
  });

  group('PrereleaseRiskRule', () {
    test('returns reason with score 10 on prerelease target', () {
      final dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
        lockedVersion: Version.parse('1.0.0'),
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('2.0.0-beta.1'),
        latestPublished: DateTime.now(),
        isDiscontinued: false,
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      final reason = const PrereleaseRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(10));
    });
  });

  group('DiscontinuedRiskRule', () {
    test('returns reason with score 40 if package is discontinued', () {
      const dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('1.0.0'),
        latestPublished: DateTime.now(),
        isDiscontinued: true,
        replacedBy: 'bar',
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      final reason = const DiscontinuedRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(40));
      expect(reason.message, contains('Replaced by: bar'));
    });
  });

  group('StalePackageRiskRule', () {
    test('returns reason with score 15 if package release exceeds stale threshold', () {
      const dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('1.0.0'),
        latestPublished: DateTime.now().subtract(const Duration(days: 800)),
        isDiscontinued: false,
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      final reason = const StalePackageRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(15));
    });
  });

  group('SdkCompatibilityRiskRule', () {
    test('returns score 40 if Dart SDK is incompatible', () {
      const dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('1.0.0'),
        latestPublished: DateTime.now(),
        dartSdkConstraint: '>=3.0.0 <4.0.0',
        isDiscontinued: false,
      );
      final ctx = DependencyContext(
        dependency: dep,
        packageInfo: info,
        config: defaultConfig,
        projectDartSdkConstraint: '>=2.12.0 <3.0.0', // project runs on older Dart, package requires 3+
      );
      final reason = const SdkCompatibilityRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(40));
      expect(reason.code, equals('DART_SDK_INCOMPATIBLE'));
    });

    test('returns score 40 if Flutter SDK is incompatible', () {
      const dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('1.0.0'),
        latestPublished: DateTime.now(),
        flutterSdkConstraint: '>=3.0.0',
        isDiscontinued: false,
      );
      final ctx = DependencyContext(
        dependency: dep,
        packageInfo: info,
        config: defaultConfig,
        projectFlutterSdkConstraint: '>=2.0.0 <3.0.0',
      );
      final reason = const SdkCompatibilityRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(40));
      expect(reason.code, equals('FLUTTER_SDK_INCOMPATIBLE'));
    });
  });

  group('ConstraintCompatibilityRiskRule', () {
    test('returns score 15 if latest version not allowed by local constraint', () {
      const dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
        constraint: '^1.0.0',
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('2.0.0'),
        latestPublished: DateTime.now(),
        isDiscontinued: false,
      );
      final ctx = DependencyContext(dependency: dep, packageInfo: info, config: defaultConfig);
      final reason = const ConstraintCompatibilityRiskRule().evaluate(ctx);

      expect(reason, isNotNull);
      expect(reason!.score, equals(15));
    });
  });

  group('RiskEngine', () {
    test('caps score at 100 and computes risk levels correctly', () {
      // Discontinued (+40) + Major (+30) + SDK incompatible (+40) = 110, capped at 100
      const engine = RiskEngine([
        DiscontinuedRiskRule(),
        MajorVersionRiskRule(),
        SdkCompatibilityRiskRule(),
      ]);

      final dep = DependencyInfo(
        name: 'foo',
        kind: DependencyKind.hosted,
        section: DependencySection.dependencies,
        lockedVersion: Version.parse('1.0.0'),
      );
      final info = PubPackageInfo(
        name: 'foo',
        latestVersion: Version.parse('2.0.0'),
        latestPublished: DateTime.now(),
        dartSdkConstraint: '>=3.0.0 <4.0.0',
        isDiscontinued: true,
      );
      final ctx = DependencyContext(
        dependency: dep,
        packageInfo: info,
        config: defaultConfig,
        projectDartSdkConstraint: '>=2.12.0 <3.0.0',
      );

      final risk = engine.evaluate(ctx);
      expect(risk.score, equals(100));
      expect(risk.level, equals(RiskLevel.critical));
      expect(risk.reasons.length, equals(3));
    });

    test('respects disabled checks in configuration', () {
      final config = ConfigLoader.parse('''
checks:
  outdated: false
  discontinued: false
''');

      final engine = RiskEngine.fromConfig(config);
      // If checks outdated/discontinued are disabled, rules list shouldn't have MajorVersionRiskRule or DiscontinuedRiskRule
      expect(engine.rules.any((r) => r is MajorVersionRiskRule), isFalse);
      expect(engine.rules.any((r) => r is DiscontinuedRiskRule), isFalse);
    });
  });
}
