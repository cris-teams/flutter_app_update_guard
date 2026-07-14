import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the latest version is a pre-release version.
class PrereleaseRiskRule implements RiskRule {
  const PrereleaseRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final latest = context.packageInfo?.latestVersion;

    if (latest != null && latest.isPreRelease) {
      return const RiskReason(
        code: 'PRERELEASE_VERSION',
        message: 'Target is a pre-release version (may be unstable)',
        score: 10,
      );
    }
    return null;
  }
}
