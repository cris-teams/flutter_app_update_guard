import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../cli/exit_codes.dart';
import '../exceptions/guard_exception.dart';
import '../models/pub_package_info.dart';
import 'pub_client.dart';

/// Concrete implementation of [PubClient] interacting with the pub.dev JSON API.
class PubApiClient implements PubClient {
  final http.Client _client;
  final String baseUrl;
  final int maxRetries;
  final Duration timeout;

  PubApiClient({
    http.Client? client,
    this.baseUrl = 'https://pub.dev/api/packages/',
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  @override
  Future<PubPackageInfo> getPackage(String packageName) async {
    final uri = Uri.parse('$baseUrl$packageName');
    int attempt = 0;

    while (true) {
      attempt++;
      try {
        final response = await _client.get(
          uri,
          headers: {
            'User-Agent': 'flutter_app_update_guard/1.1.0 (+https://github.com/example/flutter_app_update_guard)',
            'Accept': 'application/json',
          },
        ).timeout(timeout);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw FormatException('Expected JSON map, but got: ${decoded.runtimeType}');
          }
          return PubPackageInfo.fromJson(decoded);
        }

        if (response.statusCode == 404) {
          throw GuardException(
            "Package '$packageName' not found on pub.dev",
            exitCode: ExitCodes.apiError,
          );
        }

        // Other HTTP status errors trigger retry
        throw HttpException(
          'HTTP status ${response.statusCode} calling pub.dev API for package $packageName',
        );
      } catch (e) {
        if (e is GuardException) {
          rethrow;
        }

        if (attempt >= maxRetries) {
          throw GuardException(
            "Failed to fetch package '$packageName' from pub.dev after $maxRetries attempts",
            exitCode: ExitCodes.apiError,
            details: e,
          );
        }

        // Exponential backoff: 500ms * 2^(attempt-1)
        final backoff = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future<void>.delayed(backoff);
      }
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _client.close();
  }
}
