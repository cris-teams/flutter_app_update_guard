import * as vscode from 'vscode';
import { PubspecCodeLensProvider } from '../features/codelens/pubspecCodeLensProvider';
import { updateDiagnostics } from '../features/diagnostics/updateDiagnostics';
import { DependencyTreeProvider } from '../features/tree/dependencyTreeProvider';
import { handleCommandError } from '../services/errorHandler';
import { resolveProjectContext } from '../services/projectContext';
import { UpdateGuardCli } from '../services/updateGuardCli';

export interface CheckCommandContext {
  cli: UpdateGuardCli;
  diagnostics: vscode.DiagnosticCollection;
  treeProvider: DependencyTreeProvider;
  codeLensProvider: PubspecCodeLensProvider;
  output: vscode.OutputChannel;
  uri?: vscode.Uri;
}

export async function runCheckCommand(context: CheckCommandContext): Promise<void> {
  const projectContext = await resolveProjectContext(context.uri);
  if (!projectContext) {
    void vscode.window.showWarningMessage('Open a pubspec.yaml file or a Dart/Flutter workspace first.');
    return;
  }

  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Window,
      title: 'Flutter Update Guard: checking dependencies'
    },
    async () => {
      try {
        const report = await context.cli.check(projectContext.workspaceFolder.uri.fsPath);
        const document = await vscode.workspace.openTextDocument(projectContext.pubspecUri);
        updateDiagnostics(document, report, context.diagnostics);
        context.treeProvider.setReport(report, projectContext.workspaceFolder);
        context.codeLensProvider.refresh();
        context.output.appendLine(`Check completed for ${report.project}. ${formatSummary(report.summary)}`);
      } catch (error) {
        context.treeProvider.setMessage('Unable to run dependency check. See output for details.');
        handleCommandError(context.output, 'Dependency check failed', error);
      }
    }
  );
}

function formatSummary(summary: Record<string, number>): string {
  return Object.entries(summary)
    .map(([level, count]) => `${level}: ${count}`)
    .join(', ');
}

