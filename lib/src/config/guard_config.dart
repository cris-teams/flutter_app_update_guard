import '../models/risk_models.dart';

/// Immutable model representing the flutter_app_update_guard configurations.
class GuardConfig {
  final RiskConfig risk;
  final ChecksConfig checks;
  final MaintenanceConfig maintenance;
  final SourceUsageConfig sourceUsage;
  final SimulationConfig simulation;
  final PoliciesConfig policies;
  final WorkspaceConfig workspace;
  final IgnoreConfig ignore;

  const GuardConfig({
    required this.risk,
    required this.checks,
    required this.maintenance,
    required this.sourceUsage,
    required this.simulation,
    required this.policies,
    required this.workspace,
    required this.ignore,
  });

  /// Factory for the default configuration.
  factory GuardConfig.defaultConfig() {
    return const GuardConfig(
      risk: RiskConfig(
        failOn: {RiskLevel.critical},
        warnOn: {RiskLevel.high, RiskLevel.medium},
      ),
      checks: ChecksConfig(
        outdated: true,
        discontinued: true,
        sdkCompatibility: true,
        sourceUsage: true,
        maintenance: true,
        changelog: true,
        analyze: true,
        tests: false,
      ),
      maintenance: MaintenanceConfig(
        staleAfterDays: 730,
      ),
      sourceUsage: SourceUsageConfig(
        enabled: true,
        includeExports: true,
        ignoreGenerated: true,
        exclude: {},
      ),
      simulation: SimulationConfig(
        runAnalyze: true,
        runTests: false,
        timeoutSeconds: 300,
        keepTempOnFailure: false,
      ),
      policies: PoliciesConfig(
        allowPrerelease: false,
        allowMajorUpdates: false,
        failOnDiscontinued: true,
        failOnSdkIncompatible: true,
        maxCriticalDependencies: 0,
        maxHighRiskDependencies: 3,
        maxMediumRiskDependencies: 10,
      ),
      workspace: WorkspaceConfig(
        enabled: false,
        maxDepth: 5,
        exclude: {},
      ),
      ignore: IgnoreConfig(
        packages: {},
      ),
    );
  }
}

class RiskConfig {
  final Set<RiskLevel> failOn;
  final Set<RiskLevel> warnOn;

  const RiskConfig({
    required this.failOn,
    required this.warnOn,
  });
}

class ChecksConfig {
  final bool outdated;
  final bool discontinued;
  final bool sdkCompatibility;
  final bool sourceUsage;
  final bool maintenance;
  final bool changelog;
  final bool analyze;
  final bool tests;

  const ChecksConfig({
    required this.outdated,
    required this.discontinued,
    required this.sdkCompatibility,
    required this.sourceUsage,
    required this.maintenance,
    required this.changelog,
    required this.analyze,
    required this.tests,
  });
}

class MaintenanceConfig {
  final int staleAfterDays;

  const MaintenanceConfig({
    required this.staleAfterDays,
  }) : assert(staleAfterDays > 0, 'staleAfterDays must be positive');
}

class SourceUsageConfig {
  final bool enabled;
  final bool includeExports;
  final bool ignoreGenerated;
  final Set<String> exclude;

  const SourceUsageConfig({
    required this.enabled,
    required this.includeExports,
    required this.ignoreGenerated,
    required this.exclude,
  });
}

class SimulationConfig {
  final bool runAnalyze;
  final bool runTests;
  final int timeoutSeconds;
  final bool keepTempOnFailure;

  const SimulationConfig({
    required this.runAnalyze,
    required this.runTests,
    required this.timeoutSeconds,
    required this.keepTempOnFailure,
  }) : assert(timeoutSeconds > 0, 'timeoutSeconds must be positive');
}

class PoliciesConfig {
  final bool allowPrerelease;
  final bool allowMajorUpdates;
  final bool failOnDiscontinued;
  final bool failOnSdkIncompatible;
  final int maxCriticalDependencies;
  final int maxHighRiskDependencies;
  final int maxMediumRiskDependencies;

  const PoliciesConfig({
    required this.allowPrerelease,
    required this.allowMajorUpdates,
    required this.failOnDiscontinued,
    required this.failOnSdkIncompatible,
    required this.maxCriticalDependencies,
    required this.maxHighRiskDependencies,
    required this.maxMediumRiskDependencies,
  })  : assert(maxCriticalDependencies >= 0, 'maxCriticalDependencies must be non-negative'),
        assert(maxHighRiskDependencies >= 0, 'maxHighRiskDependencies must be non-negative'),
        assert(maxMediumRiskDependencies >= 0, 'maxMediumRiskDependencies must be non-negative');
}

class WorkspaceConfig {
  final bool enabled;
  final int maxDepth;
  final Set<String> exclude;

  const WorkspaceConfig({
    required this.enabled,
    required this.maxDepth,
    required this.exclude,
  }) : assert(maxDepth > 0, 'maxDepth must be positive');
}

class IgnoreConfig {
  final Set<String> packages;

  const IgnoreConfig({
    required this.packages,
  });
}
