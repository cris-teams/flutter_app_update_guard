import '../config/guard_config.dart';
import '../models/risk_models.dart';
import 'risk_rule.dart';
import 'rules/constraint_compatibility_risk_rule.dart';
import 'rules/discontinued_risk_rule.dart';
import 'rules/major_version_risk_rule.dart';
import 'rules/minor_version_risk_rule.dart';
import 'rules/prerelease_risk_rule.dart';
import 'rules/sdk_compatibility_risk_rule.dart';
import 'rules/source_usage_risk_rule.dart';
import 'rules/stale_package_risk_rule.dart';

/// Engine responsible for evaluating dependency context against a list of risk rules.
class RiskEngine {
  final List<RiskRule> rules;

  const RiskEngine(this.rules);

  /// Creates a [RiskEngine] with rules enabled based on [GuardConfig].
  factory RiskEngine.fromConfig(GuardConfig config) {
    final activeRules = <RiskRule>[];
    final checks = config.checks;

    if (checks.outdated) {
      activeRules.add(const MajorVersionRiskRule());
      activeRules.add(const MinorVersionRiskRule());
      activeRules.add(const PrereleaseRiskRule());
      activeRules.add(const ConstraintCompatibilityRiskRule());
    }

    if (checks.discontinued) {
      activeRules.add(const DiscontinuedRiskRule());
    }

    if (checks.maintenance) {
      activeRules.add(const StalePackageRiskRule());
    }

    if (checks.sdkCompatibility) {
      activeRules.add(const SdkCompatibilityRiskRule());
    }

    if (checks.sourceUsage) {
      activeRules.add(const SourceUsageRiskRule());
    }

    return RiskEngine(activeRules);
  }

  /// Evaluates the risk of a dependency.
  DependencyRisk evaluate(DependencyContext context) {
    // Non-hosted dependencies (git, path, sdk) do not have risk evaluation in MVP.
    if (!context.dependency.isHosted) {
      return DependencyRisk.safe();
    }

    final reasons = <RiskReason>[];

    for (final rule in rules) {
      final reason = rule.evaluate(context);
      if (reason != null) {
        reasons.add(reason);
      }
    }

    int totalScore = reasons.fold(0, (sum, r) => sum + r.score);
    if (totalScore > 100) {
      totalScore = 100;
    }

    return DependencyRisk(
      score: totalScore,
      level: RiskLevel.fromScore(totalScore),
      reasons: reasons,
    );
  }
}
