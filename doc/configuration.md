# Configuration Guide

The `flutter_app_update_guard.yaml` file configures the update guard runner behavior.

## Example Config

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
    - test/fixtures/**

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
    - flutter_lints
```
