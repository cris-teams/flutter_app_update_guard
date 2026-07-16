# Flutter App Update Guard VS Code Extension

This extension surfaces `flutter_app_update_guard` dependency risk checks inside VS Code.

## Usage

The VS Code extension provides the editor UI, but it still needs the `flutter_app_update_guard` CLI to run dependency checks.

Recommended project-local setup:

```sh
dart pub add dev:flutter_app_update_guard
dart pub get
```

Then open VS Code at the Dart or Flutter project root that contains `pubspec.yaml` and run **Flutter Update Guard: Check Dependencies** from the Command Palette.

After installing the extension from VSIX or the Marketplace, reload VS Code and make sure the opened folder is the project root where `pubspec.yaml` lives.

You can also use a global CLI installation:

```sh
dart pub global activate flutter_app_update_guard
```

Make sure the pub global bin directory is available in your shell `PATH`:

```sh
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

For zsh on macOS, add that line to `~/.zshrc`, then restart VS Code.

## Troubleshooting

If you see this error:

```text
Dependency check failed: spawn flutter_app_update_guard ENOENT
```

the extension is installed and running, but it cannot find the CLI executable. Fix it by either adding `flutter_app_update_guard` to your project's `dev_dependencies` or installing the CLI globally and ensuring `$HOME/.pub-cache/bin` is in `PATH`.

You can verify the CLI from the project root with:

```sh
dart run flutter_app_update_guard check
```

or, for a global install:

```sh
flutter_app_update_guard check
```

## Source Layout

- `src/extension.ts`: VS Code lifecycle entrypoint only.
- `src/app/`: activation wiring, subscriptions, and document event orchestration.
- `src/commands/`: command handlers registered by the extension.
- `src/services/`: CLI execution, project context resolution, and shared command helpers.
- `src/features/`: VS Code UI providers grouped by feature area.
- `src/workspace/`: workspace and `pubspec.yaml` parsing helpers.
- `src/domain/`: TypeScript models for CLI reports.

## Development

```sh
npm install
npm run compile
```

Open this `extensions/vscode` folder in VS Code and press `F5` to run the Extension Development Host.
