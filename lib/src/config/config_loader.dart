import 'dart:io';
import 'package:yaml/yaml.dart';
import '../cli/exit_codes.dart';
import '../exceptions/guard_exception.dart';
import '../models/risk_models.dart';
import 'guard_config.dart';

/// Service class responsible for loading, parsing, and validating `flutter_app_update_guard.yaml` configurations.
class ConfigLoader {
  /// Loads configuration from the given file path.
  /// If file does not exist, returns the default config.
  /// Throws [GuardException] if yaml is invalid or has validation errors.
  static GuardConfig load(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return GuardConfig.defaultConfig();
    }

    try {
      final content = file.readAsStringSync();
      return parse(content);
    } on GuardException {
      rethrow;
    } on FileSystemException catch (e) {
      throw GuardException(
        'Failed to read configuration file: $filePath',
        exitCode: ExitCodes.invalidConfig,
        details: e,
      );
    } catch (e) {
      throw GuardException(
        'Unexpected error reading config file',
        exitCode: ExitCodes.invalidConfig,
        details: e,
      );
    }
  }

  /// Parses configuration from a raw YAML string.
  static GuardConfig parse(String yamlContent) {
    dynamic doc;
    try {
      doc = loadYaml(yamlContent);
    } catch (e) {
      throw GuardException(
        'Invalid YAML format in config',
        exitCode: ExitCodes.invalidConfig,
        details: e,
      );
    }

    if (doc == null) {
      return GuardConfig.defaultConfig();
    }

    if (doc is! Map) {
      throw const GuardException(
        'Configuration must be a YAML map structure at root',
        exitCode: ExitCodes.invalidConfig,
      );
    }

    final defaults = GuardConfig.defaultConfig();

    final riskConfig = _parseRisk(doc['risk'], defaults.risk);
    final checksConfig = _parseChecks(doc['checks'], defaults.checks);
    final maintenanceConfig = _parseMaintenance(doc['maintenance'], defaults.maintenance);
    final sourceUsageConfig = _parseSourceUsage(doc['source_usage'], defaults.sourceUsage);
    final simulationConfig = _parseSimulation(doc['simulation'], defaults.simulation);
    final policiesConfig = _parsePolicies(doc['policies'], defaults.policies);
    final workspaceConfig = _parseWorkspace(doc['workspace'], defaults.workspace);
    final ignoreConfig = _parseIgnore(doc['ignore'], defaults.ignore);

    return GuardConfig(
      risk: riskConfig,
      checks: checksConfig,
      maintenance: maintenanceConfig,
      sourceUsage: sourceUsageConfig,
      simulation: simulationConfig,
      policies: policiesConfig,
      workspace: workspaceConfig,
      ignore: ignoreConfig,
    );
  }

  static RiskConfig _parseRisk(dynamic node, RiskConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'risk' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    final failOnNode = node['fail_on'];
    final warnOnNode = node['warn_on'];

    Set<RiskLevel> failOn = defaults.failOn;
    if (failOnNode != null) {
      if (failOnNode is! List) {
        throw const GuardException(
          "The 'risk.fail_on' property must be a list of risk levels",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      try {
        failOn = failOnNode.map((e) => RiskLevel.parse(e.toString())).toSet();
      } catch (e) {
        throw GuardException(
          'Error parsing risk.fail_on level',
          exitCode: ExitCodes.invalidConfig,
          details: e,
        );
      }
    }

    Set<RiskLevel> warnOn = defaults.warnOn;
    if (warnOnNode != null) {
      if (warnOnNode is! List) {
        throw const GuardException(
          "The 'risk.warn_on' property must be a list of risk levels",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      try {
        warnOn = warnOnNode.map((e) => RiskLevel.parse(e.toString())).toSet();
      } catch (e) {
        throw GuardException(
          'Error parsing risk.warn_on level',
          exitCode: ExitCodes.invalidConfig,
          details: e,
        );
      }
    }

    return RiskConfig(failOn: failOn, warnOn: warnOn);
  }

  static ChecksConfig _parseChecks(dynamic node, ChecksConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'checks' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    bool parseBool(dynamic value, String name, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is! bool) {
        throw GuardException(
          "The 'checks.$name' property must be a boolean",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      return value;
    }

    return ChecksConfig(
      outdated: parseBool(node['outdated'], 'outdated', defaults.outdated),
      discontinued: parseBool(node['discontinued'], 'discontinued', defaults.discontinued),
      sdkCompatibility: parseBool(node['sdk_compatibility'], 'sdk_compatibility', defaults.sdkCompatibility),
      sourceUsage: parseBool(node['source_usage'], 'source_usage', defaults.sourceUsage),
      maintenance: parseBool(node['maintenance'], 'maintenance', defaults.maintenance),
      changelog: parseBool(node['changelog'], 'changelog', defaults.changelog),
      analyze: parseBool(node['analyze'], 'analyze', defaults.analyze),
      tests: parseBool(node['tests'], 'tests', defaults.tests),
    );
  }

  static MaintenanceConfig _parseMaintenance(dynamic node, MaintenanceConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'maintenance' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    final staleDays = node['stale_after_days'];
    int staleAfterDays = defaults.staleAfterDays;
    if (staleDays != null) {
      if (staleDays is! int) {
        throw const GuardException(
          "The 'maintenance.stale_after_days' property must be an integer",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      if (staleDays <= 0) {
        throw const GuardException(
          "The 'maintenance.stale_after_days' must be a positive integer (> 0)",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      staleAfterDays = staleDays;
    }

    return MaintenanceConfig(staleAfterDays: staleAfterDays);
  }

  static SourceUsageConfig _parseSourceUsage(dynamic node, SourceUsageConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'source_usage' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    bool parseBool(dynamic value, String name, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is! bool) {
        throw GuardException(
          "The 'source_usage.$name' property must be a boolean",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      return value;
    }

    final excludeNode = node['exclude'];
    Set<String> exclude = defaults.exclude;
    if (excludeNode != null) {
      if (excludeNode is! List) {
        throw const GuardException(
          "The 'source_usage.exclude' property must be a list of patterns",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      exclude = excludeNode.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    }

    return SourceUsageConfig(
      enabled: parseBool(node['enabled'], 'enabled', defaults.enabled),
      includeExports: parseBool(node['include_exports'], 'include_exports', defaults.includeExports),
      ignoreGenerated: parseBool(node['ignore_generated'], 'ignore_generated', defaults.ignoreGenerated),
      exclude: exclude,
    );
  }

  static SimulationConfig _parseSimulation(dynamic node, SimulationConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'simulation' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    bool parseBool(dynamic value, String name, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is! bool) {
        throw GuardException(
          "The 'simulation.$name' property must be a boolean",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      return value;
    }

    final timeoutNode = node['timeout_seconds'];
    int timeoutSeconds = defaults.timeoutSeconds;
    if (timeoutNode != null) {
      if (timeoutNode is! int) {
        throw const GuardException(
          "The 'simulation.timeout_seconds' property must be an integer",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      if (timeoutSeconds <= 0) {
        throw const GuardException(
          "The 'simulation.timeout_seconds' must be a positive integer (> 0)",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      timeoutSeconds = timeoutNode;
    }

    return SimulationConfig(
      runAnalyze: parseBool(node['run_analyze'], 'run_analyze', defaults.runAnalyze),
      runTests: parseBool(node['run_tests'], 'run_tests', defaults.runTests),
      timeoutSeconds: timeoutSeconds,
      keepTempOnFailure: parseBool(node['keep_temp_on_failure'], 'keep_temp_on_failure', defaults.keepTempOnFailure),
    );
  }

  static PoliciesConfig _parsePolicies(dynamic node, PoliciesConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'policies' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    bool parseBool(dynamic value, String name, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is! bool) {
        throw GuardException(
          "The 'policies.$name' property must be a boolean",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      return value;
    }

    int parseInt(dynamic value, String name, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is! int) {
        throw GuardException(
          "The 'policies.$name' property must be an integer",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      if (value < 0) {
        throw GuardException(
          "The 'policies.$name' must be a non-negative integer (>= 0)",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      return value;
    }

    return PoliciesConfig(
      allowPrerelease: parseBool(node['allow_prerelease'], 'allow_prerelease', defaults.allowPrerelease),
      allowMajorUpdates: parseBool(node['allow_major_updates'], 'allow_major_updates', defaults.allowMajorUpdates),
      failOnDiscontinued: parseBool(node['fail_on_discontinued'], 'fail_on_discontinued', defaults.failOnDiscontinued),
      failOnSdkIncompatible: parseBool(node['fail_on_sdk_incompatible'], 'fail_on_sdk_incompatible', defaults.failOnSdkIncompatible),
      maxCriticalDependencies: parseInt(node['max_critical_dependencies'], 'max_critical_dependencies', defaults.maxCriticalDependencies),
      maxHighRiskDependencies: parseInt(node['max_high_risk_dependencies'], 'max_high_risk_dependencies', defaults.maxHighRiskDependencies),
      maxMediumRiskDependencies: parseInt(node['max_medium_risk_dependencies'], 'max_medium_risk_dependencies', defaults.maxMediumRiskDependencies),
    );
  }

  static WorkspaceConfig _parseWorkspace(dynamic node, WorkspaceConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'workspace' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    bool parseBool(dynamic value, String name, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is! bool) {
        throw GuardException(
          "The 'workspace.$name' property must be a boolean",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      return value;
    }

    final depthNode = node['max_depth'];
    int maxDepth = defaults.maxDepth;
    if (depthNode != null) {
      if (depthNode is! int) {
        throw const GuardException(
          "The 'workspace.max_depth' property must be an integer",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      if (depthNode <= 0) {
        throw const GuardException(
          "The 'workspace.max_depth' must be a positive integer (> 0)",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      maxDepth = depthNode;
    }

    final excludeNode = node['exclude'];
    Set<String> exclude = defaults.exclude;
    if (excludeNode != null) {
      if (excludeNode is! List) {
        throw const GuardException(
          "The 'workspace.exclude' property must be a list of patterns",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      exclude = excludeNode.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    }

    return WorkspaceConfig(
      enabled: parseBool(node['enabled'], 'enabled', defaults.enabled),
      maxDepth: maxDepth,
      exclude: exclude,
    );
  }

  static IgnoreConfig _parseIgnore(dynamic node, IgnoreConfig defaults) {
    if (node == null) return defaults;
    if (node is! Map) {
      throw const GuardException(
        "The 'ignore' section must be a map",
        exitCode: ExitCodes.invalidConfig,
      );
    }

    final packagesNode = node['packages'];
    Set<String> packages = defaults.packages;
    if (packagesNode != null) {
      if (packagesNode is! List) {
        throw const GuardException(
          "The 'ignore.packages' property must be a list of package names",
          exitCode: ExitCodes.invalidConfig,
        );
      }
      packages = packagesNode.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    }

    return IgnoreConfig(packages: packages);
  }
}
