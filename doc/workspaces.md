# Monorepos and Workspace Analysis

Analyze multi-project workspace setups (e.g. Melos monorepos or standard workspace configs).

## Scanning

```bash
flutter_app_update_guard check --workspace
```

## Features
- Discovers sub-projects containing `pubspec.yaml` recursively.
- Exclude test directories or legacy folders using `workspace.exclude` configurations.
- Checks package constraint mismatches (flagging if `dio` resolved to non-equivalent constraint boundaries across apps/packages).
- Provides project-by-project compliance summary.
