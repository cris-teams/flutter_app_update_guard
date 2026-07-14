/// Command result model and runner interface for process execution.
library command_runner;

/// Result of a process execution.
class CommandResult {
  final String executable;
  final List<String> arguments;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool timedOut;

  const CommandResult({
    required this.executable,
    required this.arguments,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    required this.timedOut,
  });

  Map<String, dynamic> toJson() => {
        'executable': executable,
        'arguments': arguments,
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'durationMs': duration.inMilliseconds,
        'timedOut': timedOut,
      };
}

/// Interface for executing commands securely and without shell injection risk.
abstract interface class CommandRunner {
  /// Executes the given [executable] with [arguments] in [workingDirectory].
  /// Supports optional [timeout].
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Duration? timeout,
  });
}
