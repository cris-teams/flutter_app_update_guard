# Risk Scoring Reference

This document outlines how `flutter_app_update_guard` evaluates the risk of upgrading package versions.

## Risk Scale & Level Boundaries
The total risk score for any dependency ranges from `0` to `100` (capped).

- **Safe:** `0`
- **Low:** `1` to `20`
- **Medium:** `21` to `50`
- **High:** `51` to `75`
- **Critical:** `76` to `100`

---

## Static Risk Triggers

| Trigger | Default Risk Score Contribution | Code |
|---|---|---|
| **Major Upgrade** | +30 | `MAJOR_UPGRADE` |
| **Minor Upgrade** | +10 | `MINOR_UPGRADE` |
| **Prerelease Target Version** | +10 | `PRERELEASE_TARGET` |
| **Discontinued Package** | +40 | `DISCONTINUED` |
| **Package Stale (Older than limit)** | +15 | `STALE_PACKAGE` |
| **Dart SDK Incompatible** | +40 | `DART_SDK_INCOMPATIBLE` |
| **Flutter SDK Incompatible** | +40 | `FLUTTER_SDK_INCOMPATIBLE` |
| **Constraint Does Not Allow Version** | +15 | `CONSTRAINT_INCOMPATIBLE` |

---

## Source Code Usage Risk Triggers

| File References count | Risk Score Contribution | Code |
|---|---|---|
| **10 to 24 file imports** | +5 | `LOW_SOURCE_USAGE` |
| **25 to 49 file imports** | +10 | `MEDIUM_SOURCE_USAGE` |
| **50 or more file imports** | +15 | `HIGH_SOURCE_USAGE` |

*Note: Source usage rules are mutually exclusive (do not stack).*

---

## Sandbox Simulation Risk Triggers

| Sandbox Result | Risk Score Contribution | Code |
|---|---|---|
| **Dependency Resolution Failure** | +40 | `SIMULATION_RESOLVE_FAIL` |
| **Dart/Flutter Analyze Failure** | +30 | `SIMULATION_ANALYZE_FAIL` |
| **Dart/Flutter Test Failure** | +40 | `SIMULATION_TEST_FAIL` |
| **Command Timeout** | +30 | `SIMULATION_TIMEOUT` |
