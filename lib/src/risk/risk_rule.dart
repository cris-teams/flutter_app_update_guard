import '../config/guard_config.dart';
import '../models/dependency_info.dart';
import '../models/package_usage.dart';
import '../models/pub_package_info.dart';
import '../models/risk_models.dart';

/// Context container passed to [RiskRule]s during evaluation.
class DependencyContext {
  /// The local dependency metadata.
  final DependencyInfo dependency;

  /// The pub.dev metadata of the package, if fetched successfully.
  final PubPackageInfo? packageInfo;

  /// The loaded CLI configuration.
  final GuardConfig config;

  /// The project's Dart SDK constraint.
  final String? projectDartSdkConstraint;

  /// The project's Flutter SDK constraint.
  final String? projectFlutterSdkConstraint;

  /// The usage metrics of this package.
  final PackageUsage? usage;

  const DependencyContext({
    required this.dependency,
    this.packageInfo,
    required this.config,
    this.projectDartSdkConstraint,
    this.projectFlutterSdkConstraint,
    this.usage,
  });
}

/// Abstract interface for a rule evaluated by the risk engine.
abstract interface class RiskRule {
  /// Evaluates the given dependency context.
  /// Returns a [RiskReason] if a risk is detected, or `null` otherwise.
  RiskReason? evaluate(DependencyContext context);
}
