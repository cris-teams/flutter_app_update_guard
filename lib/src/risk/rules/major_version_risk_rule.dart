import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the latest version is a major version upgrade.
class MajorVersionRiskRule implements RiskRule {
  const MajorVersionRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final current = context.dependency.lockedVersion;
    final latest = context.packageInfo?.latestVersion;

    if (current != null && latest != null) {
      if (latest.major > current.major) {
        return const RiskReason(
          code: 'MAJOR_UPGRADE',
          message: 'Major version upgrade (potential breaking changes)',
          score: 30,
        );
      }
    }
    return null;
  }
}
