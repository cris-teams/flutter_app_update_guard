import 'package:flutter_app_update_guard/src/models/pub_package_info.dart';
import 'package:flutter_app_update_guard/src/pub/pub_client.dart';

/// Shared fake client for pub.dev API requests under tests.
class FakePubClient implements PubClient {
  final Map<String, PubPackageInfo> packages;

  FakePubClient(this.packages);

  @override
  Future<PubPackageInfo> getPackage(String packageName) async {
    final info = packages[packageName];
    if (info == null) {
      throw Exception('Package not found: $packageName');
    }
    return info;
  }
}
