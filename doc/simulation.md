# Upgrade Simulation

Upgrade simulation isolates package upgrades inside a temporary sandboxed workspace to test real compatibility.

## Execution

```bash
flutter_app_update_guard simulate dio
```

### Flow
1. Generates a safe sandboxed copy of the target package.
2. Modifies `pubspec.yaml` version constraints safely (preserves yaml formatting).
3. Executes `pub get`.
4. Executes `analyze`.
5. Optionally executes `test` (`--run-tests` flag).
6. Cleans up temp workspaces. If validation fails, `--keep-temp` retains the sandbox.

---

## Direct vs. Transitive (Nested) Dependencies

- **Static Checks (`check` / `inspect`):** To avoid cluttering reports with hundreds of nested libraries, the static checks only inspect **direct dependencies** defined in `pubspec.yaml`.
- **Sandbox Simulation (`simulate`):** Validates the entire tree of **transitive (nested) dependencies** dynamically:
  - When executing `pub get` in the sandbox, the native package manager resolves the full dependency graph. Any dependency conflicts will fail this step.
  - Running `analyze` and `test` ensures that even if a nested dependency has breaking changes, the tool will catch compilation or runtime failures and mark the upgrade as unsafe.
