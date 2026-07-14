/// Centrally managed exit codes for flutter_app_update_guard.
abstract final class ExitCodes {
  /// Success, no policy violations
  static const int success = 0;

  /// Success running checks, but policy violation was detected (e.g. discontinued package or too many critical risk packages)
  static const int policyViolation = 1;

  /// Invalid configuration file structure or values
  static const int invalidConfig = 2;

  /// Dependency parsing/reading error (e.g. corrupted pubspec.lock or pubspec.yaml)
  static const int dependencyReadError = 3;

  /// Missing pubspec.yaml file
  static const int pubspecNotFound = 4;

  /// Network or Pub.dev API errors
  static const int apiError = 5;

  /// Analyze or test failed in simulation
  static const int simulationFailed = 6;

  /// Command execution timeout
  static const int timeout = 7;

  /// Workspace discovery or analysis error
  static const int workspaceError = 8;

  /// Unexpected internal engine exception
  static const int internalError = 10;
}
