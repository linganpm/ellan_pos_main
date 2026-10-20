import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_tablet/core/company_profile_sync.dart';

void main() {
  late Map<String, dynamic> profile;
  Map<String, String>? synced;

  CompanyProfileSync sync(MockClient client) => CompanyProfileSync(
    loadProfile: () async => Map<String, dynamic>.from(profile),
    markSynced: (fields) async {
      synced = fields;
      profile = {...profile, ...fields, 'profile_pending_sync': 0};
    },
    client: client,
  );

  Future<bool> push(MockClient client, {String? token = 'tok'}) =>
      sync(client).push(
        origin: 'http://gateway.test',
        token: token,
        refs: const {'orgId': '287', 'storeId': '289'},
      );

  setUp(() {
    synced = null;
    profile = {
      'storeName': 'Tea Hut',
      'contactEmail': 'tea@example.com',
      'phone': '9000000001',
      'address': 'Main road',
      'registration_number': 'REG-1',
      'tax_number': 'GST-1',
      'identifier': 'TH',
      'profile_pending_sync': 1,
    };
  });

  test('nothing pending makes no request', () async {
    profile['profile_pending_sync'] = 0;
    final client = MockClient((_) async => fail('should not post'));
    expect(await push(client), isTrue);
  });

  test('offline keeps the edit queued', () async {
    final client = MockClient(
      (_) async => throw const SocketException('Failed host lookup'),
    );
    expect(await push(client), isFalse);
    expect(synced, isNull);
  });

  test('no access token keeps the edit queued without a request', () async {
    final client = MockClient((_) async => fail('should not post'));
    expect(await push(client, token: null), isFalse);
  });

  test('proxy HTML error page is treated as offline', () async {
    final client = MockClient((_) async => http.Response('<html>', 502));
    expect(await push(client), isFalse);
    expect(synced, isNull);
  });

  test('accepted push sends local fields and clears the pending flag', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.headers['Authorization'], 'Bearer tok');
      expect(request.url.path, '/api/pos/store/profile');
      return http.Response(
        jsonEncode({
          'store': {'store_name': 'Tea Hut Ltd', 'phone': '9000000001'},
        }),
        200,
      );
    });
    expect(await push(client), isTrue);
    expect(sent['store_name'], 'Tea Hut');
    expect(sent['tax_number'], 'GST-1');
    expect(sent['storeId'], '289');
    expect(synced!['storeName'], 'Tea Hut Ltd');
    expect(synced!['address'], 'Main road');
  });

  test('gateway rejection surfaces its message and keeps the edit', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'message': 'Invalid email'}), 400),
    );
    await expectLater(
      push(client),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'Invalid email'),
      ),
    );
    expect(synced, isNull);
  });

  test('an edit saved while the push was in flight stays pending', () async {
    final client = MockClient((_) async {
      profile = {...profile, 'phone': '9111111111'};
      return http.Response(jsonEncode({'store': {}}), 200);
    });
    expect(await push(client), isTrue);
    expect(synced, isNull);
    expect(profile['profile_pending_sync'], 1);
  });
}
