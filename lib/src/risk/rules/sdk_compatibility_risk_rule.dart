import 'package:pub_semver/pub_semver.dart';

import '../../models/risk_models.dart';
import '../risk_rule.dart';

/// Rule to evaluate if the latest package version is compatible with the project's Dart/Flutter SDK constraints.
class SdkCompatibilityRiskRule implements RiskRule {
  const SdkCompatibilityRiskRule();

  @override
  RiskReason? evaluate(DependencyContext context) {
    if (!context.dependency.isHosted) return null;

    final info = context.packageInfo;
    if (info == null) return null;

    // 1. Check Dart SDK compatibility
    final projDartStr = context.projectDartSdkConstraint;
    final pkgDartStr = info.dartSdkConstraint;

    if (projDartStr != null && pkgDartStr != null) {
      try {
        final projConstraint = VersionConstraint.parse(projDartStr);
        final pkgConstraint = VersionConstraint.parse(pkgDartStr);
        final intersection = projConstraint.intersect(pkgConstraint);

        if (intersection.isEmpty) {
          return const RiskReason(
            code: 'DART_SDK_INCOMPATIBLE',
            message: 'Latest version is incompatible with the project Dart SDK constraint',
            score: 40,
          );
        }
      } catch (_) {
        // Ignore parsing errors, treat as compatible/unknown
      }
    }

    // 2. Check Flutter SDK compatibility
    final projFlutterStr = context.projectFlutterSdkConstraint;
    final pkgFlutterStr = info.flutterSdkConstraint;

    if (projFlutterStr != null && pkgFlutterStr != null) {
      try {
        final projConstraint = VersionConstraint.parse(projFlutterStr);
        final pkgConstraint = VersionConstraint.parse(pkgFlutterStr);
        final intersection = projConstraint.intersect(pkgConstraint);

        if (intersection.isEmpty) {
          return const RiskReason(
            code: 'FLUTTER_SDK_INCOMPATIBLE',
            message: 'Latest version is incompatible with the project Flutter SDK constraint',
            score: 40,
          );
        }
      } catch (_) {
        // Ignore parsing errors, treat as compatible/unknown
      }
    }

    return null;
  }
}
