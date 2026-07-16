import * as vscode from 'vscode';
import { ExtensionController } from './app/extensionController';

let controller: ExtensionController | undefined;

export function activate(context: vscode.ExtensionContext): void {
  controller = new ExtensionController(context);
  controller.activate();
}

export function deactivate(): void {
  controller?.dispose();
  controller = undefined;
}

