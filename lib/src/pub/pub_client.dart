import '../models/pub_package_info.dart';

/// Abstraction for querying package metadata from a package repository (e.g., pub.dev).
abstract interface class PubClient {
  /// Fetches [PubPackageInfo] for the given [packageName].
  /// Throws [Exception] (specifically [GuardException] when implemented) if call fails.
  Future<PubPackageInfo> getPackage(String packageName);
}
