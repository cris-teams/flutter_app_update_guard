import 'package:pub_semver/pub_semver.dart';

/// The type of dependency reference.
enum DependencyKind {
  hosted,
  git,
  path,
  sdk,
}

/// The pubspec section where the dependency is declared.
enum DependencySection {
  dependencies,
  devDependencies,
  dependencyOverrides,
}

/// Representation of a dependency read from pubspec.yaml and resolved via pubspec.lock.
class DependencyInfo {
  final String name;
  final DependencyKind kind;
  final DependencySection section;
  final String? constraint;
  final Version? lockedVersion;

  const DependencyInfo({
    required this.name,
    required this.kind,
    required this.section,
    this.constraint,
    this.lockedVersion,
  });

  /// True if the package is published on pub.dev (hosted kind)
  bool get isHosted => kind == DependencyKind.hosted;

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'section': section.name,
        'constraint': constraint,
        'lockedVersion': lockedVersion?.toString(),
      };
}
