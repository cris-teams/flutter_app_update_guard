import 'dart:io';
import 'package:path/path.dart' as p;
import '../cli/exit_codes.dart';
import '../exceptions/guard_exception.dart';

/// Paths of detected project files.
class ProjectPaths {
  final String rootPath;
  final String pubspecPath;
  final String lockfilePath;

  const ProjectPaths({
    required this.rootPath,
    required this.pubspecPath,
    required this.lockfilePath,
  });
}

/// Helper service to detect Dart/Flutter project roots.
class ProjectDetector {
  /// Detects the project starting at [workingDir].
  /// Throws [GuardException] if [pubspec.yaml] is not found.
  static ProjectPaths detect(String workingDir) {
    final root = p.canonicalize(p.absolute(workingDir));
    final pubspec = p.join(root, 'pubspec.yaml');
    final lockfile = p.join(root, 'pubspec.lock');

    if (!File(pubspec).existsSync()) {
      throw GuardException(
        'pubspec.yaml not found in directory: $root',
        exitCode: ExitCodes.pubspecNotFound,
      );
    }

    return ProjectPaths(
      rootPath: root,
      pubspecPath: pubspec,
      lockfilePath: lockfile,
    );
  }
}
