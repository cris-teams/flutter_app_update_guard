import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the package is discontinued on pub.dev.
class DiscontinuedRiskRule implements RiskRule {
  const DiscontinuedRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final info = context.packageInfo;
    if (info != null && info.isDiscontinued) {
      final replacement = info.replacedBy;
      final message = replacement != null
          ? 'Package has been marked as discontinued on pub.dev. Replaced by: $replacement'
          : 'Package has been marked as discontinued on pub.dev';
      return RiskReason(
        code: 'DISCONTINUED_PACKAGE',
        message: message,
        score: 40,
      );
    }
    return null;
  }
}
