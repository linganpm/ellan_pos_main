import 'dart:async';
import 'dart:io';

import 'package:pos_tablet/core/constants/discovery_constants.dart';

/// Lightweight reachability probe for the configured POS gateway.
///
/// Uses a short-timeout HTTP HEAD against the bootstrap origin — no third-party
/// connectivity package required. Offline selling continues regardless.
class NetworkReachability {
  NetworkReachability._();

  static Future<bool> canReachGateway({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final bootstrap = Uri.parse(kDiscoveryUrl);
    final probe = bootstrap.replace(path: bootstrap.path, query: '');
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final request = await client.openUrl('HEAD', probe).timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      // Any HTTP response (even 404/405) means the host is reachable.
      await response.drain<void>();
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on HandshakeException {
      return false;
    } on HttpException {
      return false;
    } catch (_) {
      // Fallback: DNS lookup of host alone.
      try {
        final host = probe.host;
        if (host.isEmpty) return false;
        final addresses = await InternetAddress.lookup(host).timeout(timeout);
        return addresses.isNotEmpty;
      } catch (_) {
        return false;
      }
    } finally {
      client?.close(force: true);
    }
  }
}
