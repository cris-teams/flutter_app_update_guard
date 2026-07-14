import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate risk based on the frequency of package usage across the project's source files.
class SourceUsageRiskRule implements RiskRule {
  const SourceUsageRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    final usage = context.usage;
    if (usage == null) return null;

    final totalFiles = usage.totalFiles;

    if (totalFiles >= 50) {
      return RiskReason(
        code: 'HIGH_SOURCE_USAGE',
        message: 'Package is imported/exported by $totalFiles files (>= 50)',
        score: 15,
      );
    } else if (totalFiles >= 25) {
      return RiskReason(
        code: 'MEDIUM_SOURCE_USAGE',
        message: 'Package is imported/exported by $totalFiles files (>= 25)',
        score: 10,
      );
    } else if (totalFiles >= 10) {
      return RiskReason(
        code: 'LOW_SOURCE_USAGE',
        message: 'Package is imported/exported by $totalFiles files (>= 10)',
        score: 5,
      );
    }

    return null;
  }
}
