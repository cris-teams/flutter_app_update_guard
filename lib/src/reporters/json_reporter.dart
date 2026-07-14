import 'dart:convert';
import '../models/project_report.dart';
import 'reporter.dart';

/// JSON reporter generating machine-readable JSON outputs.
class JsonReporter implements Reporter {
  const JsonReporter();

  @override
  String render(ProjectReport report) {
    final Map<String, dynamic> data = {
      'project': report.projectName,
      'generatedAt': report.generatedAt.toUtc().toIso8601String(),
      'summary': report.summary,
      'dependencies': report.dependencies.map((dep) {
        final currentVer = dep.dependency.lockedVersion?.toString() ?? dep.dependency.kind.name;
        final latestVer = dep.latestVersion?.toString();

        return {
          'name': dep.dependency.name,
          'currentVersion': currentVer,
          'latestVersion': latestVer,
          'updateType': dep.updateType.name,
          'risk': {
            'score': dep.risk.score,
            'level': dep.risk.level.name,
            'reasons': dep.risk.reasons.map((r) => {
              'code': r.code,
              'message': r.message,
              'score': r.score,
            }).toList(),
          },
          'kind': dep.dependency.kind.name,
          'section': dep.dependency.section.name,
          'constraint': dep.dependency.constraint,
          'sdkCompatibility': dep.sdkCompatibility.name,
          'isSkipped': dep.isSkipped,
          'skipReason': dep.skipReason,
        };
      }).toList(),
      'policyViolations': report.policyViolations,
      'warnings': report.warnings,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
