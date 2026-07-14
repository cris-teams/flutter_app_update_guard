import 'package:pub_semver/pub_semver.dart';

/// Metadata of a package fetched from pub.dev.
class PubPackageInfo {
  final String name;
  final Version latestVersion;
  final DateTime latestPublished;
  final String? dartSdkConstraint;
  final String? flutterSdkConstraint;
  final bool isDiscontinued;
  final String? replacedBy;
  final String? repositoryUrl;
  final String? homepageUrl;

  const PubPackageInfo({
    required this.name,
    required this.latestVersion,
    required this.latestPublished,
    this.dartSdkConstraint,
    this.flutterSdkConstraint,
    required this.isDiscontinued,
    this.replacedBy,
    this.repositoryUrl,
    this.homepageUrl,
  });

  /// Factory constructor to parse the JSON response from `https://pub.dev/api/packages/<package>`.
  factory PubPackageInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;

    // Parse latest version details
    final latestNode = json['latest'] as Map<String, dynamic>?;
    if (latestNode == null) {
      throw FormatException("Missing 'latest' field for package $name");
    }

    final versionStr = latestNode['version'] as String;
    final latestVersion = Version.parse(versionStr);
    
    final publishedStr = latestNode['published'] as String;
    final latestPublished = DateTime.parse(publishedStr);

    final pubspec = latestNode['pubspec'] as Map<String, dynamic>? ?? {};
    final environment = pubspec['environment'] as Map<String, dynamic>? ?? {};
    
    final dartSdkConstraint = environment['sdk'] as String?;
    final flutterSdkConstraint = environment['flutter'] as String?;

    // Discontinued properties are top level
    final isDiscontinued = json['isDiscontinued'] as bool? ?? false;
    final replacedBy = json['replacedBy'] as String?;

    final repositoryUrl = pubspec['repository'] as String?;
    final homepageUrl = pubspec['homepage'] as String?;

    return PubPackageInfo(
      name: name,
      latestVersion: latestVersion,
      latestPublished: latestPublished,
      dartSdkConstraint: dartSdkConstraint,
      flutterSdkConstraint: flutterSdkConstraint,
      isDiscontinued: isDiscontinued,
      replacedBy: replacedBy,
      repositoryUrl: repositoryUrl,
      homepageUrl: homepageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'latestVersion': latestVersion.toString(),
        'latestPublished': latestPublished.toIso8601String(),
        'dartSdkConstraint': dartSdkConstraint,
        'flutterSdkConstraint': flutterSdkConstraint,
        'isDiscontinued': isDiscontinued,
        'replacedBy': replacedBy,
        'repositoryUrl': repositoryUrl,
        'homepageUrl': homepageUrl,
      };
}
