import '../cli/command_runner.dart';

/// Evaluation outcome of a dependency update simulation.
class SimulationResult {
  final String packageName;
  final String currentVersion;
  final String targetVersion;
  final CommandResult pubGetResult;
  final CommandResult? analyzeResult;
  final CommandResult? testResult;
  final bool success;
  final bool tempDirectoryKept;
  final String? tempDirectory;

  const SimulationResult({
    required this.packageName,
    required this.currentVersion,
    required this.targetVersion,
    required this.pubGetResult,
    required this.analyzeResult,
    required this.testResult,
    required this.success,
    required this.tempDirectoryKept,
    this.tempDirectory,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'currentVersion': currentVersion,
        'targetVersion': targetVersion,
        'pubGet': pubGetResult.toJson(),
        'analyze': analyzeResult?.toJson(),
        'test': testResult?.toJson(),
        'success': success,
        'tempDirectoryKept': tempDirectoryKept,
        'tempDirectory': tempDirectory,
      };
}
