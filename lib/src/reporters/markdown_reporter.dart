import '../models/project_report.dart';
import '../models/risk_models.dart';
import 'reporter.dart';

/// Reporter formatting [ProjectReport] into PR-ready Markdown syntax.
class MarkdownReporter implements Reporter {
  const MarkdownReporter();

  @override
  String render(ProjectReport report) {
    final buffer = StringBuffer();

    buffer.writeln('# Flutter App Update Guard');
    buffer.writeln();
    buffer.writeln('## Summary');
    buffer.writeln();

    // Compute counts
    int safeCount = 0;
    int lowCount = 0;
    int mediumCount = 0;
    int highCount = 0;
    int criticalCount = 0;

    for (final dep in report.dependencies) {
      if (dep.isSkipped) continue;
      switch (dep.risk.level) {
        case RiskLevel.safe:
          safeCount++;
          break;
        case RiskLevel.low:
          lowCount++;
          break;
        case RiskLevel.medium:
          mediumCount++;
          break;
        case RiskLevel.high:
          highCount++;
          break;
        case RiskLevel.critical:
          criticalCount++;
          break;
      }
    }

    buffer.writeln('| Level | Count |');
    buffer.writeln('|---|---:|');
    buffer.writeln('| Safe | $safeCount |');
    buffer.writeln('| Low | $lowCount |');
    buffer.writeln('| Medium | $mediumCount |');
    buffer.writeln('| High | $highCount |');
    buffer.writeln('| Critical | $criticalCount |');
    buffer.writeln();

    // 1. Policy violations
    if (report.policyViolations.isNotEmpty) {
      buffer.writeln('## 🛑 Policy Violations');
      buffer.writeln();
      for (final violation in report.policyViolations) {
        buffer.writeln('- $violation');
      }
      buffer.writeln();
    }

    // 2. Warnings
    if (report.warnings.isNotEmpty) {
      buffer.writeln('## ⚠️ Warnings');
      buffer.writeln();
      for (final warning in report.warnings) {
        buffer.writeln('- $warning');
      }
      buffer.writeln();
    }

    // 3. High/Critical Risk Dependencies detail
    final criticalOrHighDeps = report.dependencies.where((d) {
      if (d.isSkipped) return false;
      return d.risk.level == RiskLevel.critical || d.risk.level == RiskLevel.high;
    }).toList();

    if (criticalOrHighDeps.isNotEmpty) {
      buffer.writeln('## High-risk dependencies');
      buffer.writeln();

      for (final depReport in criticalOrHighDeps) {
        final dep = depReport.dependency;
        buffer.writeln('### ${dep.name}');
        buffer.writeln();
        buffer.writeln('- Current: `${dep.lockedVersion ?? 'unknown'}`');
        buffer.writeln('- Latest: `${depReport.latestVersion ?? 'unknown'}`');
        buffer.writeln('- Risk: **${depReport.risk.level.name.toUpperCase()}**');
        buffer.writeln('- Score: `${depReport.risk.score}`');
        buffer.writeln();

        if (depReport.risk.reasons.isNotEmpty) {
          buffer.writeln('Reasons:');
          buffer.writeln();
          for (final reason in depReport.risk.reasons) {
            buffer.writeln('- ${reason.message}');
          }
          buffer.writeln();
        }
      }
    }

    // 4. Recommendations
    buffer.writeln('## Recommendations');
    buffer.writeln();
    if (report.policyViolations.isNotEmpty) {
      buffer.writeln('❌ **Action required:** Fix the policy violations listed above before proceeding.');
    } else if (criticalOrHighDeps.isNotEmpty) {
      buffer.writeln('⚠️ **Manual review is recommended:** Review the high-risk dependencies before upgrading.');
    } else {
      buffer.writeln('✅ **All packages are clear:** No critical or high-risk updates detected.');
    }
    buffer.writeln();

    return buffer.toString();
  }
}
