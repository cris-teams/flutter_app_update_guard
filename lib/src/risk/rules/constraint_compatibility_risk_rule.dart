import 'package:pub_semver/pub_semver.dart';

import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the current project constraint allows the latest version available on pub.dev.
class ConstraintCompatibilityRiskRule implements RiskRule {
  const ConstraintCompatibilityRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final constraintStr = context.dependency.constraint;
    final latest = context.packageInfo?.latestVersion;

    if (constraintStr != null && latest != null) {
      try {
        final constraint = VersionConstraint.parse(constraintStr);
        if (!constraint.allows(latest)) {
          return RiskReason(
            code: 'CONSTRAINT_INCOMPATIBLE',
            message: 'Current constraint "$constraintStr" does not allow the latest version ($latest)',
            score: 15,
          );
        }
      } catch (_) {
        // Parse error, treat as compatible or skip rule
      }
    }
    return null;
  }
}
