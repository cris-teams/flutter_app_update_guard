import 'dart:convert';

import 'package:flutter_app_update_guard/src/pub/pub_api_client.dart';
import 'package:flutter_app_update_guard/src/pub/pub_cache.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _sendHandler;

  MockHttpClient(this._sendHandler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _sendHandler(request);
  }
}

void main() {
  group('PubApiClient', () {
    test('fetches package info successfully', () async {
      final jsonResponse = {
        'name': 'dio',
        'latest': {
          'version': '5.7.0',
          'published': '2026-07-14T10:00:00Z',
          'pubspec': {
            'environment': {
              'sdk': '>=3.0.0 <4.0.0',
              'flutter': '>=3.10.0',
            },
            'repository': 'https://github.com/cfug/dio',
            'homepage': 'https://github.com/cfug/dio/tree/main/test',
          }
        },
        'isDiscontinued': false,
      };

      final mockHttp = MockHttpClient((request) async {
        expect(request.url.path, endsWith('/dio'));
        expect(request.headers['User-Agent'], contains('flutter_app_update_guard'));
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(jsonResponse))),
          200,
        );
      });

      final client = PubApiClient(client: mockHttp);
      final info = await client.getPackage('dio');

      expect(info.name, equals('dio'));
      expect(info.latestVersion.toString(), equals('5.7.0'));
      expect(info.dartSdkConstraint, equals('>=3.0.0 <4.0.0'));
      expect(info.flutterSdkConstraint, equals('>=3.10.0'));
      expect(info.isDiscontinued, isFalse);
      expect(info.repositoryUrl, equals('https://github.com/cfug/dio'));
    });

    test('throws GuardException on 404 package not found', () async {
      final mockHttp = MockHttpClient((request) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      final client = PubApiClient(client: mockHttp);
      expect(
        () => client.getPackage('nonexistent_package'),
        throwsException,
      );
    });

    test('retries on temporary failure and succeeds', () async {
      int calls = 0;
      final jsonResponse = <String, dynamic>{
        'name': 'dio',
        'latest': <String, dynamic>{
          'version': '5.7.0',
          'published': '2026-07-14T10:00:00Z',
          'pubspec': <String, dynamic>{}
        },
        'isDiscontinued': false,
      };

      final mockHttp = MockHttpClient((request) async {
        calls++;
        if (calls == 1) {
          return http.StreamedResponse(Stream.value([]), 503);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(jsonResponse))),
          200,
        );
      });

      final client = PubApiClient(client: mockHttp, maxRetries: 2);
      final info = await client.getPackage('dio');

      expect(info.name, equals('dio'));
      expect(calls, equals(2));
    });
  });

  group('CachedPubClient', () {
    test('calls delegate exactly once and caches subsequent calls', () async {
      int delegateCalls = 0;
      final mockInfo = <String, dynamic>{
        'name': 'dio',
        'latest': <String, dynamic>{
          'version': '5.7.0',
          'published': '2026-07-14T10:00:00Z',
          'pubspec': <String, dynamic>{}
        },
        'isDiscontinued': false,
      };

      final mockHttp = MockHttpClient((request) async {
        delegateCalls++;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(mockInfo))),
          200,
        );
      });

      final delegate = PubApiClient(client: mockHttp);
      final cachedClient = CachedPubClient(delegate);

      // Call 1
      final res1 = await cachedClient.getPackage('dio');
      expect(res1.name, equals('dio'));
      expect(delegateCalls, equals(1));

      // Call 2 (should be cached)
      final res2 = await cachedClient.getPackage('dio');
      expect(res2.name, equals('dio'));
      expect(delegateCalls, equals(1));
    });
  });
}
