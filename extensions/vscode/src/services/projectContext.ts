import * as path from 'path';
import * as vscode from 'vscode';
import { isPubspecDocument } from '../workspace/pubspec';

export interface ProjectContext {
  workspaceFolder: vscode.WorkspaceFolder;
  pubspecUri: vscode.Uri;
  projectPath: string;
}

let extensionContext: vscode.ExtensionContext | undefined;

export function setExtensionContext(context: vscode.ExtensionContext): void {
  extensionContext = context;
}

export async function resolveProjectContext(
  uri?: vscode.Uri,
  promptIfMultiple = false
): Promise<ProjectContext | undefined> {
  let candidateUri = uri;

  // 1. If no URI is provided, check workspaceState for a pinned/selected one
  if (!candidateUri && extensionContext) {
    const selectedUriStr = extensionContext.workspaceState.get<string>('selectedPubspecUri');
    if (selectedUriStr) {
      try {
        const parsed = vscode.Uri.parse(selectedUriStr);
        await vscode.workspace.fs.stat(parsed);
        candidateUri = parsed;
      } catch {
        // Pinned URI no longer exists, clear it
        await extensionContext.workspaceState.update('selectedPubspecUri', undefined);
      }
    }
  }

  // 2. If still no URI, check the active editor
  if (!candidateUri) {
    const activeDoc = vscode.window.activeTextEditor?.document;
    if (activeDoc && isPubspecDocument(activeDoc)) {
      candidateUri = activeDoc.uri;
    }
  }

  // Resolve workspace folder
  const workspaceFolder = candidateUri
    ? vscode.workspace.getWorkspaceFolder(candidateUri)
    : vscode.workspace.workspaceFolders?.[0];

  if (!workspaceFolder) {
    return undefined;
  }

  // 3. If candidateUri is specified (and exists), return its context
  if (candidateUri && path.basename(candidateUri.fsPath) === 'pubspec.yaml') {
    try {
      await vscode.workspace.fs.stat(candidateUri);
      return {
        workspaceFolder,
        pubspecUri: candidateUri,
        projectPath: path.dirname(candidateUri.fsPath)
      };
    } catch {
      // ignore and fallback
    }
  }

  // 4. Fallback: Find all pubspec.yaml files in the workspace
  const uris = await vscode.workspace.findFiles('**/pubspec.yaml', '**/node_modules/**');
  if (uris.length === 0) {
    return undefined;
  }

  if (uris.length === 1) {
    const singleUri = uris[0];
    const singleWorkspace = vscode.workspace.getWorkspaceFolder(singleUri) || workspaceFolder;
    return {
      workspaceFolder: singleWorkspace,
      pubspecUri: singleUri,
      projectPath: path.dirname(singleUri.fsPath)
    };
  }

  // Multiple pubspec files found
  if (promptIfMultiple) {
    const items = uris.map(u => ({
      label: vscode.workspace.asRelativePath(u),
      description: 'pubspec.yaml',
      uri: u
    }));
    const selection = await vscode.window.showQuickPick(items, {
      placeHolder: 'Select a pubspec.yaml project to target'
    });
    if (selection) {
      if (extensionContext) {
        await extensionContext.workspaceState.update('selectedPubspecUri', selection.uri.toString());
      }
      const selectedWorkspace = vscode.workspace.getWorkspaceFolder(selection.uri) || workspaceFolder;
      return {
        workspaceFolder: selectedWorkspace,
        pubspecUri: selection.uri,
        projectPath: path.dirname(selection.uri.fsPath)
      };
    }
    return undefined;
  }

  // If we shouldn't prompt, check if the root has a pubspec.yaml
  const rootPubspec = vscode.Uri.joinPath(workspaceFolder.uri, 'pubspec.yaml');
  try {
    await vscode.workspace.fs.stat(rootPubspec);
    return {
      workspaceFolder,
      pubspecUri: rootPubspec,
      projectPath: path.dirname(rootPubspec.fsPath)
    };
  } catch {
    // Otherwise fallback to the first found
    const firstUri = uris[0];
    const firstWorkspace = vscode.workspace.getWorkspaceFolder(firstUri) || workspaceFolder;
    return {
      workspaceFolder: firstWorkspace,
      pubspecUri: firstUri,
      projectPath: path.dirname(firstUri.fsPath)
    };
  }
}

