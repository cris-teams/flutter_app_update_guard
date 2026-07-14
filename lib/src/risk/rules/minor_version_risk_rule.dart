import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the latest version is a minor version upgrade.
class MinorVersionRiskRule implements RiskRule {
  const MinorVersionRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final current = context.dependency.lockedVersion;
    final latest = context.packageInfo?.latestVersion;

    if (current != null && latest != null) {
      if (latest.major == current.major && latest.minor > current.minor) {
        return const RiskReason(
          code: 'MINOR_UPGRADE',
          message: 'Minor version upgrade (new features, potential behavior changes)',
          score: 10,
        );
      }
    }
    return null;
  }
}
