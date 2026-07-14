import 'dart:convert';
import 'dart:io';
import '../models/project_report.dart';

/// Representation of a baseline entry for a single dependency.
class BaselineEntry {
  final String name;
  final String currentVersion;
  final String riskLevel;
  final List<String> riskReasonCodes;

  const BaselineEntry({
    required this.name,
    required this.currentVersion,
    required this.riskLevel,
    required this.riskReasonCodes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'currentVersion': currentVersion,
        'riskLevel': riskLevel,
        'riskReasonCodes': riskReasonCodes,
      };

  factory BaselineEntry.fromJson(Map<String, dynamic> json) {
    return BaselineEntry(
      name: json['name'] as String,
      currentVersion: json['currentVersion'] as String,
      riskLevel: json['riskLevel'] as String,
      riskReasonCodes: (json['riskReasonCodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Project baseline containing package risk configurations to bypass existing debt.
class Baseline {
  final Map<String, BaselineEntry> packages;
  final DateTime timestamp;
  final String toolVersion;

  const Baseline({
    required this.packages,
    required this.timestamp,
    required this.toolVersion,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'toolVersion': toolVersion,
        'packages': packages.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Baseline.fromJson(Map<String, dynamic> json) {
    final packagesMap = <String, BaselineEntry>{};
    final pkgs = json['packages'] as Map<String, dynamic>?;
    if (pkgs != null) {
      pkgs.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          packagesMap[key] = BaselineEntry.fromJson(val);
        }
      });
    }

    return Baseline(
      packages: packagesMap,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      toolVersion: (json['toolVersion'] as String?) ?? '1.0.0',
    );
  }

  factory Baseline.empty() => Baseline(
        packages: const {},
        timestamp: DateTime.now(),
        toolVersion: '1.0.0',
      );
}

/// Service class to load and save baseline files.
class BaselineManager {
  /// Loads baseline from file path. Returns empty baseline if file does not exist.
  static Baseline load(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return Baseline.empty();
    }

    try {
      final jsonStr = file.readAsStringSync();
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return Baseline.fromJson(decoded);
    } catch (_) {
      return Baseline.empty();
    }
  }

  /// Saves baseline generated from [projectReport] into [filePath].
  static void save(String filePath, ProjectReport projectReport, String toolVersion) {
    final packages = <String, BaselineEntry>{};

    for (final depReport in projectReport.dependencies) {
      if (depReport.isSkipped) continue;

      final dep = depReport.dependency;
      packages[dep.name] = BaselineEntry(
        name: dep.name,
        currentVersion: dep.lockedVersion?.toString() ?? '0.0.0',
        riskLevel: depReport.risk.level.name,
        riskReasonCodes: depReport.risk.reasons.map((r) => r.code).toList(),
      );
    }

    final baseline = Baseline(
      packages: packages,
      timestamp: DateTime.now(),
      toolVersion: toolVersion,
    );

    final file = File(filePath);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(baseline.toJson()));
  }
}
