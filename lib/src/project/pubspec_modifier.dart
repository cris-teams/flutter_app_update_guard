import 'dart:io';
import 'package:yaml/yaml.dart';
import '../cli/exit_codes.dart';
import '../exceptions/guard_exception.dart';

/// Service class to safely modify dependency versions inside `pubspec.yaml` using source spans.
class PubspecModifier {
  /// Modifies the constraint of [packageName] to [newVersion] inside the [pubspecPath] file.
  /// Modifies only the source span of the version declaration, preserving formatting and comments.
  /// Throws [GuardException] if modification fails or cannot be done safely.
  static void updateDependency(String pubspecPath, String packageName, String newVersion) {
    final file = File(pubspecPath);
    if (!file.existsSync()) {
      throw GuardException(
        'pubspec.yaml not found for simulation: $pubspecPath',
        exitCode: ExitCodes.pubspecNotFound,
      );
    }

    final content = file.readAsStringSync();
    final YamlNode doc;
    try {
      doc = loadYamlNode(content);
    } catch (e) {
      throw GuardException(
        'Failed to parse YAML during simulation in $pubspecPath',
        exitCode: ExitCodes.dependencyReadError,
        details: e,
      );
    }

    if (doc is! YamlMap) {
      throw const GuardException(
        'pubspec.yaml root is not a YAML map',
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    // Search under dependencies, dev_dependencies, dependency_overrides
    final sections = ['dependencies', 'dev_dependencies', 'dependency_overrides'];
    YamlNode? targetSectionNode;
    String? foundSectionName;

    for (final sec in sections) {
      if (doc.nodes.containsKey(sec)) {
        final secNode = doc.nodes[sec];
        if (secNode is YamlMap && secNode.nodes.containsKey(packageName)) {
          targetSectionNode = secNode;
          foundSectionName = sec;
          break;
        }
      }
    }

    if (targetSectionNode == null || targetSectionNode is! YamlMap || foundSectionName == null) {
      throw GuardException(
        "Package '$packageName' not found in dependencies of $pubspecPath",
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    final pkgNode = targetSectionNode.nodes[packageName]!;

    int startOffset;
    int endOffset;
    String replacement;

    if (pkgNode is YamlScalar) {
      // e.g. dio: ^5.7.0
      startOffset = pkgNode.span.start.offset;
      endOffset = pkgNode.span.end.offset;
      replacement = '"$newVersion"'; // wrap in quotes for safety in YAML string parsing
    } else if (pkgNode is YamlMap) {
      // check if it's hosted map
      final isHosted = pkgNode.nodes.containsKey('hosted') || pkgNode.nodes.containsKey('version');
      final isGit = pkgNode.nodes.containsKey('git');
      final isPath = pkgNode.nodes.containsKey('path');
      final isSdk = pkgNode.nodes.containsKey('sdk');

      if (isGit || isPath || isSdk) {
        throw GuardException(
          "Cannot simulate update for git/path/sdk dependency '$packageName'",
          exitCode: ExitCodes.dependencyReadError,
        );
      }

      if (!isHosted) {
        throw GuardException(
          "Unsupported map structure for dependency '$packageName' in section '$foundSectionName'",
          exitCode: ExitCodes.dependencyReadError,
        );
      }

      final versionNode = pkgNode.nodes['version'];
      if (versionNode is YamlScalar) {
        startOffset = versionNode.span.start.offset;
        endOffset = versionNode.span.end.offset;
        replacement = '"$newVersion"';
      } else if (versionNode == null) {
        // version is missing, append it to the map
        startOffset = pkgNode.span.end.offset;
        endOffset = startOffset;
        replacement = '\n  version: "$newVersion"';
      } else {
        throw GuardException(
          "Invalid version field structure for package '$packageName'",
          exitCode: ExitCodes.dependencyReadError,
        );
      }
    } else {
      throw GuardException(
        "Unrecognized dependency structure for package '$packageName'",
        exitCode: ExitCodes.dependencyReadError,
      );
    }

    // Apply replacement on the raw content string
    final updatedContent = content.replaceRange(startOffset, endOffset, replacement);

    // Save back to file
    try {
      file.writeAsStringSync(updatedContent);
    } catch (e) {
      throw GuardException(
        'Failed to save updated pubspec.yaml during simulation',
        exitCode: ExitCodes.dependencyReadError,
        details: e,
      );
    }
  }
}
