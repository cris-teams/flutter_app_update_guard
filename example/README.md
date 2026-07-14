# flutter_app_update_guard Examples

This folder acts as a simulated project with an outdated `dio` dependency to test the CLI tool.

---

## 1. Outdated Project Structure

The files inside the `example/` folder represent an outdated app:
- **[pubspec.yaml](file:///Users/trung.ngo/code/flutter_app_update_guard/example/pubspec.yaml)**: Uses `dio: ^3.0.0` and `path: ^1.7.0`.
- **[pubspec.lock](file:///Users/trung.ngo/code/flutter_app_update_guard/example/pubspec.lock)**: Resolves/locks `dio` to version `3.0.10` (released in 2020) and `path` to `1.7.0`.
- **[lib/main.dart](file:///Users/trung.ngo/code/flutter_app_update_guard/example/lib/main.dart)**: Standard production file importing `package:dio/dio.dart`.

---

## 2. Running CLI Commands on the Example Folder

From the root of this package, you can run the following commands to check security risks and examine package metadata on the example files:

### A. Run Dependency Scan
Scan all dependencies declared in the `example/` directory and print the risk report:
```bash
dart run flutter_app_update_guard check example
```

### B. Inspect `dio` Dependency
Examine detailed package safety metrics, compatibility, URLs, release age, and references for the `dio` dependency in the `example/` folder:
```bash
dart run flutter_app_update_guard inspect dio --working-dir example --show-files
```

### C. Simulate upgrading `dio`
Test compiling the `example/` project inside a temp sandbox after changing its constraints:
```bash
dart run flutter_app_update_guard simulate dio --working-dir example
```

---

## 3. Programmatic Usage

To execute the programmatic API sample querying the pub.dev endpoints:

```bash
dart run example/example.dart
```
This script runs the safety scanner programmatically on the host package.
