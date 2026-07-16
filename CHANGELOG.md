# Changelog

## 1.2.0

- **VS Code Extension MVP**: Adds a TypeScript VS Code extension under `extensions/vscode` with diagnostics for risky or policy-violating dependencies in `pubspec.yaml`.
- **Editor Actions**: Adds CodeLens actions for `Simulate Upgrade` and `Inspect Package`, plus commands for check, fix, baseline creation, package inspection, and upgrade simulation.
- **Dependency Sidebar**: Adds a Flutter Update Guard sidebar tree view showing dependency risk levels, scores, versions, and risk reasons.
- **Extension CLI Integration**: Runs the existing CLI through a configured executable, project-local `dart run flutter_app_update_guard`, or global `flutter_app_update_guard`.
- **Extension Documentation**: Documents the two-part editor workflow: running/installing the VS Code extension and adding the CLI as a project `dev_dependency`.

## 1.1.0

- **Fix Command (`fix`)**: Adds a new command to automatically update safe dependency constraints in `pubspec.yaml` and executes `pub get`. Supports `--dry-run` previews, `--exact` pinning, and monorepo `--workspace` modes.
- **Doctor Command (`doctor`)**: Adds diagnostic verification of Dart/Flutter SDK environment, DNS resolution for pub.dev, and YAML configuration validation.
- **Library API Programmatic Export**: Exports `FixCommandExecutor` from the public package entry point.
- **CI Policy Violation Instructions**: Adds detailed guidelines in README for resolving policy violations blocking CI builds.
- **Workflow Robustness**: Configures GITHUB_STEP_SUMMARY generation to use `continue-on-error` on CI.

## 1.0.0

* Initial release of `flutter_app_update_guard`.
* **Dependency Risk Analysis**: Scans direct/dev dependencies, checks pub.dev, and scores upgrade risk (0-100).
- **Inspect Command**: Provides detailed safety metrics, compatibility reports, URLs, release age, and references for a single package.
- **Source Usage Scanner**: Scans project `lib/`, `bin/`, `test/`, `integration_test/`, and `example/` directories for imports/exports to determine usage impact.
- **CI Enforcement**: Introduces the `ci` command to validate configured policies (allow_prerelease, allow_major_updates, fail_on_discontinued, fail_on_sdk_incompatible) and exits on violation.
- **Baseline Support**: Creates and compares baselines (`flutter_app_update_guard.baseline.json`) to bypass historic technical debt while catching regressions.
- **Upgrade Simulations**: Isolates package updates inside a temporary sandbox, updating pubspecs and running validation commands (`pub get`, `analyze`, `test`).
- **Workspace Support**: Recursively scans monorepos/workspaces and identifies constraint mismatches across projects.
- **Reports**: Standard Console, JSON, and PR-friendly Markdown formats.
