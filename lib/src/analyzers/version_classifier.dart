import 'package:pub_semver/pub_semver.dart';

/// Enum representing the categories of version updates.
enum UpdateType {
  none,
  patch,
  minor,
  major,
  prerelease,
  unknown,
}

/// Service class to classify the difference between two semantic versions.
class VersionClassifier {
  /// Classifies the update type when upgrading from [current] to [target].
  static UpdateType classify(Version current, Version target) {
    final coreEqual = current.major == target.major &&
        current.minor == target.minor &&
        current.patch == target.patch &&
        current.preRelease.join('.') == target.preRelease.join('.');

    if (coreEqual) {
      final currentBuild = current.build.join('.');
      final targetBuild = target.build.join('.');
      if (currentBuild != targetBuild) {
        return UpdateType.patch;
      }
      return UpdateType.none;
    }

    // If target is pre-release (e.g. -beta.1, -rc)
    if (target.isPreRelease) {
      return UpdateType.prerelease;
    }

    if (target.major > current.major) {
      return UpdateType.major;
    }

    if (target.major == current.major) {
      if (target.minor > current.minor) {
        return UpdateType.minor;
      }
      if (target.minor == current.minor) {
        if (target.patch > current.patch) {
          return UpdateType.patch;
        }
        // Resolving a pre-release version to its stable version (e.g. 1.0.0-beta.1 -> 1.0.0)
        if (target > current) {
          return UpdateType.patch;
        }
      }
    }

    // If target is less than current (downgrade)
    if (target < current) {
      return UpdateType.none;
    }

    return UpdateType.unknown;
  }
}
