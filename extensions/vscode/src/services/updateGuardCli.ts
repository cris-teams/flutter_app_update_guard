import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { CheckReport } from '../domain/updateGuard';

export interface CliExecution {
  command: string;
  args: string[];
}

export interface CliResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
}

export class UpdateGuardCli {
  constructor(private readonly output: vscode.OutputChannel) {}

  async check(workingDir: string): Promise<CheckReport> {
    const result = await this.run(
      ['check', '--format', 'json', '--working-dir', workingDir],
      workingDir,
      { toleratePolicyExit: true }
    );
    const json = extractJsonObject(result.stdout);
    return JSON.parse(json) as CheckReport;
  }

  async inspect(workingDir: string, packageName: string): Promise<string> {
    const result = await this.run(
      ['inspect', packageName, '--format', 'markdown', '--working-dir', workingDir],
      workingDir
    );
    return result.stdout.trim();
  }

  async simulate(workingDir: string, packageName: string): Promise<string> {
    const result = await this.run(
      ['simulate', packageName, '--format', 'markdown', '--working-dir', workingDir],
      workingDir,
      { tolerateFailureExit: true }
    );
    return [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join('\n\n');
  }

  async fix(workingDir: string, dryRun: boolean): Promise<string> {
    const args = ['fix', '--working-dir', workingDir];
    if (dryRun) {
      args.push('--dry-run');
    }

    const result = await this.run(args, workingDir);
    return [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join('\n\n');
  }

  async baseline(workingDir: string): Promise<string> {
    const result = await this.run(
      ['baseline', 'create', '--working-dir', workingDir],
      workingDir
    );
    return [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join('\n\n');
  }

  async run(
    cliArgs: string[],
    workingDir: string,
    options: { toleratePolicyExit?: boolean; tolerateFailureExit?: boolean } = {}
  ): Promise<CliResult> {
    const execution = this.resolveExecution(workingDir, cliArgs);
    this.output.appendLine(`$ ${execution.command} ${execution.args.join(' ')}`);

    const result = await spawn(execution.command, execution.args, workingDir);
    if (
      result.exitCode !== 0 &&
      !(options.toleratePolicyExit && result.exitCode === 1) &&
      !(options.tolerateFailureExit && result.exitCode !== null)
    ) {
      const message = result.stderr || result.stdout || `Exit code ${result.exitCode}`;
      throw new Error(message.trim());
    }

    return result;
  }

  private resolveExecution(workingDir: string, cliArgs: string[]): CliExecution {
    const configuredPath = vscode.workspace
      .getConfiguration('flutter_app_update_guard')
      .get<string>('cliPath', '')
      .trim();

    if (configuredPath.length > 0) {
      return { command: configuredPath, args: cliArgs };
    }

    if (hasLocalDependency(workingDir)) {
      return {
        command: 'dart',
        args: ['run', 'flutter_app_update_guard', ...cliArgs]
      };
    }

    return { command: 'flutter_app_update_guard', args: cliArgs };
  }
}

function hasLocalDependency(workingDir: string): boolean {
  const pubspecPath = path.join(workingDir, 'pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) {
    return false;
  }

  const pubspec = fs.readFileSync(pubspecPath, 'utf8');
  if (
    /^name:\s*flutter_app_update_guard\s*$/m.test(pubspec) ||
    /^\s{2}flutter_app_update_guard\s*:/m.test(pubspec)
  ) {
    return true;
  }

  const packageConfigPath = path.join(workingDir, '.dart_tool', 'package_config.json');
  if (!fs.existsSync(packageConfigPath)) {
    return false;
  }

  try {
    const packageConfig = JSON.parse(fs.readFileSync(packageConfigPath, 'utf8')) as {
      packages?: Array<{ name?: string }>;
    };
    return packageConfig.packages?.some((pkg) => pkg.name === 'flutter_app_update_guard') ?? false;
  } catch {
    return false;
  }
}

function spawn(command: string, args: string[], cwd: string): Promise<CliResult> {
  return new Promise((resolve, reject) => {
    const child = cp.spawn(command, args, {
      cwd,
      shell: process.platform === 'win32'
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk: Buffer) => {
      stderr += chunk.toString();
    });
    child.on('error', reject);
    child.on('close', (exitCode) => {
      resolve({ stdout, stderr, exitCode });
    });
  });
}

function extractJsonObject(stdout: string): string {
  const start = stdout.indexOf('{');
  const end = stdout.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('flutter_app_update_guard did not return JSON output.');
  }

  return stdout.slice(start, end + 1);
}
