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
