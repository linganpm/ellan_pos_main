#!/usr/bin/env bash
# Open the Flutter POS app in Android Studio (Flutter + Android project).
#
# Open THIS folder in Studio: ellan-pos/ellan-pos-res-main
# (not the bare android/ subfolder — Studio needs pubspec.yaml for Flutter).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/ellan-pos-res-main"
CORE="$ROOT/pos-core-ib-main"

if [[ ! -d "$APP" ]]; then
  echo "error: Flutter app not found at $APP" >&2
  exit 1
fi

# Keep local path override for pos-core in this monorepo.
if [[ -d "$CORE" ]]; then
  cat > "$APP/pubspec_overrides.yaml" <<EOF
dependency_overrides:
  pos_orders_offline:
    path: ../pos-core-ib-main
EOF
fi

# Ensure Android platform files (gradlew, iml) exist.
if [[ ! -f "$APP/android/gradlew" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    (cd "$APP" && flutter create --platforms=android .)
  else
    echo "error: android/gradlew missing and flutter not on PATH" >&2
    exit 1
  fi
fi

# Refresh SDK paths in android/local.properties when flutter is available.
if command -v flutter >/dev/null 2>&1; then
  (cd "$APP" && flutter pub get >/dev/null)
fi

STUDIO_BIN=""
for candidate in \
  "${ANDROID_STUDIO:-}" \
  "$HOME/android-studio/bin/studio.sh" \
  "$HOME/android-studio/bin/studio" \
  /snap/bin/android-studio \
  /opt/android-studio/bin/studio.sh \
  "$(command -v studio 2>/dev/null || true)" \
  "$(command -v android-studio 2>/dev/null || true)"
do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    STUDIO_BIN="$candidate"
    break
  fi
done

if [[ -z "$STUDIO_BIN" ]]; then
  echo "error: Android Studio not found. Set ANDROID_STUDIO=/path/to/studio.sh" >&2
  exit 1
fi

echo "Opening Android Studio project:"
echo "  $APP"
echo "  (pos-core: $CORE)"
exec "$STUDIO_BIN" "$APP"
