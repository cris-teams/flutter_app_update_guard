import * as vscode from 'vscode';
import { handleCommandError } from '../services/errorHandler';
import { resolveProjectContext } from '../services/projectContext';
import { UpdateGuardCli } from '../services/updateGuardCli';
import { findDependencyLines } from '../workspace/pubspec';

export type PackageCommand = 'inspect' | 'simulate';

export async function runPackageCommand(
  cli: UpdateGuardCli,
  output: vscode.OutputChannel,
  command: PackageCommand,
  packageName?: string,
  uri?: vscode.Uri
): Promise<void> {
  const context = await resolveProjectContext(uri);
  if (!context) {
    void vscode.window.showWarningMessage('Open a Dart/Flutter workspace first.');
    return;
  }

  const selectedPackage = packageName ?? await pickPackageName(context.pubspecUri);
  if (!selectedPackage) {
    return;
  }

  try {
    const result = command === 'inspect'
      ? await cli.inspect(context.workspaceFolder.uri.fsPath, selectedPackage)
      : await cli.simulate(context.workspaceFolder.uri.fsPath, selectedPackage);
    output.show(true);
    output.appendLine(result);
  } catch (error) {
    handleCommandError(output, `${command} command failed`, error);
  }
}

async function pickPackageName(pubspecUri: vscode.Uri): Promise<string | undefined> {
  const document = await vscode.workspace.openTextDocument(pubspecUri);
  const names = [...findDependencyLines(document).keys()];
  return vscode.window.showQuickPick([...new Set(names)], {
    placeHolder: 'Select a dependency'
  });
}

