import 'dart:convert';
import 'package:flutter_app_update_guard/src/analyzers/version_classifier.dart';
import 'package:flutter_app_update_guard/src/models/dependency_info.dart';
import 'package:flutter_app_update_guard/src/models/dependency_report.dart';
import 'package:flutter_app_update_guard/src/models/project_report.dart';
import 'package:flutter_app_update_guard/src/models/risk_models.dart';
import 'package:flutter_app_update_guard/src/reporters/console_reporter.dart';
import 'package:flutter_app_update_guard/src/reporters/json_reporter.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  final report = ProjectReport(
    projectName: 'my_test_app',
    generatedAt: DateTime.parse('2026-07-14T10:00:00Z'),
    dependencies: [
      DependencyReport(
        dependency: DependencyInfo(
          name: 'dio',
          kind: DependencyKind.hosted,
          section: DependencySection.dependencies,
          lockedVersion: Version(5, 0, 0),
          constraint: '^5.0.0',
        ),
        latestVersion: Version(6, 0, 0),
        updateType: UpdateType.major,
        risk: const DependencyRisk(
          score: 45,
          level: RiskLevel.medium,
          reasons: [
            RiskReason(code: 'MAJOR_UPGRADE', message: 'Major version upgrade', score: 30),
            RiskReason(code: 'CONSTRAINT_INCOMPATIBLE', message: 'Constraint incompatible', score: 15),
          ],
        ),
        isSkipped: false,
        sdkCompatibility: SdkCompatibility.compatible,
      ),
      const DependencyReport(
        dependency: DependencyInfo(
          name: 'local_pkg',
          kind: DependencyKind.path,
          section: DependencySection.dependencies,
        ),
        updateType: UpdateType.none,
        risk: DependencyRisk(score: 0, level: RiskLevel.safe, reasons: []),
        isSkipped: true,
        skipReason: 'Not hosted',
        sdkCompatibility: SdkCompatibility.unknown,
      ),
    ],
    policyViolations: const ['Prohibited dependency version update'],
    warnings: const ['Medium risk dependencies found'],
  );

  group('ConsoleReporter', () {
    test('renders tabular data, summary, warnings, and violations', () {
      const reporter = ConsoleReporter(useColor: false);
      final output = reporter.render(report);

      expect(output, contains('Flutter App Update Guard'));
      expect(output, contains('dio'));
      expect(output, contains('local_pkg'));
      expect(output, contains('Summary'));
      expect(output, contains('Safe:      0'));
      expect(output, contains('Medium:    1'));
      expect(output, contains('Skipped:   1'));
      expect(output, contains('Risk Breakdown & Explanations'));
      expect(output, contains('dio (medium risk, score: 45)'));
      expect(output, contains('Policy Violations'));
      expect(output, contains('[!] Prohibited dependency version update'));
    });
  });

  group('JsonReporter', () {
    test('renders valid machine-readable JSON structure', () {
      const reporter = JsonReporter();
      final output = reporter.render(report);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['project'], equals('my_test_app'));
      expect(decoded['generatedAt'], equals('2026-07-14T10:00:00.000Z'));

      final summary = decoded['summary'] as Map<String, dynamic>;
      expect(summary['medium'], equals(1));
      expect(summary['skipped'], equals(1));

      final deps = decoded['dependencies'] as List<dynamic>;
      expect(deps.length, equals(2));

      final dep0 = deps[0] as Map<String, dynamic>;
      expect(dep0['name'], equals('dio'));
      expect(dep0['latestVersion'], equals('6.0.0'));

      final risk = dep0['risk'] as Map<String, dynamic>;
      expect(risk['score'], equals(45));
      expect(risk['level'], equals('medium'));

      final dep1 = deps[1] as Map<String, dynamic>;
      expect(dep1['isSkipped'], isTrue);
    });
  });
}
