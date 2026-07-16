import * as vscode from 'vscode';

export function handleCommandError(
  output: vscode.OutputChannel,
  title: string,
  error: unknown
): void {
  const message = error instanceof Error ? error.message : String(error);
  output.show(true);
  output.appendLine(`${title}: ${message}`);
  void vscode.window.showErrorMessage(`${title}: ${message}`);
}

