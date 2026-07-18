import * as vscode from 'vscode';
import { handleCommandError } from '../services/errorHandler';
import { resolveProjectContext } from '../services/projectContext';
import { UpdateGuardCli } from '../services/updateGuardCli';

export async function runBaselineCommand(
  cli: UpdateGuardCli,
  output: vscode.OutputChannel
): Promise<void> {
  const context = await resolveProjectContext(undefined, true);
  if (!context) {
    void vscode.window.showWarningMessage('Open a Dart/Flutter workspace first.');
    return;
  }

  try {
    const result = await cli.baseline(context.projectPath);
    output.show(true);
    output.appendLine(result);
  } catch (error) {
    handleCommandError(output, 'Baseline command failed', error);
  }
}

