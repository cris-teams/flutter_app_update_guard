import '../models/project_report.dart';
import '../models/risk_models.dart';
import 'reporter.dart';

/// Console reporter that generates human-readable ASCII tables.
/// Supports ANSI color output which can be disabled.
class ConsoleReporter implements Reporter {
  final bool useColor;

  const ConsoleReporter({this.useColor = true});

  // ANSI codes
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String green = '\x1B[32m';
  static const String blue = '\x1B[34m';
  static const String yellow = '\x1B[33m';
  static const String red = '\x1B[31m';
  static const String magenta = '\x1B[35m';
  static const String grey = '\x1B[90m';

  String _colorize(String text, String ansiCode) {
    if (!useColor) return text;
    return '$ansiCode$text$reset';
  }

  String _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return green;
      case RiskLevel.low:
        return blue;
      case RiskLevel.medium:
        return yellow;
      case RiskLevel.high:
        return red;
      case RiskLevel.critical:
        return magenta;
    }
  }

  @override
  String render(ProjectReport report) {
    final buffer = StringBuffer();
    buffer.writeln(_colorize('Flutter App Update Guard', bold));
    buffer.writeln();

    // Table headers
    final headers = ['Package', 'Current', 'Latest', 'Update', 'Risk'];
    final widths = [20, 12, 12, 10, 10];

    // Calculate maximum widths based on contents to prevent truncation
    for (final dep in report.dependencies) {
      if (dep.dependency.name.length > widths[0]) {
        widths[0] = dep.dependency.name.length;
      }
      final curStr = dep.dependency.lockedVersion?.toString() ?? dep.dependency.kind.name;
      if (curStr.length > widths[1]) {
        widths[1] = curStr.length;
      }
      final latestStr = dep.latestVersion?.toString() ?? '-';
      if (latestStr.length > widths[2]) {
        widths[2] = latestStr.length;
      }
      final updateStr = dep.isSkipped ? 'skipped' : dep.updateType.name;
      if (updateStr.length > widths[3]) {
        widths[3] = updateStr.length;
      }
      final riskStr = dep.isSkipped ? 'skipped' : dep.risk.level.name;
      if (riskStr.length > widths[4]) {
        widths[4] = riskStr.length;
      }
    }

    // Add extra padding spaces
    for (int i = 0; i < widths.length; i++) {
      widths[i] += 2;
    }

    // Print Header
    final headerLine = StringBuffer();
    for (int i = 0; i < headers.length; i++) {
      headerLine.write(_padRight(headers[i], widths[i]));
    }
    buffer.writeln(_colorize(headerLine.toString(), bold));

    // Print rows
    for (final dep in report.dependencies) {
      final name = dep.dependency.name;
      final current = dep.dependency.lockedVersion?.toString() ?? dep.dependency.kind.name;
      final latest = dep.latestVersion?.toString() ?? '-';
      final update = dep.isSkipped ? 'skipped' : dep.updateType.name;
      final risk = dep.isSkipped ? 'skipped' : dep.risk.level.name;

      final nameStr = _padRight(name, widths[0]);
      final currentStr = _padRight(current, widths[1]);
      final latestStr = _padRight(latest, widths[2]);

      final updateColor = dep.isSkipped
          ? grey
          : (dep.updateType.name == 'major' ? red : (dep.updateType.name == 'minor' ? yellow : reset));
      final updateStr = _colorize(_padRight(update, widths[3]), updateColor);

      final riskColor = dep.isSkipped ? grey : _getRiskColor(dep.risk.level);
      final riskStr = _colorize(_padRight(risk, widths[4]), riskColor);

      buffer.writeln('$nameStr$currentStr$latestStr$updateStr$riskStr');
    }

    buffer.writeln();

    // Summary Section
    final s = report.summary;
    buffer.writeln(_colorize('Summary', bold));
    buffer.writeln('  Safe:      ${_colorize(s['safe'].toString(), green)}');
    buffer.writeln('  Low:       ${_colorize(s['low'].toString(), blue)}');
    buffer.writeln('  Medium:    ${_colorize(s['medium'].toString(), yellow)}');
    buffer.writeln('  High:      ${_colorize(s['high'].toString(), red)}');
    buffer.writeln('  Critical:  ${_colorize(s['critical'].toString(), magenta)}');
    buffer.writeln('  Skipped:   ${_colorize(s['skipped'].toString(), grey)}');
    buffer.writeln();

    // Explain Risks Section
    final riskDeps = report.dependencies.where((d) => !d.isSkipped && d.risk.score > 0).toList();
    if (riskDeps.isNotEmpty) {
      buffer.writeln(_colorize('Risk Breakdown & Explanations', bold));
      for (final dep in riskDeps) {
        final riskColor = _getRiskColor(dep.risk.level);
        buffer.writeln(
          '${_colorize(dep.dependency.name, bold)} '
          '(${_colorize(dep.risk.level.name, riskColor)} risk, score: ${dep.risk.score})',
        );
        for (final reason in dep.risk.reasons) {
          buffer.writeln('  - ${reason.message} (+${reason.score})');
        }
        buffer.writeln();
      }
    }

    // Policy Violations Section
    if (report.policyViolations.isNotEmpty) {
      buffer.writeln(_colorize('Policy Violations', red));
      for (final violation in report.policyViolations) {
        buffer.writeln('  [!] $violation');
      }
      buffer.writeln();
    }

    // Warnings Section
    if (report.warnings.isNotEmpty) {
      buffer.writeln(_colorize('Warnings', yellow));
      for (final warn in report.warnings) {
        buffer.writeln('  [*] $warn');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _padRight(String val, int width) {
    if (val.length >= width) return val;
    return val + ' ' * (width - val.length);
  }
}
