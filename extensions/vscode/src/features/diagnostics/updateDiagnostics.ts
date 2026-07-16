import * as vscode from 'vscode';
import { CheckReport, DependencyReport, RiskLevel } from '../../domain/updateGuard';
import { findDependencyLines } from '../../workspace/pubspec';

const riskRank: Record<RiskLevel, number> = {
  safe: 0,
  low: 1,
  medium: 2,
  high: 3,
  critical: 4
};

export function updateDiagnostics(
  document: vscode.TextDocument,
  report: CheckReport,
  collection: vscode.DiagnosticCollection
): void {
  const minimumRisk = vscode.workspace
    .getConfiguration('flutter_app_update_guard')
    .get<RiskLevel>('diagnosticMinimumRisk', 'high');
  const lines = findDependencyLines(document);
  const diagnostics: vscode.Diagnostic[] = [];
  const policyViolations = groupPolicyViolationsByPackage(report.policyViolations);

  for (const dependency of report.dependencies) {
    const dependencyPolicyViolations = policyViolations.get(dependency.name) ?? [];
    if (!shouldShowDiagnostic(dependency, minimumRisk) && dependencyPolicyViolations.length === 0) {
      continue;
    }

    const dependencyLine = lines.get(dependency.name);
    if (!dependencyLine) {
      continue;
    }

    const range = new vscode.Range(
      dependencyLine.line,
      dependencyLine.startCharacter,
      dependencyLine.line,
      dependencyLine.endCharacter
    );
    const reasons = dependency.risk.reasons.map((reason) => reason.message);
    const messageParts = [
      `${dependency.name} has ${dependency.risk.level} update risk (score: ${dependency.risk.score}).`,
      ...reasons,
      ...dependencyPolicyViolations
    ];
    const diagnostic = new vscode.Diagnostic(
      range,
      messageParts.join(' ').trim(),
      dependency.risk.level === 'critical' || dependencyPolicyViolations.length > 0
        ? vscode.DiagnosticSeverity.Error
        : vscode.DiagnosticSeverity.Warning
    );
    diagnostic.source = 'flutter_app_update_guard';
    diagnostics.push(diagnostic);
  }

  collection.set(document.uri, diagnostics);
}

function shouldShowDiagnostic(dependency: DependencyReport, minimumRisk: RiskLevel): boolean {
  if (dependency.isSkipped) {
    return false;
  }

  return riskRank[dependency.risk.level] >= riskRank[minimumRisk];
}

function groupPolicyViolationsByPackage(violations: string[]): Map<string, string[]> {
  const byPackage = new Map<string, string[]>();
  for (const violation of violations) {
    const match = /Package '([^']+)'/.exec(violation);
    if (!match) {
      continue;
    }

    const packageName = match[1];
    const current = byPackage.get(packageName) ?? [];
    current.push(violation);
    byPackage.set(packageName, current);
  }

  return byPackage;
}
