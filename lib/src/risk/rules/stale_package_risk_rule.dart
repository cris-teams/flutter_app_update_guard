import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the package release date is older than configured stale threshold.
class StalePackageRiskRule implements RiskRule {
  const StalePackageRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final info = context.packageInfo;
    if (info != null) {
      final daysSinceLastRelease = DateTime.now().difference(info.latestPublished).inDays;
      final threshold = context.config.maintenance.staleAfterDays;

      if (daysSinceLastRelease > threshold) {
        return RiskReason(
          code: 'STALE_PACKAGE',
          message: 'Package has not published a release for more than $threshold days ($daysSinceLastRelease days ago)',
          score: 15,
        );
      }
    }
    return null;
  }
}
