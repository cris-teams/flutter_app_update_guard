import 'package:flutter_app_update_guard/src/cli/command_runner.dart';

/// Test mock implementation of [CommandRunner] allowing pre-configured execution handlers.
class FakeCommandRunner implements CommandRunner {
  final Future<CommandResult> Function(
    String executable,
    List<String> arguments,
    String workingDirectory,
  ) _handler;

  FakeCommandRunner(this._handler);

  /// Helper factory to return a constant result for all commands.
  factory FakeCommandRunner.withResult(CommandResult result) {
    return FakeCommandRunner((exec, args, workingDir) async => result);
  }

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Duration? timeout,
  }) {
    return _handler(executable, arguments, workingDirectory);
  }
}
