import 'package:flutter_app_update_guard/src/analyzers/version_classifier.dart';
import 'package:flutter_app_update_guard/src/models/dependency_info.dart';
import 'package:flutter_app_update_guard/src/models/dependency_report.dart';
import 'package:flutter_app_update_guard/src/models/project_report.dart';
import 'package:flutter_app_update_guard/src/models/risk_models.dart';
import 'package:flutter_app_update_guard/src/reporters/markdown_reporter.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownReporter', () {
    test('renders PR summary table, policy violations, and recommendations correctly', () {
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
              score: 80,
              level: RiskLevel.critical,
              reasons: [
                RiskReason(code: 'MAJOR_UPGRADE', message: 'Major version upgrade', score: 30),
                RiskReason(code: 'CONSTRAINT_INCOMPATIBLE', message: 'Constraint incompatible', score: 15),
              ],
            ),
            isSkipped: false,
            sdkCompatibility: SdkCompatibility.compatible,
          ),
        ],
        policyViolations: const ['POLICY_ALLOW_MAJOR_VIOLATION: Major upgrade is prohibited'],
        warnings: const ['Warnings found during run'],
      );

      const reporter = MarkdownReporter();
      final markdown = reporter.render(report);

      expect(markdown, contains('# Flutter App Update Guard'));
      expect(markdown, contains('| Level | Count |'));
      expect(markdown, contains('| Critical | 1 |'));
      expect(markdown, contains('| Safe | 0 |'));
      expect(markdown, contains('## 🛑 Policy Violations'));
      expect(markdown, contains('- POLICY_ALLOW_MAJOR_VIOLATION: Major upgrade is prohibited'));
      expect(markdown, contains('## ⚠️ Warnings'));
      expect(markdown, contains('- Warnings found during run'));
      expect(markdown, contains('### dio'));
      expect(markdown, contains('- Current: `5.0.0`'));
      expect(markdown, contains('- Latest: `6.0.0`'));
      expect(markdown, contains('- Score: `80`'));
      expect(markdown, contains('Action required'));
    });
  });
}
