import 'package:flutter_app_update_guard/src/analyzers/version_classifier.dart';
import 'package:flutter_app_update_guard/src/commands/ci_command.dart';
import 'package:flutter_app_update_guard/src/config/baseline_manager.dart';
import 'package:flutter_app_update_guard/src/config/guard_config.dart';
import 'package:flutter_app_update_guard/src/models/dependency_info.dart';
import 'package:flutter_app_update_guard/src/models/dependency_report.dart';
import 'package:flutter_app_update_guard/src/models/project_report.dart';
import 'package:flutter_app_update_guard/src/models/risk_models.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('CiCommandExecutor', () {
    late ProjectReport baseReport;
    late GuardConfig defaultConfig;

    setUp(() {
      defaultConfig = GuardConfig.defaultConfig();
      baseReport = ProjectReport(
        projectName: 'ci_test_app',
        generatedAt: DateTime.now(),
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
        ],
        policyViolations: const [],
        warnings: const [],
      );
    });

    test('CI policy fail on prohibited major update (allow_major_updates = false)', () {
      final violations = CiCommandExecutor.evaluate(baseReport, defaultConfig);

      // default config has allowMajorUpdates = false
      expect(violations.length, equals(1));
      expect(violations.first.code, equals('POLICY_ALLOW_MAJOR_VIOLATION'));
      expect(violations.first.packageName, equals('dio'));
    });

    test('CI policy pass if allow_major_updates is configured to true', () {
      // Modify policy configuration
      final customConfig = GuardConfig(
        risk: defaultConfig.risk,
        checks: defaultConfig.checks,
        maintenance: defaultConfig.maintenance,
        sourceUsage: defaultConfig.sourceUsage,
        simulation: defaultConfig.simulation,
        policies: const PoliciesConfig(
          allowPrerelease: false,
          allowMajorUpdates: true,
          failOnDiscontinued: true,
          failOnSdkIncompatible: true,
          maxCriticalDependencies: 0,
          maxHighRiskDependencies: 3,
          maxMediumRiskDependencies: 10,
        ),
        workspace: defaultConfig.workspace,
        ignore: defaultConfig.ignore,
      );

      final violations = CiCommandExecutor.evaluate(baseReport, customConfig);
      expect(violations, isEmpty);
    });

    test('CI bypasses violations if logged in baseline', () {
      final baseline = Baseline(
        packages: {
          'dio': const BaselineEntry(
            name: 'dio',
            currentVersion: '5.0.0',
            riskLevel: 'medium',
            riskReasonCodes: ['MAJOR_UPGRADE', 'CONSTRAINT_INCOMPATIBLE'],
          ),
        },
        timestamp: DateTime.now(),
        toolVersion: '1.0.0',
      );

      // Should bypass the major violation as it is baselined
      final violations = CiCommandExecutor.evaluate(baseReport, defaultConfig, baseline);
      expect(violations, isEmpty);
    });

    test('CI fails if package risk escalates above baseline levels', () {
      final baseline = Baseline(
        packages: {
          // baselined as low, but currently it is medium
          'dio': const BaselineEntry(
            name: 'dio',
            currentVersion: '5.0.0',
            riskLevel: 'low',
            riskReasonCodes: ['CONSTRAINT_INCOMPATIBLE'],
          ),
        },
        timestamp: DateTime.now(),
        toolVersion: '1.0.0',
      );

      // Should NOT bypass because level escalated from low -> medium
      final violations = CiCommandExecutor.evaluate(baseReport, defaultConfig, baseline);
      expect(violations.length, equals(1));
      expect(violations.first.code, equals('POLICY_ALLOW_MAJOR_VIOLATION'));
    });
  });
}
