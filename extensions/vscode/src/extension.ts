import * as vscode from 'vscode';
import { ExtensionController } from './app/extensionController';
import { setExtensionContext } from './services/projectContext';

let controller: ExtensionController | undefined;

export function activate(context: vscode.ExtensionContext): void {
  setExtensionContext(context);
  controller = new ExtensionController(context);
  controller.activate();
}

export function deactivate(): void {
  controller?.dispose();
  controller = undefined;
}

