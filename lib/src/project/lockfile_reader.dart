import 'dart:io';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import '../cli/exit_codes.dart';
import '../exceptions/guard_exception.dart';
import '../models/dependency_info.dart';

/// Representation of a resolved package inside `pubspec.lock`.
class LockedPackageInfo {
  final Version version;
  final DependencyKind kind;

  const LockedPackageInfo({
    required this.version,
    required this.kind,
  });
}

/// Class to read and parse the project's `pubspec.lock`.
class LockfileReader {
  /// Reads and parses the `pubspec.lock` at the given path.
  /// Throws [GuardException] if reading or parsing fails.
  static Map<String, LockedPackageInfo> read(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw GuardException(
        'pubspec.lock not found at: $filePath. Please run "dart pub get" first.',
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content);

      if (yaml is! Map) {
        throw const GuardException(
          'pubspec.lock structure must be a YAML map',
          exitCode: ExitCodes.dependencyReadError,
        );
      }

      final packagesNode = yaml['packages'];
      final map = <String, LockedPackageInfo>{};

      if (packagesNode is Map) {
        for (final entry in packagesNode.entries) {
          final name = entry.key as String;
          final details = entry.value;

          if (details is Map) {
            final versionStr = details['version'] as String?;
            if (versionStr == null) continue;

            final version = Version.parse(versionStr);
            final sourceStr = details['source'] as String? ?? 'hosted';

            final DependencyKind kind;
            switch (sourceStr) {
              case 'hosted':
                kind = DependencyKind.hosted;
                break;
              case 'git':
                kind = DependencyKind.git;
                break;
              case 'path':
                kind = DependencyKind.path;
                break;
              case 'sdk':
                kind = DependencyKind.sdk;
                break;
              default:
                kind = DependencyKind.hosted;
            }

            map[name] = LockedPackageInfo(version: version, kind: kind);
          }
        }
      }

      return map;
    } on GuardException {
      rethrow;
    } catch (e) {
      throw GuardException(
        'Failed to read or parse pubspec.lock',
        exitCode: ExitCodes.dependencyReadError,
        details: e,
      );
    }
  }
}
