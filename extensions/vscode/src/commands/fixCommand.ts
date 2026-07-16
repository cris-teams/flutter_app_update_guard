import * as vscode from 'vscode';
import { handleCommandError } from '../services/errorHandler';
import { resolveProjectContext } from '../services/projectContext';
import { UpdateGuardCli } from '../services/updateGuardCli';

const dryRunChoice = 'Preview only';
const applyChoice = 'Apply safe updates';

export async function runFixCommand(
  cli: UpdateGuardCli,
  output: vscode.OutputChannel
): Promise<void> {
  const context = await resolveProjectContext();
  if (!context) {
    void vscode.window.showWarningMessage('Open a Dart/Flutter workspace first.');
    return;
  }

  const choice = await vscode.window.showQuickPick([dryRunChoice, applyChoice], {
    placeHolder: 'Choose how to run flutter_app_update_guard fix'
  });
  if (!choice) {
    return;
  }

  try {
    const result = await cli.fix(context.workspaceFolder.uri.fsPath, choice === dryRunChoice);
    output.show(true);
    output.appendLine(result);
  } catch (error) {
    handleCommandError(output, 'Fix command failed', error);
  }
}

