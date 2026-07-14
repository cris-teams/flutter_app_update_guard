import 'package:flutter_app_update_guard/src/config/config_loader.dart';
import 'package:flutter_app_update_guard/src/models/risk_models.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigLoader.parse', () {
    test('parses empty or null configuration to default config', () {
      final config = ConfigLoader.parse('');
      expect(config.risk.failOn, contains(RiskLevel.critical));
      expect(config.risk.warnOn, contains(RiskLevel.high));
      expect(config.risk.warnOn, contains(RiskLevel.medium));
      expect(config.checks.outdated, isTrue);
      expect(config.checks.discontinued, isTrue);
      expect(config.maintenance.staleAfterDays, equals(730));
      expect(config.policies.allowPrerelease, isFalse);
      expect(config.policies.allowMajorUpdates, isFalse);
      expect(config.policies.maxCriticalDependencies, equals(0));
      expect(config.ignore.packages, isEmpty);
    });

    test('parses custom YAML values correctly', () {
      const yaml = '''
risk:
  fail_on:
    - critical
    - high
  warn_on:
    - medium

checks:
  outdated: false
  discontinued: true

maintenance:
  stale_after_days: 365

policies:
  allow_prerelease: true
  allow_major_updates: false
  fail_on_discontinued: false
  max_critical_dependencies: 2

ignore:
  packages:
    - foo
    - bar
''';
      final config = ConfigLoader.parse(yaml);
      expect(config.risk.failOn, containsAll([RiskLevel.critical, RiskLevel.high]));
      expect(config.risk.warnOn, contains(RiskLevel.medium));
      expect(config.checks.outdated, isFalse);
      expect(config.checks.discontinued, isTrue);
      expect(config.maintenance.staleAfterDays, equals(365));
      expect(config.policies.allowPrerelease, isTrue);
      expect(config.policies.allowMajorUpdates, isFalse);
      expect(config.policies.failOnDiscontinued, isFalse);
      expect(config.policies.maxCriticalDependencies, equals(2));
      expect(config.ignore.packages, containsAll(['foo', 'bar']));
    });

    test('throws GuardException on invalid YAML format', () {
      const yaml = '''
risk:
  fail_on: [invalid_yaml
''';
      expect(() => ConfigLoader.parse(yaml), throwsException);
    });

    test('throws GuardException on invalid risk levels', () {
      const yaml = '''
risk:
  fail_on:
    - ultra_high
''';
      expect(() => ConfigLoader.parse(yaml), throwsException);
    });

    test('throws GuardException on negative stale_after_days', () {
      const yaml = '''
maintenance:
  stale_after_days: -10
''';
      expect(() => ConfigLoader.parse(yaml), throwsException);
    });

    test('throws GuardException on negative max_critical_dependencies', () {
      const yaml = '''
policies:
  max_critical_dependencies: -1
''';
      expect(() => ConfigLoader.parse(yaml), throwsException);
    });

    test('throws GuardException on invalid type for boolean check', () {
      const yaml = '''
checks:
  outdated: "yes"
''';
      expect(() => ConfigLoader.parse(yaml), throwsException);
    });
  });
}
