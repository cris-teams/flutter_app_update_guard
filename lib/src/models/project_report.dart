import 'dependency_report.dart';
import 'risk_models.dart';

/// Aggregated report of the entire project's dependencies and update risks.
class ProjectReport {
  final String projectName;
  final DateTime generatedAt;
  final List<DependencyReport> dependencies;
  final List<String> policyViolations;
  final List<String> warnings;

  const ProjectReport({
    required this.projectName,
    required this.generatedAt,
    required this.dependencies,
    required this.policyViolations,
    required this.warnings,
  });

  /// Counts the dependencies by risk level.
  Map<String, int> get summary {
    int safe = 0;
    int low = 0;
    int medium = 0;
    int high = 0;
    int critical = 0;
    int skipped = 0;

    for (final dep in dependencies) {
      if (dep.isSkipped) {
        skipped++;
      } else {
        switch (dep.risk.level) {
          case RiskLevel.safe:
            safe++;
            break;
          case RiskLevel.low:
            low++;
            break;
          case RiskLevel.medium:
            medium++;
            break;
          case RiskLevel.high:
            high++;
            break;
          case RiskLevel.critical:
            critical++;
            break;
        }
      }
    }

    return {
      'safe': safe,
      'low': low,
      'medium': medium,
      'high': high,
      'critical': critical,
      'skipped': skipped,
    };
  }

  /// Whether the project has any policy violations.
  bool get hasPolicyViolations => policyViolations.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'project': projectName,
        'generatedAt': generatedAt.toIso8601String(),
        'summary': summary,
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
        'policyViolations': policyViolations,
        'warnings': warnings,
      };
}
