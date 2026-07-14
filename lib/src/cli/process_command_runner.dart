import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'command_runner.dart';

/// Concrete implementation of [CommandRunner] executing system processes.
class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    Process? process;
    bool timedOut = false;

    try {
      process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final StreamSubscription<String> stdoutSub = process.stdout
          .transform(utf8.decoder)
          .listen((data) => stdoutBuffer.write(data));

      final StreamSubscription<String> stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen((data) => stderrBuffer.write(data));

      Future<int> exitCodeFuture = process.exitCode;
      if (timeout != null) {
        exitCodeFuture = exitCodeFuture.timeout(timeout, onTimeout: () {
          timedOut = true;
          process?.kill(ProcessSignal.sigkill);
          return -1;
        });
      }

      final exitCode = await exitCodeFuture;
      stopwatch.stop();

      await stdoutSub.cancel();
      await stderrSub.cancel();

      return CommandResult(
        executable: executable,
        arguments: arguments,
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: stopwatch.elapsed,
        timedOut: timedOut,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult(
        executable: executable,
        arguments: arguments,
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
        timedOut: timedOut,
      );
    }
  }
}
