# Changelog

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
