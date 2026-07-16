import * as vscode from 'vscode';
import { runBaselineCommand } from '../commands/baselineCommand';
import { runCheckCommand } from '../commands/checkCommand';
import { runFixCommand } from '../commands/fixCommand';
import { runPackageCommand } from '../commands/packageCommand';
import { PubspecCodeLensProvider } from '../features/codelens/pubspecCodeLensProvider';
import { DependencyTreeProvider } from '../features/tree/dependencyTreeProvider';
import { UpdateGuardCli } from '../services/updateGuardCli';
import { isPubspecDocument } from '../workspace/pubspec';

export class ExtensionController {
  private debounceTimer: NodeJS.Timeout | undefined;
  private readonly output = vscode.window.createOutputChannel('Flutter Update Guard');
  private readonly cli = new UpdateGuardCli(this.output);
  private readonly diagnostics = vscode.languages.createDiagnosticCollection('flutter_app_update_guard');
  private readonly treeProvider = new DependencyTreeProvider();
  private readonly codeLensProvider = new PubspecCodeLensProvider();

  constructor(private readonly context: vscode.ExtensionContext) {}

  activate(): void {
    this.context.subscriptions.push(
      this.output,
      this.diagnostics,
      vscode.window.registerTreeDataProvider('flutterAppUpdateGuard.dependencies', this.treeProvider),
      vscode.languages.registerCodeLensProvider(
        { language: 'yaml', scheme: 'file' },
        this.codeLensProvider
      ),
      vscode.commands.registerCommand('flutter_app_update_guard.check', async (uri?: vscode.Uri) => {
        await this.runCheck(uri);
      }),
      vscode.commands.registerCommand('flutter_app_update_guard.refresh', async () => {
        await this.runCheck();
      }),
      vscode.commands.registerCommand('flutter_app_update_guard.fix', async () => {
        await runFixCommand(this.cli, this.output);
      }),
      vscode.commands.registerCommand('flutter_app_update_guard.baseline', async () => {
        await runBaselineCommand(this.cli, this.output);
      }),
      vscode.commands.registerCommand(
        'flutter_app_update_guard.inspect',
        async (packageName?: string, uri?: vscode.Uri) => {
          await runPackageCommand(this.cli, this.output, 'inspect', packageName, uri);
        }
      ),
      vscode.commands.registerCommand(
        'flutter_app_update_guard.simulate',
        async (packageName?: string, uri?: vscode.Uri) => {
          await runPackageCommand(this.cli, this.output, 'simulate', packageName, uri);
        }
      ),
      vscode.workspace.onDidOpenTextDocument((document) => {
        if (this.shouldCheckOnDocumentEvent('checkOnOpen', document)) {
          this.scheduleCheck(document.uri);
        }
      }),
      vscode.workspace.onDidSaveTextDocument((document) => {
        if (this.shouldCheckOnDocumentEvent('checkOnSave', document)) {
          this.scheduleCheck(document.uri);
        }
      }),
      vscode.workspace.onDidCloseTextDocument((document) => {
        this.diagnostics.delete(document.uri);
      })
    );

    const activeDocument = vscode.window.activeTextEditor?.document;
    if (activeDocument && isPubspecDocument(activeDocument)) {
      this.scheduleCheck(activeDocument.uri);
    }
  }

  dispose(): void {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }
  }

  private scheduleCheck(uri: vscode.Uri): void {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    this.debounceTimer = setTimeout(() => {
      void this.runCheck(uri);
    }, 500);
  }

  private async runCheck(uri?: vscode.Uri): Promise<void> {
    await runCheckCommand({
      cli: this.cli,
      diagnostics: this.diagnostics,
      treeProvider: this.treeProvider,
      codeLensProvider: this.codeLensProvider,
      output: this.output,
      uri
    });
  }

  private shouldCheckOnDocumentEvent(setting: 'checkOnOpen' | 'checkOnSave', document: vscode.TextDocument): boolean {
    const enabled = vscode.workspace
      .getConfiguration('flutter_app_update_guard')
      .get<boolean>(setting, true);
    return enabled && isPubspecDocument(document);
  }
}

