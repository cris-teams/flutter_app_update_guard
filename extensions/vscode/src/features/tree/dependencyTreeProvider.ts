import * as vscode from 'vscode';
import { CheckReport, DependencyReport } from '../../domain/updateGuard';

type TreeNode = RiskGroupNode | DependencyNode | ReasonNode | MessageNode;

const riskOrder = ['critical', 'high', 'medium', 'low', 'safe', 'skipped'] as const;

export class DependencyTreeProvider implements vscode.TreeDataProvider<TreeNode> {
  private readonly onDidChangeTreeDataEmitter = new vscode.EventEmitter<TreeNode | undefined | void>();
  readonly onDidChangeTreeData = this.onDidChangeTreeDataEmitter.event;

  private report?: CheckReport;
  private workspaceFolder?: vscode.WorkspaceFolder;
  private statusMessage = 'Run a dependency check to populate this view.';

  setReport(report: CheckReport, workspaceFolder: vscode.WorkspaceFolder): void {
    this.report = report;
    this.workspaceFolder = workspaceFolder;
    this.statusMessage = '';
    this.onDidChangeTreeDataEmitter.fire();
  }

  setMessage(message: string): void {
    this.report = undefined;
    this.statusMessage = message;
    this.onDidChangeTreeDataEmitter.fire();
  }

  getTreeItem(element: TreeNode): vscode.TreeItem {
    if (element instanceof RiskGroupNode) {
      const item = new vscode.TreeItem(
        element.label,
        vscode.TreeItemCollapsibleState.Expanded
      );
      item.description = `${element.dependencies.length}`;
      item.tooltip = `${element.dependencies.length} dependencies`;
      item.iconPath = new vscode.ThemeIcon(
        iconForRisk(element.level),
        colorForRisk(element.level)
      );
      return item;
    }

    if (element instanceof DependencyNode) {
      const item = new vscode.TreeItem(
        dependencyLabel(element.dependency),
        element.dependency.risk.reasons.length > 0
          ? vscode.TreeItemCollapsibleState.Collapsed
          : vscode.TreeItemCollapsibleState.None
      );
      item.description = describeDependency(element.dependency);
      item.tooltip = dependencyTooltip(element.dependency);
      item.contextValue = 'dependency';
      item.command = {
        command: 'flutter_app_update_guard.inspect',
        title: 'Inspect Package',
        arguments: [element.dependency.name, this.workspaceFolder?.uri]
      };
      item.iconPath = new vscode.ThemeIcon(
        iconForRisk(levelForDependency(element.dependency)),
        colorForRisk(levelForDependency(element.dependency))
      );
      return item;
    }

    if (element instanceof ReasonNode) {
      const item = new vscode.TreeItem(
        element.reason.message,
        vscode.TreeItemCollapsibleState.None
      );
      item.description = `${element.reason.code} +${element.reason.score}`;
      item.iconPath = new vscode.ThemeIcon('debug-breakpoint-log', new vscode.ThemeColor('charts.yellow'));
      return item;
    }

    return new vscode.TreeItem(element.message, vscode.TreeItemCollapsibleState.None);
  }

  getChildren(element?: TreeNode): TreeNode[] {
    if (element instanceof RiskGroupNode) {
      return element.dependencies
        .sort((a, b) => b.risk.score - a.risk.score || a.name.localeCompare(b.name))
        .map((dependency) => new DependencyNode(dependency));
    }

    if (element instanceof DependencyNode) {
      return element.dependency.risk.reasons.map((reason) => new ReasonNode(reason));
    }

    if (!this.report) {
      return [new MessageNode(this.statusMessage)];
    }

    return riskOrder
      .map((level) => {
        const dependencies = this.report!.dependencies.filter((dependency) => {
          return levelForDependency(dependency) === level;
        });
        return dependencies.length > 0 ? new RiskGroupNode(level, dependencies) : undefined;
      })
      .filter((node): node is RiskGroupNode => node !== undefined);
  }
}

class RiskGroupNode {
  readonly label: string;

  constructor(
    readonly level: string,
    readonly dependencies: DependencyReport[]
  ) {
    this.label = `${level.toUpperCase()} RISK`;
  }
}

class DependencyNode {
  constructor(readonly dependency: DependencyReport) {}
}

class ReasonNode {
  constructor(readonly reason: { code: string; message: string; score: number }) {}
}

class MessageNode {
  constructor(readonly message: string) {}
}

function describeDependency(dependency: DependencyReport): string {
  if (dependency.isSkipped) {
    return dependency.skipReason ?? 'skipped';
  }

  const latest = dependency.latestVersion && dependency.latestVersion !== dependency.currentVersion
    ? ` -> ${dependency.latestVersion}`
    : '';
  const updateType = dependency.updateType !== 'none' ? ` ${dependency.updateType}` : '';
  return `${dependency.currentVersion}${latest}${updateType}`;
}

function dependencyTooltip(dependency: DependencyReport): string {
  const reasons = dependency.risk.reasons.map((reason) => `- ${reason.message}`).join('\n');
  return [
    `${dependency.name}`,
    `Section: ${dependency.section}`,
    `Risk: ${dependency.risk.level} (${dependency.risk.score})`,
    dependency.latestVersion ? `Latest: ${dependency.latestVersion}` : undefined,
    reasons.length > 0 ? reasons : undefined
  ].filter(Boolean).join('\n');
}

function iconForRisk(level: string): string {
  switch (level) {
    case 'critical':
      return 'error';
    case 'high':
      return 'warning';
    case 'medium':
      return 'alert';
    case 'low':
      return 'info';
    case 'skipped':
      return 'debug-step-over';
    default:
      return 'pass';
  }
}

function colorForRisk(level: string): vscode.ThemeColor {
  switch (level) {
    case 'critical':
      return new vscode.ThemeColor('charts.red');
    case 'high':
      return new vscode.ThemeColor('charts.orange');
    case 'medium':
      return new vscode.ThemeColor('charts.yellow');
    case 'low':
      return new vscode.ThemeColor('charts.blue');
    case 'skipped':
      return new vscode.ThemeColor('descriptionForeground');
    default:
      return new vscode.ThemeColor('charts.green');
  }
}

function levelForDependency(dependency: DependencyReport): string {
  return dependency.isSkipped ? 'skipped' : dependency.risk.level;
}

function dependencyLabel(dependency: DependencyReport): string {
  if (dependency.isSkipped) {
    return dependency.name;
  }

  return `${dependency.name}  ${dependency.risk.score}`;
}
