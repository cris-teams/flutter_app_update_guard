import '../analyzers/version_classifier.dart';
import '../config/baseline_manager.dart';
import '../config/guard_config.dart';
import '../models/policy_violation.dart';
import '../models/project_report.dart';
import '../models/risk_models.dart';

/// Command executor verifying project compliance against CI policies and baselines.
class CiCommandExecutor {
  /// Evaluates compliance of a [ProjectReport] against configured [policies] and an optional [baseline].
  /// Returns a list of all active [PolicyViolation]s.
  static List<PolicyViolation> evaluate(
    ProjectReport report,
    GuardConfig config, [
    Baseline? baseline,
  ]) {
    final violations = <PolicyViolation>[];

    int criticalCount = 0;
    int highCount = 0;
    int mediumCount = 0;

    for (final depReport in report.dependencies) {
      if (depReport.isSkipped) continue;

      final pkgName = depReport.dependency.name;
      final risk = depReport.risk;

      if (risk.level == RiskLevel.critical) criticalCount++;
      if (risk.level == RiskLevel.high) highCount++;
      if (risk.level == RiskLevel.medium) mediumCount++;

      // 1. Allow prerelease policy check
      if (!config.policies.allowPrerelease &&
          depReport.updateType == UpdateType.prerelease &&
          (depReport.dependency.lockedVersion == null ||
              !depReport.dependency.lockedVersion!.isPreRelease)) {
        violations.add(PolicyViolation(
          code: 'POLICY_ALLOW_PRERELEASE_VIOLATION',
          message:
              "Package '$pkgName' resolves to a prerelease version '${depReport.latestVersion}' which is not allowed by policy.",
          packageName: pkgName,
        ));
      }

      // 2. Allow major updates policy check
      if (!config.policies.allowMajorUpdates &&
          depReport.updateType == UpdateType.major) {
        violations.add(PolicyViolation(
          code: 'POLICY_ALLOW_MAJOR_VIOLATION',
          message:
              "Package '$pkgName' has a major version update to '${depReport.latestVersion}' which is not allowed by policy.",
          packageName: pkgName,
        ));
      }

      // 3. Fail on discontinued policy check
      if (config.policies.failOnDiscontinued &&
          risk.reasons.any((r) => r.code == 'DISCONTINUED')) {
        violations.add(PolicyViolation(
          code: 'POLICY_DISCONTINUED_VIOLATION',
          message:
              "Package '$pkgName' has been discontinued, which is not allowed by policy.",
          packageName: pkgName,
        ));
      }

      // 4. Fail on SDK incompatible policy check
      if (config.policies.failOnSdkIncompatible &&
          risk.reasons.any((r) =>
              r.code == 'SDK_INCOMPATIBLE' ||
              r.code == 'DART_SDK_INCOMPATIBLE' ||
              r.code == 'FLUTTER_SDK_INCOMPATIBLE')) {
        violations.add(PolicyViolation(
          code: 'POLICY_SDK_INCOMPATIBLE_VIOLATION',
          message:
              "Package '$pkgName' has SDK incompatibility, which is not allowed by policy.",
          packageName: pkgName,
        ));
      }

      // 5. Fail on specific risk level configuration (risk.fail_on)
      if (config.risk.failOn.contains(risk.level)) {
        violations.add(PolicyViolation(
          code: 'POLICY_FAIL_ON_RISK_LEVEL_VIOLATION',
          message:
              "Package '$pkgName' has a risk level of '${risk.level.name}' which is marked as fail_on.",
          packageName: pkgName,
        ));
      }
    }

    // 6. Max critical count exceeded
    if (criticalCount > config.policies.maxCriticalDependencies) {
      violations.add(PolicyViolation(
        code: 'POLICY_MAX_CRITICAL_EXCEEDED',
        message:
            'Number of critical risk dependencies ($criticalCount) exceeds the maximum allowed (${config.policies.maxCriticalDependencies}).',
      ));
    }

    // 7. Max high count exceeded
    if (highCount > config.policies.maxHighRiskDependencies) {
      violations.add(PolicyViolation(
        code: 'POLICY_MAX_HIGH_EXCEEDED',
        message:
            'Number of high risk dependencies ($highCount) exceeds the maximum allowed (${config.policies.maxHighRiskDependencies}).',
      ));
    }

    // 8. Max medium count exceeded
    if (mediumCount > config.policies.maxMediumRiskDependencies) {
      violations.add(PolicyViolation(
        code: 'POLICY_MAX_MEDIUM_EXCEEDED',
        message:
            'Number of medium risk dependencies ($mediumCount) exceeds the maximum allowed (${config.policies.maxMediumRiskDependencies}).',
      ));
    }

    // Apply baseline filtering if provided
    if (baseline != null && baseline.packages.isNotEmpty) {
      final filtered = <PolicyViolation>[];
      for (final v in violations) {
        if (v.packageName == null) {
          // Global violations (max counts) are not associated with single packages, so they cannot be bypassed
          filtered.add(v);
          continue;
        }

        final pkgName = v.packageName!;
        final baseEntry = baseline.packages[pkgName];
        if (baseEntry == null) {
          filtered.add(v);
          continue;
        }

        final depReport = report.dependencies.firstWhere((d) => d.dependency.name == pkgName);
        final currentLevel = depReport.risk.level;
        final baseLevel = RiskLevel.parse(baseEntry.riskLevel);

        // Escalation condition 1: Risk level increased
        if (currentLevel.index > baseLevel.index) {
          filtered.add(v);
          continue;
        }

        // Escalation condition 2: Newly discontinued
        final isDiscontinued = depReport.risk.reasons.any((r) => r.code == 'DISCONTINUED');
        final wasDiscontinued = baseEntry.riskReasonCodes.contains('DISCONTINUED');
        if (isDiscontinued && !wasDiscontinued) {
          filtered.add(v);
          continue;
        }

        // Escalation condition 3: Newly SDK incompatible
        final isSdkIncompatible = depReport.risk.reasons.any((r) =>
            r.code == 'SDK_INCOMPATIBLE' ||
            r.code == 'DART_SDK_INCOMPATIBLE' ||
            r.code == 'FLUTTER_SDK_INCOMPATIBLE');
        final wasSdkIncompatible = baseEntry.riskReasonCodes.contains('SDK_INCOMPATIBLE') ||
            baseEntry.riskReasonCodes.contains('DART_SDK_INCOMPATIBLE') ||
            baseEntry.riskReasonCodes.contains('FLUTTER_SDK_INCOMPATIBLE');
        if (isSdkIncompatible && !wasSdkIncompatible) {
          filtered.add(v);
          continue;
        }

        // Escalation condition 4: A new risk reason code appears
        bool hasNewReason = false;
        for (final r in depReport.risk.reasons) {
          if (!baseEntry.riskReasonCodes.contains(r.code)) {
            hasNewReason = true;
            break;
          }
        }
        if (hasNewReason) {
          filtered.add(v);
          continue;
        }

        // If none of the escalation conditions were met, we skip (bypass) the violation
      }
      return filtered;
    }

    return violations;
  }
}
