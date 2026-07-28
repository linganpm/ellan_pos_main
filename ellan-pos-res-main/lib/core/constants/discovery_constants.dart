/// Default gateway used only when the operator has not saved a server yet.
const String kDefaultDiscoveryUrl = 'http://127.0.0.1:8000/api/pos/bootstrap';

String _runtimeDiscoveryUrl = kDefaultDiscoveryUrl;

/// Normalises operator input into the bootstrap endpoint the tablet calls.
///
/// Accepts:
/// - `http://host:8000`
/// - `http://host:8000/api/pos`
/// - `http://host:8000/api/pos/bootstrap`
String normalizeDiscoveryUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return kDefaultDiscoveryUrl;

  // Strip accidental trailing slashes before appending path segments.
  value = value.replaceAll(RegExp(r'/+$'), '');

  if (value.endsWith('/api/pos/bootstrap')) {
    return value;
  }
  if (value.endsWith('/api/pos')) {
    return '$value/bootstrap';
  }
  return '$value/api/pos/bootstrap';
}

/// Origin host the operator typed (no `/api/pos/...` suffix).
String discoveryOrigin(String discoveryOrBase) {
  final bootstrap = Uri.parse(normalizeDiscoveryUrl(discoveryOrBase));
  return bootstrap.replace(path: '', query: '').toString().replaceAll(RegExp(r'/+$'), '');
}

/// Activates [url] for every gateway call on this device for the rest of the
/// process lifetime. Persist the same value via [DeviceSetupStore] so cold
/// starts restore it.
void setActiveDiscoveryUrl(String url) {
  _runtimeDiscoveryUrl = normalizeDiscoveryUrl(url);
}

/// Restores the default compile-time gateway (e.g. after clearing setup).
void clearActiveDiscoveryUrl() {
  _runtimeDiscoveryUrl = kDefaultDiscoveryUrl;
}

/// Bootstrap URL currently in use. Prefer this over hardcoding a host.
String get kDiscoveryUrl => _runtimeDiscoveryUrl;

/// Device registration request — the tablet asks to join an organisation.
Uri get kDeviceRegistrationUrl =>
    Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/devices/register');

/// Approval gate — is this device registered, approved and active?
Uri get kDeviceStatusUrl =>
    Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/devices/status');
