import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import '../analyzers/workspace_analyzer.dart';
import '../commands/check_command.dart';
import '../commands/ci_command.dart';
import '../commands/inspect_command.dart';
import '../commands/simulate_command.dart';
import '../commands/doctor_command.dart';
import '../commands/fix_command.dart';
import '../config/baseline_manager.dart';
import '../config/config_loader.dart';
import '../config/guard_config.dart';
import '../exceptions/guard_exception.dart';
import '../models/policy_violation.dart';
import '../models/project_report.dart';
import '../models/risk_models.dart';
import '../models/simulation_result.dart';
import '../models/workspace_models.dart';
import '../pub/pub_api_client.dart';
import '../pub/pub_cache.dart';
import '../pub/pub_client.dart';
import '../reporters/console_reporter.dart';
import '../reporters/json_reporter.dart';
import '../reporters/markdown_reporter.dart';
import 'command_runner.dart';
import 'exit_codes.dart';
import 'process_command_runner.dart';

/// Runner responsible for command parsing, setup, and exception boundaries.
class AppRunner {
  final List<String> args;
  final PubClient? pubClient;
  final CommandRunner? commandRunner;

  AppRunner(this.args, {this.pubClient, this.commandRunner});

  /// Executes the CLI application. Returns the exit code.
  Future<int> run() async {
    final parser = ArgParser();
    bool verbose = false;

    // Common options for output and format
    void addCommonFormatOptions(ArgParser p) {
      p.addOption(
        'format',
        allowed: ['console', 'json', 'markdown'],
        defaultsTo: 'console',
        help: 'Output formatting structure.',
      );
      p.addOption(
        'output',
        abbr: 'o',
        help: 'File path to write report results into.',
      );
      p.addFlag(
        'verbose',
        abbr: 'v',
        defaultsTo: false,
        help: 'Print raw failure details and trace output.',
      );
      p.addFlag(
        'quiet',
        abbr: 'q',
        defaultsTo: false,
        help: 'Silence all stdout logging.',
      );
      p.addOption(
        'config',
        defaultsTo: 'flutter_app_update_guard.yaml',
        help: 'Target configuration filepath.',
      );
      p.addOption(
        'working-dir',
        help: 'Target project directory to analyze.',
      );
    }

    // 1. check command
    final checkParser = ArgParser()
      ..addFlag('color', defaultsTo: true, help: 'Enable terminal color output.')
      ..addFlag('workspace', defaultsTo: false, help: 'Scan workspace/monorepo projects.');
    addCommonFormatOptions(checkParser);
    parser.addCommand('check', checkParser);

    // 2. inspect command
    final inspectParser = ArgParser()
      ..addFlag('show-files', defaultsTo: false, help: 'Display list of files referencing the package.');
    addCommonFormatOptions(inspectParser);
    parser.addCommand('inspect', inspectParser);

    // 3. report command
    final reportParser = ArgParser()
      ..addFlag('workspace', defaultsTo: false, help: 'Generate report for workspace projects.');
    addCommonFormatOptions(reportParser);
    parser.addCommand('report', reportParser);

    // 4. ci command
    final ciParser = ArgParser()
      ..addOption('baseline', help: 'Baseline file path to filter existing issues.')
      ..addFlag('workspace', defaultsTo: false, help: 'Run CI checks for workspace projects.');
    addCommonFormatOptions(ciParser);
    parser.addCommand('ci', ciParser);

    // 5. baseline command
    final baselineParser = ArgParser();
    final createParser = ArgParser();
    baselineParser.addCommand('create', createParser);
    addCommonFormatOptions(baselineParser);
    parser.addCommand('baseline', baselineParser);

    // 6. simulate command
    final simulateParser = ArgParser()
      ..addOption('version', help: 'Target upgrade simulation version.')
      ..addFlag('run-tests', defaultsTo: false, help: 'Run tests in addition to analyze check.')
      ..addFlag('keep-temp', defaultsTo: false, help: 'Retain sandbox temp folder after execution.')
      ..addOption('timeout', defaultsTo: '300', help: 'Timeout in seconds for simulation commands.');
    addCommonFormatOptions(simulateParser);
    parser.addCommand('simulate', simulateParser);

    // 7. doctor command
    final doctorParser = ArgParser();
    addCommonFormatOptions(doctorParser);
    parser.addCommand('doctor', doctorParser);

    // 8. fix command
    final fixParser = ArgParser()
      ..addFlag('dry-run', defaultsTo: false, help: 'Preview updates without applying them.')
      ..addFlag('workspace', defaultsTo: false, help: 'Scan workspace/monorepo projects.')
      ..addFlag('exact', defaultsTo: false, help: 'Pin version constraints to exact versions instead of using carets (^).');
    addCommonFormatOptions(fixParser);
    parser.addCommand('fix', fixParser);

    // Global flags
    parser
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage instructions.')
      ..addFlag('verbose', abbr: 'v', defaultsTo: false, help: 'Print raw failure details.')
      ..addFlag('quiet', abbr: 'q', defaultsTo: false, help: 'Silence all stdout logging.');

    try {
      final ArgResults topResults = parser.parse(args);
      verbose = topResults.options.contains('verbose') && topResults['verbose'] == true;

      if (topResults['help'] == true) {
        _printUsage(parser);
        return ExitCodes.success;
      }

      final command = topResults.command;
      if (command == null) {
        stderr.writeln('Error: Missing command.');
        _printUsage(parser);
        return ExitCodes.invalidConfig;
      }

      verbose = (topResults.options.contains('verbose') && topResults['verbose'] == true) ||
          (command.options.contains('verbose') && command['verbose'] == true);

      final quiet = (topResults.options.contains('quiet') && topResults['quiet'] == true) ||
          (command.options.contains('quiet') && command['quiet'] == true);

      final format = command.options.contains('format') ? command['format'] as String : 'console';
      final outputPath = command.options.contains('output') ? command['output'] as String? : null;
      final configPath = command.options.contains('config') ? command['config'] as String : 'flutter_app_update_guard.yaml';
      final workingDir = command.options.contains('working-dir') && command['working-dir'] != null
          ? command['working-dir'] as String
          : ((command.name == 'check' || command.name == 'ci') && command.rest.isNotEmpty
              ? command.rest.first
              : Directory.current.path);

      // Load config & client
      final config = ConfigLoader.load(configPath);
      final client = pubClient ?? CachedPubClient(PubApiClient());
      final runner = commandRunner ?? const ProcessCommandRunner();

      // Branch on command
      if (command.name == 'check' || command.name == 'report') {
        final workspaceMode = command.options.contains('workspace') && command['workspace'] == true;
        final useColor = command.options.contains('color') && command['color'] == true;

        if (workspaceMode) {
          return await _runWorkspaceCheck(
            workingDir: workingDir,
            format: format,
            outputPath: outputPath,
            quiet: quiet,
            config: config,
            client: client,
            verbose: verbose,
          );
        } else {
          final executor = CheckCommandExecutor(pubClient: client);
          final report = await executor.execute(
            workingDir: workingDir,
            config: config,
            verbose: verbose,
          );

          final renderedReport = _renderReport(report, format, useColor);
          if (!quiet) print(renderedReport);
          if (outputPath != null) {
            File(outputPath).writeAsStringSync(renderedReport);
          }

          return report.hasPolicyViolations ? ExitCodes.policyViolation : ExitCodes.success;
        }
      }

      if (command.name == 'inspect') {
        if (command.rest.isEmpty) {
          throw const GuardException(
            'Missing package name for inspect command. Usage: flutter_app_update_guard inspect <package_name>',
            exitCode: ExitCodes.invalidConfig,
          );
        }
        final pkgName = command.rest.first;
        final showFiles = command['show-files'] as bool;
        final inspector = InspectCommandExecutor(pubClient: client);

        return await inspector.execute(
          workingDir: workingDir,
          packageName: pkgName,
          format: format,
          showFiles: showFiles,
          config: config,
        );
      }

      if (command.name == 'ci') {
        final workspaceMode = command.options.contains('workspace') && command['workspace'] == true;
        final baselinePath = command['baseline'] as String?;

        Baseline? baseline;
        if (baselinePath != null) {
          baseline = BaselineManager.load(baselinePath);
        }

        if (workspaceMode) {
          return await _runWorkspaceCi(
            workingDir: workingDir,
            baseline: baseline,
            format: format,
            outputPath: outputPath,
            quiet: quiet,
            config: config,
            client: client,
            verbose: verbose,
          );
        } else {
          final checker = CheckCommandExecutor(pubClient: client);
          final report = await checker.execute(
            workingDir: workingDir,
            config: config,
            verbose: verbose,
          );

          final violations = CiCommandExecutor.evaluate(report, config, baseline);

          final ciOutput = _renderCiViolations(violations, format);
          if (!quiet && ciOutput.isNotEmpty) print(ciOutput);

          if (outputPath != null) {
            File(outputPath).writeAsStringSync(ciOutput);
          }

          return violations.isNotEmpty ? ExitCodes.policyViolation : ExitCodes.success;
        }
      }

      if (command.name == 'baseline') {
        final sub = command.command;
        if (sub == null || sub.name != 'create') {
          throw const GuardException(
            'Invalid baseline subcommand. Only "create" is supported. Usage: flutter_app_update_guard baseline create',
            exitCode: ExitCodes.invalidConfig,
          );
        }

        final checker = CheckCommandExecutor(pubClient: client);
        final report = await checker.execute(
          workingDir: workingDir,
          config: config,
          verbose: verbose,
        );

        const targetBaselinePath = 'flutter_app_update_guard.baseline.json';
        BaselineManager.save(targetBaselinePath, report, '1.0.0');

        if (!quiet) {
          print('Created baseline file at: $targetBaselinePath');
        }
        return ExitCodes.success;
      }

      if (command.name == 'simulate') {
        if (command.rest.isEmpty) {
          throw const GuardException(
            'Missing package name for simulate command. Usage: flutter_app_update_guard simulate <package_name>',
            exitCode: ExitCodes.invalidConfig,
          );
        }
        final pkgName = command.rest.first;
        final simVersion = command['version'] as String?;
        final runTests = command['run-tests'] as bool;
        final keepTemp = command['keep-temp'] as bool;
        final timeoutSec = int.tryParse(command['timeout'] as String) ?? 300;

        final simulator = SimulateCommandExecutor(pubClient: client, commandRunner: runner);
        final simResult = await simulator.simulate(
          workingDir: workingDir,
          packageName: pkgName,
          targetVersion: simVersion,
          config: config,
          runTestsOverride: runTests,
          keepTempOverride: keepTemp,
          timeout: Duration(seconds: timeoutSec),
          verbose: verbose,
        );

        final renderedSim = _renderSimulationResult(simResult, format);
        if (!quiet) print(renderedSim);

        if (outputPath != null) {
          File(outputPath).writeAsStringSync(renderedSim);
        }

        return simResult.success ? ExitCodes.success : ExitCodes.simulationFailed;
      }

      if (command.name == 'doctor') {
        final executor = DoctorCommandExecutor(commandRunner: runner);
        return await executor.execute(
          workingDir: workingDir,
          configPath: configPath,
        );
      }

      if (command.name == 'fix') {
        final dryRun = command['dry-run'] as bool;
        final workspaceMode = command.options.contains('workspace') && command['workspace'] == true;
        final exact = command.options.contains('exact') && command['exact'] == true;
        final executor = FixCommandExecutor(pubClient: client, commandRunner: runner);
        return await executor.execute(
          workingDir: workingDir,
          config: config,
          workspaceMode: workspaceMode,
          dryRun: dryRun,
          exact: exact,
          verbose: verbose,
        );
      }

      return ExitCodes.success;
    } on ArgParserException catch (e) {
      stderr.writeln('Argument parsing error: ${e.message}');
      _printUsage(parser);
      return ExitCodes.invalidConfig;
    } on GuardException catch (e) {
      stderr.writeln('Error: ${e.message}');
      if (verbose && e.details != null) {
        stderr.writeln('Details: ${e.details}');
      }
      return e.exitCode;
    } catch (e, stack) {
      stderr.writeln('Unexpected internal error: $e');
      if (verbose) {
        stderr.writeln(stack);
      }
      return ExitCodes.internalError;
    }
  }

  Future<int> _runWorkspaceCheck({
    required String workingDir,
    required String format,
    required String? outputPath,
    required bool quiet,
    required GuardConfig config,
    required PubClient client,
    required bool verbose,
  }) async {
    final projects = WorkspaceAnalyzer.discoverProjects(
      workingDir,
      maxDepth: config.workspace.maxDepth,
      excludePatterns: config.workspace.exclude.toList(),
    );

    final reportsMap = <String, ProjectReport>{};
    bool hasAnyFailure = false;

    for (final proj in projects) {
      final absoluteProjDir = p.join(workingDir, proj.relativePath);
      try {
        final executor = CheckCommandExecutor(pubClient: client);
        final report = await executor.execute(
          workingDir: absoluteProjDir,
          config: config,
          verbose: verbose,
        );
        reportsMap[proj.relativePath.isEmpty ? '.' : proj.relativePath] = report;
        if (report.hasPolicyViolations) {
          hasAnyFailure = true;
        }
      } catch (e) {
        if (verbose) {
          stderr.writeln('Warning: Failed workspace check for path: ${proj.relativePath}. $e');
        }
      }
    }

    final mismatches = WorkspaceAnalyzer.findMismatches(projects, workingDir);

    final String output = _renderWorkspaceReport(reportsMap, mismatches, format);
    if (!quiet) print(output);
    if (outputPath != null) {
      File(outputPath).writeAsStringSync(output);
    }

    return hasAnyFailure ? ExitCodes.policyViolation : ExitCodes.success;
  }

  Future<int> _runWorkspaceCi({
    required String workingDir,
    required Baseline? baseline,
    required String format,
    required String? outputPath,
    required bool quiet,
    required GuardConfig config,
    required PubClient client,
    required bool verbose,
  }) async {
    final projects = WorkspaceAnalyzer.discoverProjects(
      workingDir,
      maxDepth: config.workspace.maxDepth,
      excludePatterns: config.workspace.exclude.toList(),
    );

    final allViolations = <String, List<PolicyViolation>>{};
    bool hasViolations = false;

    for (final proj in projects) {
      final absoluteProjDir = p.join(workingDir, proj.relativePath);
      try {
        final executor = CheckCommandExecutor(pubClient: client);
        final report = await executor.execute(
          workingDir: absoluteProjDir,
          config: config,
          verbose: verbose,
        );

        final violations = CiCommandExecutor.evaluate(report, config, baseline);
        if (violations.isNotEmpty) {
          allViolations[proj.relativePath.isEmpty ? '.' : proj.relativePath] = violations;
          hasViolations = true;
        }
      } catch (e) {
        if (verbose) {
          stderr.writeln('Warning: Failed workspace CI for path: ${proj.relativePath}. $e');
        }
      }
    }

    final output = _renderWorkspaceCiViolations(allViolations, format);
    if (!quiet && output.isNotEmpty) print(output);
    if (outputPath != null) {
      File(outputPath).writeAsStringSync(output);
    }

    return hasViolations ? ExitCodes.policyViolation : ExitCodes.success;
  }

  String _renderReport(ProjectReport report, String format, bool useColor) {
    if (format == 'json') {
      return const JsonReporter().render(report);
    }
    if (format == 'markdown') {
      return const MarkdownReporter().render(report);
    }
    return ConsoleReporter(useColor: useColor).render(report);
  }

  String _renderCiViolations(List<PolicyViolation> violations, String format) {
    if (violations.isEmpty) {
      return format == 'json' ? '[]' : (format == 'markdown' ? 'No policy violations found.' : '');
    }

    if (format == 'json') {
      return const JsonEncoder.withIndent('  ').convert(violations.map((e) => e.toJson()).toList());
    }

    if (format == 'markdown') {
      final buffer = StringBuffer();
      buffer.writeln('## CI Policy Violations');
      buffer.writeln();
      for (final v in violations) {
        final pkgText = v.packageName != null ? ' (`${v.packageName}`)' : '';
        buffer.writeln('- **${v.code}**$pkgText: ${v.message}');
      }
      return buffer.toString();
    }

    final buffer = StringBuffer();
    buffer.writeln('CI Policy Violations:');
    for (final v in violations) {
      final pkgPrefix = v.packageName != null ? '${v.packageName}: ' : '';
      buffer.writeln('  [${v.code}] $pkgPrefix${v.message}');
    }
    return buffer.toString();
  }

  String _renderWorkspaceReport(
    Map<String, ProjectReport> reports,
    List<WorkspaceConstraintMismatch> mismatches,
    String format,
  ) {
    if (format == 'json') {
      final jsonMap = {
        'projects': reports.map((k, v) {
          // Compact project representation
          final map = <String, int>{};
          for (final dep in v.dependencies) {
            if (dep.isSkipped) continue;
            map[dep.risk.level.name] = (map[dep.risk.level.name] ?? 0) + 1;
          }
          return MapEntry(k, map);
        }),
        'mismatches': mismatches.map((e) => e.toJson()).toList(),
      };
      return const JsonEncoder.withIndent('  ').convert(jsonMap);
    }

    if (format == 'markdown') {
      final buffer = StringBuffer();
      buffer.writeln('# Workspace Update Guard Report');
      buffer.writeln();
      buffer.writeln('## Summary by Project');
      buffer.writeln();
      for (final entry in reports.entries) {
        buffer.writeln('### `${entry.key}`');
        buffer.writeln();
        buffer.writeln('| Level | Count |');
        buffer.writeln('|---|---:|');

        int safe = 0, low = 0, med = 0, high = 0, crit = 0;
        for (final dep in entry.value.dependencies) {
          if (dep.isSkipped) continue;
          switch (dep.risk.level) {
            case RiskLevel.safe: safe++; break;
            case RiskLevel.low: low++; break;
            case RiskLevel.medium: med++; break;
            case RiskLevel.high: high++; break;
            case RiskLevel.critical: crit++; break;
          }
        }
        buffer.writeln('| Safe | $safe |');
        buffer.writeln('| Low | $low |');
        buffer.writeln('| Medium | $med |');
        buffer.writeln('| High | $high |');
        buffer.writeln('| Critical | $crit |');
        buffer.writeln();
      }

      if (mismatches.isNotEmpty) {
        buffer.writeln('## Dependency constraint mismatch');
        buffer.writeln();
        for (final m in mismatches) {
          buffer.writeln('### `${m.packageName}` (${m.section})');
          buffer.writeln();
          for (final entry in m.constraintsByProject.entries) {
            buffer.writeln('- `${entry.key}`: `${entry.value}`');
          }
          buffer.writeln();
        }
      }
      return buffer.toString();
    }

    final buffer = StringBuffer();
    buffer.writeln('Workspace report');
    buffer.writeln();
    for (final entry in reports.entries) {
      buffer.writeln(entry.key);
      int safe = 0, low = 0, med = 0, high = 0, crit = 0;
      for (final dep in entry.value.dependencies) {
        if (dep.isSkipped) continue;
        switch (dep.risk.level) {
          case RiskLevel.safe: safe++; break;
          case RiskLevel.low: low++; break;
          case RiskLevel.medium: med++; break;
          case RiskLevel.high: high++; break;
          case RiskLevel.critical: crit++; break;
        }
      }
      if (safe > 0) buffer.writeln('  Safe: $safe');
      if (low > 0) buffer.writeln('  Low: $low');
      if (med > 0) buffer.writeln('  Medium: $med');
      if (high > 0) buffer.writeln('  High: $high');
      if (crit > 0) buffer.writeln('  Critical: $crit');
      buffer.writeln();
    }

    if (mismatches.isNotEmpty) {
      buffer.writeln('Dependency constraint mismatch');
      buffer.writeln();
      for (final m in mismatches) {
        buffer.writeln(m.packageName);
        for (final entry in m.constraintsByProject.entries) {
          buffer.writeln('  ${entry.key}: ${entry.value}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  String _renderWorkspaceCiViolations(Map<String, List<PolicyViolation>> violations, String format) {
    if (violations.isEmpty) {
      return format == 'json' ? '{}' : (format == 'markdown' ? 'No policy violations found in workspace.' : '');
    }

    if (format == 'json') {
      final jsonMap = violations.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
      return const JsonEncoder.withIndent('  ').convert(jsonMap);
    }

    if (format == 'markdown') {
      final buffer = StringBuffer();
      buffer.writeln('# Workspace CI Violations');
      buffer.writeln();
      for (final entry in violations.entries) {
        buffer.writeln('## `${entry.key}`');
        buffer.writeln();
        for (final v in entry.value) {
          buffer.writeln('- **${v.code}**: ${v.message}');
        }
        buffer.writeln();
      }
      return buffer.toString();
    }

    final buffer = StringBuffer();
    buffer.writeln('Workspace CI Violations:');
    buffer.writeln();
    for (final entry in violations.entries) {
      buffer.writeln(entry.key);
      for (final v in entry.value) {
        buffer.writeln('  [${v.code}] ${v.message}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _renderSimulationResult(SimulationResult res, String format) {
    if (format == 'json') {
      return const JsonEncoder.withIndent('  ').convert(res.toJson());
    }

    if (format == 'markdown') {
      final buffer = StringBuffer();
      buffer.writeln('# Simulation Report: ${res.packageName}');
      buffer.writeln();
      buffer.writeln('- **Target Version:** `${res.targetVersion}`');
      buffer.writeln('- **Success:** ${res.success ? '✅ Yes' : '❌ No'}');
      buffer.writeln();
      buffer.writeln('## Execution details');
      buffer.writeln();
      buffer.writeln('- **Pub Get:** Exit Code `${res.pubGetResult.exitCode}` (Duration: `${res.pubGetResult.duration.inMilliseconds}ms`)');
      if (res.analyzeResult != null) {
        buffer.writeln('- **Analyze:** Exit Code `${res.analyzeResult!.exitCode}` (Duration: `${res.analyzeResult!.duration.inMilliseconds}ms`)');
      }
      if (res.testResult != null) {
        buffer.writeln('- **Test:** Exit Code `${res.testResult!.exitCode}` (Duration: `${res.testResult!.duration.inMilliseconds}ms`)');
      }
      if (res.tempDirectoryKept && res.tempDirectory != null) {
        buffer.writeln('- **Sandbox Saved At:** `${res.tempDirectory}`');
      }
      return buffer.toString();
    }

    final buffer = StringBuffer();
    buffer.writeln('Simulation report: ${res.packageName}');
    buffer.writeln('  Target version: ${res.targetVersion}');
    buffer.writeln('  Success: ${res.success}');
    buffer.writeln('  Pub get code: ${res.pubGetResult.exitCode}');
    if (res.analyzeResult != null) {
      buffer.writeln('  Analyze code: ${res.analyzeResult!.exitCode}');
    }
    if (res.testResult != null) {
      buffer.writeln('  Test code: ${res.testResult!.exitCode}');
    }
    if (res.tempDirectoryKept && res.tempDirectory != null) {
      buffer.writeln('  Sandbox directory: ${res.tempDirectory}');
    }
    return buffer.toString();
  }

  void _printUsage(ArgParser parser) {
    print('Flutter App Update Guard CLI');
    print('\nUsage: flutter_app_update_guard <command> [options]\n');
    print('Available commands:');
    print('  check      Scan project dependencies for risk');
    print('  inspect    Verify detailed safety metrics for a single package');
    print('  report     Generate detailed markdown summaries');
    print('  ci         Evaluate policies against update reports');
    print('  baseline   Create baseline snapshots to exclude tech debt');
    print('  simulate   Sandbox dependency upgrades to test compilation health');
    print('  doctor     Run environment diagnostics');
    print('  fix        Automatically update safe dependencies and run pub get');
    print('\nGlobal Options:');
    print(parser.usage);
  }
}
