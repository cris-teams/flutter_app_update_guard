import 'dart:io';
import 'package:yaml/yaml.dart';
import '../cli/exit_codes.dart';
import '../exceptions/guard_exception.dart';
import '../models/dependency_info.dart';

/// Class to read and parse the project's `pubspec.yaml`.
class PubspecReader {
  /// Reads and parses the `pubspec.yaml` at the given path.
  /// Throws [GuardException] if reading or parsing fails.
  static PubspecData read(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw GuardException(
        'pubspec.yaml not found at: $filePath',
        exitCode: ExitCodes.pubspecNotFound,
      );
    }

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content);

      if (yaml is! Map) {
        throw const GuardException(
          'pubspec.yaml root must be a YAML map',
          exitCode: ExitCodes.dependencyReadError,
        );
      }

      final projectName = yaml['name'] as String? ?? 'unnamed_project';

      // Parse SDK environment constraints
      final environment = yaml['environment'] as Map? ?? {};
      final dartSdk = environment['sdk'] as String?;
      final flutterSdk = environment['flutter'] as String?;

      final dependencies = <RawDependency>[];

      _parseSection(yaml['dependencies'], DependencySection.dependencies, dependencies);
      _parseSection(yaml['dev_dependencies'], DependencySection.devDependencies, dependencies);
      _parseSection(yaml['dependency_overrides'], DependencySection.dependencyOverrides, dependencies);

      return PubspecData(
        projectName: projectName,
        dartSdkConstraint: dartSdk,
        flutterSdkConstraint: flutterSdk,
        dependencies: dependencies,
      );
    } on GuardException {
      rethrow;
    } catch (e) {
      throw GuardException(
        'Failed to read or parse pubspec.yaml',
        exitCode: ExitCodes.dependencyReadError,
        details: e,
      );
    }
  }

  static void _parseSection(
    dynamic sectionNode,
    DependencySection section,
    List<RawDependency> list,
  ) {
    if (sectionNode == null) return;
    if (sectionNode is! Map) {
      throw GuardException(
        "Invalid section structure for '${section.name}' in pubspec.yaml",
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    for (final entry in sectionNode.entries) {
      final name = entry.key as String;
      final val = entry.value;

      String? constraint;
      DependencyKind kind = DependencyKind.hosted;

      if (val is String) {
        constraint = val;
        kind = DependencyKind.hosted;
      } else if (val is Map) {
        if (val.containsKey('path')) {
          kind = DependencyKind.path;
        } else if (val.containsKey('git')) {
          kind = DependencyKind.git;
        } else if (val.containsKey('sdk')) {
          kind = DependencyKind.sdk;
        } else if (val.containsKey('hosted')) {
          kind = DependencyKind.hosted;
          final hostedNode = val['hosted'];
          if (hostedNode is Map) {
            constraint = val['version'] as String?;
          } else {
            constraint = hostedNode as String?;
          }
        } else {
          constraint = val['version'] as String?;
        }
      } else if (val != null) {
        throw GuardException(
          "Invalid dependency format for package '$name' in section '${section.name}'",
          exitCode: ExitCodes.dependencyReadError,
        );
      }

      list.add(RawDependency(
        name: name,
        kind: kind,
        section: section,
        constraint: constraint,
      ));
    }
  }
}

/// Temporary class to hold raw dependency definitions before merging with lockfile.
class RawDependency {
  final String name;
  final DependencyKind kind;
  final DependencySection section;
  final String? constraint;

  const RawDependency({
    required this.name,
    required this.kind,
    required this.section,
    this.constraint,
  });
}

/// Extracted data from pubspec.yaml.
class PubspecData {
  final String projectName;
  final String? dartSdkConstraint;
  final String? flutterSdkConstraint;
  final List<RawDependency> dependencies;

  const PubspecData({
    required this.projectName,
    this.dartSdkConstraint,
    this.flutterSdkConstraint,
    required this.dependencies,
  });
}
