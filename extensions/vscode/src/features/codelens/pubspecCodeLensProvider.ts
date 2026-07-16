import * as vscode from 'vscode';
import { findDependencyLines, isPubspecDocument } from '../../workspace/pubspec';

export class PubspecCodeLensProvider implements vscode.CodeLensProvider {
  private readonly onDidChangeCodeLensesEmitter = new vscode.EventEmitter<void>();
  readonly onDidChangeCodeLenses = this.onDidChangeCodeLensesEmitter.event;

  refresh(): void {
    this.onDidChangeCodeLensesEmitter.fire();
  }

  provideCodeLenses(document: vscode.TextDocument): vscode.CodeLens[] {
    if (!isPubspecDocument(document)) {
      return [];
    }

    const codeLenses: vscode.CodeLens[] = [];
    for (const dependency of findDependencyLines(document).values()) {
      const range = new vscode.Range(
        dependency.line,
        dependency.startCharacter,
        dependency.line,
        dependency.endCharacter
      );

      codeLenses.push(
        new vscode.CodeLens(range, {
          title: 'Simulate Upgrade',
          command: 'flutter_app_update_guard.simulate',
          arguments: [dependency.name, document.uri]
        }),
        new vscode.CodeLens(range, {
          title: 'Inspect Package',
          command: 'flutter_app_update_guard.inspect',
          arguments: [dependency.name, document.uri]
        })
      );
    }

    return codeLenses;
  }
}
