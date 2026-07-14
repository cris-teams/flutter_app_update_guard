import '../models/pub_package_info.dart';
import 'pub_client.dart';

/// Decorator for [PubClient] that caches queried package results in memory.
class CachedPubClient implements PubClient {
  final PubClient _delegate;
  final Map<String, PubPackageInfo> _cache = {};

  CachedPubClient(this._delegate);

  @override
  Future<PubPackageInfo> getPackage(String packageName) async {
    final cached = _cache[packageName];
    if (cached != null) {
      return cached;
    }
    final result = await _delegate.getPackage(packageName);
    _cache[packageName] = result;
    return result;
  }

  /// Clears the in-memory cache.
  void clear() => _cache.clear();

  /// Gets the count of cached package entries.
  int get size => _cache.length;
}
