import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _fallbackServerOrigin = 'http://127.0.0.1:8000';
const String _fallbackRootOrgInstanceId = 'eln-org';

String _envServerOrigin = _fallbackServerOrigin;
String _envRootOrgInstanceId = _fallbackRootOrgInstanceId;
bool _hasEnvServerOrigin = false;
bool _hasEnvRootOrgInstanceId = false;

/// Bundled env asset to read; `--dart-define=POS_ENV_FILE=.env.development`
/// selects another one (see run.sh).
const String _posEnvFile = String.fromEnvironment(
  'POS_ENV_FILE',
  defaultValue: '.env',
);

/// Loads `POS_SERVER_URL` and `POS_ROOT_ORG_INSTANCE_ID` from [_posEnvFile].
Future<void> loadPosDiscoveryEnv() async {
  var loadedPrimaryEnv = false;
  try {
    await dotenv.load(fileName: _posEnvFile);
    loadedPrimaryEnv = true;
  } catch (e) {
    debugPrint('POS env: $_posEnvFile not loaded ($e); trying .env.example');
    try {
      await dotenv.load(fileName: '.env.example');
    } catch (e2) {
      debugPrint(
        'POS env: .env.example not loaded ($e2); using built-in defaults',
      );
    }
  }

  if (dotenv.isInitialized) {
    final server = (dotenv.env['POS_SERVER_URL'] ?? '').trim();
    final rootOrg = (dotenv.env['POS_ROOT_ORG_INSTANCE_ID'] ?? '').trim();
    if (server.isNotEmpty) {
      _envServerOrigin = discoveryOrigin(server);
      _hasEnvServerOrigin = loadedPrimaryEnv;
    }
    if (rootOrg.isNotEmpty) {
      _envRootOrgInstanceId = rootOrg;
      _hasEnvRootOrgInstanceId = loadedPrimaryEnv;
    }
  }

  setActiveDiscoveryUrl(_envServerOrigin);
}

/// Base server origin shown on the welcome / signup screens (host + optional port).
String get kDefaultServerOrigin => _envServerOrigin;

/// Default parent / root organisation identifier for company signup.
String get kDefaultRootOrgInstanceId => _envRootOrgInstanceId;

/// Whether both discovery values were explicitly supplied by the bundled
/// `.env`. When true, setup screens must use them without exposing editable
/// server or parent-organisation fields.
bool get kIsPosDiscoveryConfiguredByEnv =>
    _hasEnvServerOrigin && _hasEnvRootOrgInstanceId;

/// Default bootstrap endpoint used only when the operator has not saved a server yet.
String get kDefaultDiscoveryUrl => '$_envServerOrigin/api/pos/bootstrap';

String? _runtimeDiscoveryUrl;

/// Normalises operator input into the bootstrap endpoint the tablet calls.
///
/// Accepts:
/// - `http://host:8000`
/// - `http://host:8000/api/pos`
/// - `http://host:8000/api/pos/bootstrap`
///
/// The welcome field should only hold the origin (e.g. localhost with port);
/// `/api/pos/...` is appended here for network calls, never shown in that field.
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
  final raw = discoveryOrBase.trim();
  if (raw.isEmpty) return _fallbackServerOrigin;
  try {
    final uri = Uri.parse(raw);
    if (uri.hasScheme && uri.host.isNotEmpty) {
      return uri
          .replace(path: '', query: '')
          .toString()
          .replaceAll(RegExp(r'/+$'), '');
    }
  } catch (_) {
    // Fall through to normalize-based stripping.
  }
  final bootstrap = Uri.parse(normalizeDiscoveryUrl(raw));
  return bootstrap
      .replace(path: '', query: '')
      .toString()
      .replaceAll(RegExp(r'/+$'), '');
}

/// Activates [url] for every gateway call on this device for the rest of the
/// process lifetime. Persist the same value via [DeviceSetupStore] so cold
/// starts restore it.
void setActiveDiscoveryUrl(String url) {
  _runtimeDiscoveryUrl = normalizeDiscoveryUrl(url);
}

/// Restores the default env / compile-time gateway (e.g. after clearing setup).
void clearActiveDiscoveryUrl() {
  _runtimeDiscoveryUrl = kDefaultDiscoveryUrl;
}

/// Bootstrap URL currently in use. Prefer this over hardcoding a host.
String get kDiscoveryUrl =>
    _runtimeDiscoveryUrl ?? normalizeDiscoveryUrl(kDefaultServerOrigin);

/// Device registration request — the tablet asks to join an organisation.
Uri get kDeviceRegistrationUrl =>
    Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/devices/register');

/// Approval gate — is this device registered, approved and active?
Uri get kDeviceStatusUrl =>
    Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/devices/status');
