import 'package:pub_semver/pub_semver.dart';
import '../analyzers/version_classifier.dart';
import 'dependency_info.dart';
import 'risk_models.dart';

/// SDK compatibility status of a dependency.
enum SdkCompatibility {
  compatible,
  incompatible,
  unknown,
}

/// Evaluation report for a single dependency.
class DependencyReport {
  final DependencyInfo dependency;
  final Version? latestVersion;
  final UpdateType updateType;
  final DependencyRisk risk;
  final bool isSkipped;
  final String? skipReason;
  final SdkCompatibility sdkCompatibility;

  const DependencyReport({
    required this.dependency,
    this.latestVersion,
    required this.updateType,
    required this.risk,
    required this.isSkipped,
    this.skipReason,
    required this.sdkCompatibility,
  });

  Map<String, dynamic> toJson() => {
        'dependency': dependency.toJson(),
        'latestVersion': latestVersion?.toString(),
        'updateType': updateType.name,
        'risk': risk.toJson(),
        'isSkipped': isSkipped,
        'skipReason': skipReason,
        'sdkCompatibility': sdkCompatibility.name,
      };
}
