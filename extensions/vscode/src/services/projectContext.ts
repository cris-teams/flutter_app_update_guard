import * as path from 'path';
import * as vscode from 'vscode';

export interface ProjectContext {
  workspaceFolder: vscode.WorkspaceFolder;
  pubspecUri: vscode.Uri;
}

export async function resolveProjectContext(uri?: vscode.Uri): Promise<ProjectContext | undefined> {
  const candidateUri = uri ?? vscode.window.activeTextEditor?.document.uri;
  const workspaceFolder = candidateUri
    ? vscode.workspace.getWorkspaceFolder(candidateUri)
    : vscode.workspace.workspaceFolders?.[0];

  if (!workspaceFolder) {
    return undefined;
  }

  if (candidateUri && path.basename(candidateUri.fsPath) === 'pubspec.yaml') {
    return { workspaceFolder, pubspecUri: candidateUri };
  }

  const pubspecUri = vscode.Uri.joinPath(workspaceFolder.uri, 'pubspec.yaml');
  try {
    await vscode.workspace.fs.stat(pubspecUri);
    return { workspaceFolder, pubspecUri };
  } catch {
    return undefined;
  }
}

