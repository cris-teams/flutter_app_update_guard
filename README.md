# flutter_app_update_guard

`flutter_app_update_guard` is a dependency safety CLI for Dart and Flutter. It scans project dependencies, computes safety risks (0-100), isolates updates inside temporary simulation sandboxes, checks compliance against CI policies, and exposes baseline mechanisms to manage update tech debt.

---

## Key Features

- **Dependency Risk Analysis:** Categorizes package updates (none, patch, minor, major, prerelease) and evaluates risk scores based on maintenance, age, and discontinued status.
- **Source Usage Scanner:** Recursively searches for package imports and exports to identify critical, widely-used packages (+5, +10, +15 risk modifiers).
- **CI Enforcement & Policies:** Configures exit-on-violation rules for major upgrades, prerelease dependencies, and discontinued status.
- **Baseline Controls:** Saves snapshot files (`flutter_app_update_guard.baseline.json`) to bypass historical technical debt and catch only new policy violations.
- **Isolated Simulations:** Copies code into sandboxes, safely rewrites pubspecs, runs `pub get`, `analyze`, and `test` to test actual compilation and regression impacts before committing.
- **Monorepo & Workspace Support:** Recursively discover nested packages and checks package version constraint mismatches.

---

## Installation & CLI Activation

### Add to Dev Dependencies
To use the tool locally in your Dart or Flutter project, add it to your `dev_dependencies`:
```yaml
dev_dependencies:
  flutter_app_update_guard: ^1.0.0
```
Or run:
```bash
dart pub add dev:flutter_app_update_guard
```

### Local Run
Run the CLI within your project directory:
```bash
dart run flutter_app_update_guard check
```

### Global Activation
Alternatively, activate the CLI globally on your machine:
```bash
dart pub global activate flutter_app_update_guard
flutter_app_update_guard check
```

---

## How to Use (Step-by-Step Guide)

### Step 1: Scan Your Project Dependencies
Run the `check` command to check for outdated dependencies, compute risk scores, and view risk reasons in a colored console table:
```bash
flutter_app_update_guard check
```

You can export the results to markdown format for a PR description or JSON format for downstream automation:
```bash
flutter_app_update_guard check --format markdown --output dependency_report.md
flutter_app_update_guard check --format json --output dependency_report.json
```

### Step 2: Inspect a Specific Package
To understand why a package has a high risk score, or to see which source files in your project import or export it:
```bash
# General package safety/maintenance lookup
flutter_app_update_guard inspect dio

# Show all Dart files referencing this package
flutter_app_update_guard inspect dio --show-files
```

### Step 3: Run Upgrade Simulations
Before upgrading a dependency in your project, simulate the upgrade in an isolated sandbox to ensure it does not break compilation or fail tests:
```bash
# Simulates updating provider to its latest version and running static analysis
flutter_app_update_guard simulate provider

# Simulates updating dio to a specific version (6.0.0) and running tests
flutter_app_update_guard simulate dio --version 6.0.0 --run-tests
```

### Step 4: Create a Tech-Debt Baseline
If you are integrating the tool into a mature project with many existing warnings, create a baseline snapshot to record the current state. This allows you to ignore existing technical debt and prevent new violations from entering the codebase:
```bash
flutter_app_update_guard baseline create
```
This command generates a `flutter_app_update_guard.baseline.json` file in the root of your project.

### Step 5: Enforce Policies in CI
In your GitHub Actions workflow or GitLab CI pipeline, execute the `ci` command. If any new dependency violates your policies, the pipeline will fail:
```bash
# Check policies and fail if violations exist (excluding baseline packages)
flutter_app_update_guard ci --baseline flutter_app_update_guard.baseline.json
```

---

## Commands and Invocations

### `check`
Scans dependencies in the project.
```bash
flutter_app_update_guard check [options]
```
- `--format`: Format of report (`console`, `json`, `markdown`).
- `--output`: Filepath to write the report to.
- `--workspace`: Discover and scan nested project workspaces.

### `inspect`
Displays safety, compatibility, and usage metrics for a single package.
```bash
flutter_app_update_guard inspect <packageName> [options]
```
- `--show-files`: Print the files referencing this package.
- `--format`: Output format (`console`, `json`, `markdown`).

### `ci`
Evaluates configured update policies against reports, failing with exit code `1` on violation.
```bash
flutter_app_update_guard ci [options]
```
- `--baseline`: Path to the baseline snapshot file.
- `--workspace`: Run CI checks for all workspace packages.

### `baseline`
Creates a baseline snapshot containing current dependencies and risk profiles.
```bash
flutter_app_update_guard baseline create
```

### `simulate`
Sandbox-upgrades dependency constraints to test compilation and regressions.
```bash
flutter_app_update_guard simulate <packageName> [options]
```
- `--version`: Explicit target upgrade version.
- `--run-tests`: Runs `dart test` or `flutter test` during simulation.
- `--keep-temp`: Keeps the sandbox temp folder on execution failure.
- `--timeout`: Max timeout in seconds (defaults to `300`).

### `doctor`
Diagnoses the local development environment and configuration validity.
```bash
flutter_app_update_guard doctor
```

---

## Configuration Reference (`flutter_app_update_guard.yaml`)

Create this file in the root of your project:

```yaml
risk:
  fail_on:
    - critical

checks:
  outdated: true
  discontinued: true
  sdk_compatibility: true
  source_usage: true
  maintenance: true
  changelog: true
  analyze: true
  tests: false

maintenance:
  stale_after_days: 730

source_usage:
  enabled: true
  include_exports: true
  ignore_generated: true
  exclude:
    - lib/generated/**

simulation:
  run_analyze: true
  run_tests: false
  timeout_seconds: 300
  keep_temp_on_failure: false

policies:
  allow_prerelease: false
  allow_major_updates: false
  fail_on_discontinued: true
  fail_on_sdk_incompatible: true
  max_critical_dependencies: 0
  max_high_risk_dependencies: 3
  max_medium_risk_dependencies: 10

workspace:
  enabled: false
  max_depth: 5
  exclude:
    - examples/legacy/**

ignore:
  packages:
    - build_runner
```

## Understanding Risk Levels & Impact

The tool maps the calculated risk score (0-100) to one of five risk levels, representing the estimated effort and caution needed when upgrading:

| Risk Level | Score Range | Code Impact / Effort | Description / Common Triggers |
| :--- | :---: | :--- | :--- |
| **Safe** | `0` | No code changes required. | Dependency is already up-to-date or only has a patch release (bug fixes). |
| **Low** | `1 - 39` | Minimal to no code changes. | Minor version upgrade with backward-compatible features; low frequency of imports. |
| **Medium** | `40 - 69` | Moderate refactoring needed. | Major version upgrade (API breakages) but the library is only imported in a few files. |
| **High** | `70 - 89` | Significant refactoring required. | Major version upgrade of a core library referenced in many production source files. |
| **Critical** | `90 - 100` | High-risk, immediate action needed. | Package is **discontinued** (unmaintained/deprecated) or **incompatible** with current SDK limits. |

---

## Exit Codes

- `0` = Success (no policy violations)
- `1` = Policy violation detected
- `2` = Invalid configuration format
- `3` = Dependency parse / read error
- `4` = Missing `pubspec.yaml`
- `5` = Network / API connection error
- `6` = Sandbox compile or test failed during simulation
- `7` = Simulation process timeout
- `8` = Workspace monorepo scan failure
- `10` = Unexpected internal error

---

## Security & Design Considerations

- **Local Execution Security:** We do not execute commands via unescaped shell strings, reducing risk of shell injection attacks.
- **Privacy Policy:** No source code or environment variable credentials are sent to remote servers; all scans are kept strictly local.
- **Copy Restrictions:** Upgrade simulation does not copy `.git`, `build`, or `.dart_tool` folders, preventing leaks and massive disk space wastage.
- **Safe Yaml Rewrites:** Constraints updates are made on exact source spans of keys, preserving formatting and comments of the remaining file parts.

---

## Example Demo Output

When running the CLI check on the outdated `example` folder (`dart run flutter_app_update_guard check example`), the CLI produces the following risk report and fails with exit code `1` due to the prohibited major version update policy:

```text
Flutter App Update Guard

Package                   Current       Latest        Update      Risk        
dio                       4.0.6         5.10.0        major       medium      
path                      1.9.1         1.9.1         none        safe        
flutter_app_update_guard  1.0.0         -             skipped     skipped     

Summary
  Safe:      1
  Low:       0
  Medium:    1
  High:      0
  Critical:  0
  Skipped:   1

Risk Breakdown & Explanations
dio (medium risk, score: 45)
  - Major version upgrade (potential breaking changes) (+30)
  - Current constraint "^4.0.0" does not allow the latest version (5.10.0) (+15)

Policy Violations
  [!] Package 'dio' has prohibited major version update

Warnings
  [*] Package 'dio' has warned risk level 'medium' (score: 45)
```
