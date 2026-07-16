# Flutter App Update Guard VS Code Extension

This extension surfaces `flutter_app_update_guard` dependency risk checks inside VS Code.

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
