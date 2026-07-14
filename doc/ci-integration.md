# CI Integration Guide

Integrate `flutter_app_update_guard` into CI servers to prevent introducing high-risk upgrades.

## CI Command

```bash
flutter_app_update_guard ci --format console
```

### Exit Codes
- `0`: Success (no policy violations).
- `1`: Policy violation detected.
- `2`: Invalid configuration file.
- `3`: Dependency resolution / file error.
- `4`: Missing `pubspec.yaml` file.
- `5`: Pub API connection failure.

---

## Baseline Support
To prevent blocking legacy technical debt:

1. Create a baseline snapshot:
   ```bash
   flutter_app_update_guard baseline create
   ```
   This generates `flutter_app_update_guard.baseline.json`.

2. Run CI check against the baseline:
   ```bash
   flutter_app_update_guard ci --baseline flutter_app_update_guard.baseline.json
   ```

CI will only fail on:
- Escalations in existing packages (e.g. risk level increased from low to critical).
- Packages becoming newly discontinued or SDK incompatible.
- New packages introducing policy violations.
