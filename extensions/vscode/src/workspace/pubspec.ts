import * as vscode from 'vscode';
import { PubspecDependencyLine } from '../domain/updateGuard';

const dependencySections = new Set([
  'dependencies',
  'dev_dependencies',
  'dependency_overrides'
]);

export function isPubspecDocument(document: vscode.TextDocument): boolean {
  return document.uri.scheme === 'file' && document.fileName.endsWith('pubspec.yaml');
}

export function findDependencyLines(document: vscode.TextDocument): Map<string, PubspecDependencyLine> {
  const dependencies = new Map<string, PubspecDependencyLine>();
  let currentSection: string | undefined;

  for (let index = 0; index < document.lineCount; index++) {
    const line = document.lineAt(index);
    const text = line.text;

    if (/^\S[^:#]*:\s*$/.test(text)) {
      const section = text.slice(0, text.indexOf(':')).trim();
      currentSection = dependencySections.has(section) ? section : undefined;
      continue;
    }

    if (!currentSection || line.isEmptyOrWhitespace) {
      continue;
    }

    const match = /^(\s{2,})([A-Za-z0-9_]+)\s*:/.exec(text);
    if (!match) {
      continue;
    }

    const name = match[2];
    const startCharacter = match[1].length;
    const endCharacter = startCharacter + name.length;
    dependencies.set(name, {
      name,
      section: currentSection,
      line: index,
      startCharacter,
      endCharacter
    });
  }

  return dependencies;
}

export function findDependencyAtPosition(
  document: vscode.TextDocument,
  position: vscode.Position
): PubspecDependencyLine | undefined {
  for (const dependency of findDependencyLines(document).values()) {
    if (dependency.line !== position.line) {
      continue;
    }

    if (
      position.character >= dependency.startCharacter &&
      position.character <= dependency.endCharacter
    ) {
      return dependency;
    }
  }

  return undefined;
}
