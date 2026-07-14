import 'dart:io';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import '../models/dependency_info.dart';
import '../models/workspace_models.dart';
import '../project/pubspec_reader.dart';

/// Project package details identified in a workspace scan.
class WorkspaceProject {
  final String name;
  final String relativePath;
  final String pubspecPath;

  const WorkspaceProject({
    required this.name,
    required this.relativePath,
    required this.pubspecPath,
  });
}

/// Service identifying monorepo projects and analyzing package constraint consistency.
class WorkspaceAnalyzer {
  /// Scans the target workspace root recursively up to [maxDepth] to discover projects.
  /// Bypasses paths matching [excludePatterns].
  static List<WorkspaceProject> discoverProjects(
    String workspaceRoot, {
    int maxDepth = 5,
    List<String> excludePatterns = const [],
  }) {
    final root = Directory(p.canonicalize(p.absolute(workspaceRoot)));
    if (!root.existsSync()) {
      return const [];
    }

    final projects = <WorkspaceProject>[];
    final excludes = excludePatterns.map((pat) => Glob(pat)).toList();
    final skipDirs = {'.dart_tool', 'build', '.git', '.idea', '.vscode', '.fvm', '.symlinks'};

    void scanDir(Directory currentDir, int currentDepth) {
      if (currentDepth > maxDepth) return;

      final dirName = p.basename(currentDir.path);
      if (skipDirs.contains(dirName)) return;

      final relDir = p.relative(currentDir.path, from: root.path).replaceAll('\\', '/');
      if (relDir != '.') {
        bool isExcluded = false;
        for (final glob in excludes) {
          if (glob.matches(relDir)) {
            isExcluded = true;
            break;
          }
        }
        if (isExcluded) return;
      }

      // Check if pubspec.yaml exists in this directory
      final pubspec = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final relativePubspecPath = p.relative(pubspec.path, from: root.path).replaceAll('\\', '/');
        bool isExcluded = false;
        for (final glob in excludes) {
          if (glob.matches(relativePubspecPath)) {
            isExcluded = true;
            break;
          }
        }

        if (!isExcluded) {
          try {
            final data = PubspecReader.read(pubspec.path);
            projects.add(WorkspaceProject(
              name: data.projectName,
              relativePath: relDir == '.' ? '' : relDir,
              pubspecPath: relativePubspecPath,
            ));
          } catch (_) {
            // Skip invalid/unreadable pubspec.yaml
          }
        }
      }

      // Traverse children
      try {
        for (final entity in currentDir.listSync(recursive: false, followLinks: false)) {
          if (entity is Directory) {
            scanDir(entity, currentDepth + 1);
          }
        }
      } catch (_) {
        // Skip unreadable directories
      }
    }

    scanDir(root, 0);
    // Sort projects for determinism
    projects.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return projects;
  }

  /// Analyzes discovered [projects] for package constraint mismatches across production and dev dependencies.
  static List<WorkspaceConstraintMismatch> findMismatches(List<WorkspaceProject> projects, String workspaceRoot) {
    final rootPath = p.canonicalize(p.absolute(workspaceRoot));
    
    // package -> section -> projectPath -> constraint
    final Map<String, Map<String, Map<String, String>>> declarations = {};

    for (final proj in projects) {
      final absolutePubspec = p.join(rootPath, proj.pubspecPath);
      try {
        final data = PubspecReader.read(absolutePubspec);
        final projIdentifier = proj.relativePath.isEmpty ? '.' : proj.relativePath;

        for (final dep in data.dependencies) {
          final sect = dep.section == DependencySection.dependencies
              ? 'dependencies'
              : (dep.section == DependencySection.devDependencies ? 'dev_dependencies' : null);
          if (sect == null) continue;

          final pkgMap = declarations.putIfAbsent(dep.name, () => {});
          final sectMap = pkgMap.putIfAbsent(sect, () => {});
          sectMap[projIdentifier] = dep.constraint ?? '';
        }
      } catch (_) {
        // Skip projects with read/parse failures
      }
    }

    final mismatches = <WorkspaceConstraintMismatch>[];

    // Sort package names alphabetically for determinism
    final sortedPackages = declarations.keys.toList()..sort();

    for (final pkg in sortedPackages) {
      final sections = declarations[pkg]!;
      for (final sect in sections.keys) {
        final projectConstraints = sections[sect]!;
        if (projectConstraints.length <= 1) continue;

        // Check if there are non-equivalent constraints
        final uniqueRanges = <VersionConstraint>[];
        final uniqueStrings = <String>{};
        bool hasMismatch = false;

        for (final entry in projectConstraints.entries) {
          final constraintStr = entry.value;
          uniqueStrings.add(constraintStr);

          try {
            final parsed = VersionConstraint.parse(constraintStr);
            if (uniqueRanges.isEmpty) {
              uniqueRanges.add(parsed);
            } else {
              bool isEquivalent = false;
              for (final range in uniqueRanges) {
                if (range.allowsAll(parsed) && parsed.allowsAll(range)) {
                  isEquivalent = true;
                  break;
                }
              }
              if (!isEquivalent) {
                hasMismatch = true;
                uniqueRanges.add(parsed);
              }
            }
          } catch (_) {
            // If it's a non-semver constraint (like git map representation or empty),
            // fallback to direct string comparison.
            if (uniqueStrings.length > 1) {
              hasMismatch = true;
            }
          }
        }

        if (hasMismatch) {
          mismatches.add(WorkspaceConstraintMismatch(
            packageName: pkg,
            section: sect,
            constraintsByProject: Map.from(projectConstraints),
          ));
        }
      }
    }

    return mismatches;
  }
}
