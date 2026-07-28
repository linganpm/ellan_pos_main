#!/usr/bin/env bash
# Run the POS tablet Flutter app from the ellan-pos monorepo root.
#
# Layout:
#   ellan-pos/                 ← this repo
#     run.sh                   ← you are here
#     ellan-pos-res-main/      ← Flutter tablet app
#     pos-core-ib-main/        ← local pos_orders_offline package
#
# Usage:
#   ./run.sh              # web browser at http://127.0.0.1:8080 (default)
#   ./run.sh web          # same as default
#   ./run.sh linux        # Linux desktop (needs working OpenGL/GPU drivers)
#   ./run.sh android      # Android emulator/device (default: Pixel_Tablet)
#   ./run.sh android Pixel_7
#   ./run.sh studio       # open Android Studio on the Flutter app
#   ./run.sh web 9090     # custom web port
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/ellan-pos-res-main"
CORE="$ROOT/pos-core-ib-main"

TARGET="${1:-web}"
PORT="${2:-8080}"
HOST="${WEB_HOST:-127.0.0.1}"

if [[ ! -d "$APP" ]]; then
  echo "error: Flutter app not found at $APP" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found on PATH" >&2
  exit 1
fi

cd "$APP"

# Prefer the sibling pos-core package in this monorepo.
if [[ -d "$CORE" ]]; then
  cat > pubspec_overrides.yaml <<EOF
dependency_overrides:
  pos_orders_offline:
    path: ../pos-core-ib-main
EOF
elif [[ ! -f pubspec_overrides.yaml ]]; then
  echo "warning: pos-core-ib-main missing; using pubspec.yaml dependency only" >&2
fi

flutter pub get

case "$TARGET" in
  web|browser)
    [[ -d web ]] || flutter create --platforms=web .
    echo "Serving POS at http://${HOST}:${PORT}"
    echo "  app:  $APP"
    echo "  core: $CORE"
    exec flutter run -d web-server --web-hostname "$HOST" --web-port "$PORT"
    ;;
  linux|desktop)
    [[ -d linux ]] || flutter create --platforms=linux .
    # Stale CMakeCache from a moved checkout breaks Linux builds.
    cmake_cache="$APP/build/linux/x64/debug/CMakeCache.txt"
    if [[ -f "$cmake_cache" ]]; then
      cached_home=$(awk -F= '/^CMAKE_HOME_DIRECTORY:INTERNAL=/{print $2; exit}' "$cmake_cache" || true)
      if [[ -n "${cached_home:-}" && "$cached_home" != "$APP" ]]; then
        echo "Clearing stale Linux CMake cache (was: $cached_home)"
        rm -rf "$APP/build/linux"
      fi
    fi
    # Optional software-GL fallback: FORCE_SOFTWARE_GL=1 ./run.sh linux
    if [[ "${FORCE_SOFTWARE_GL:-0}" == "1" ]]; then
      export LIBGL_ALWAYS_SOFTWARE=1
      export __GLX_VENDOR_LIBRARY_NAME=mesa
      if [[ -f /usr/share/glvnd/egl_vendor.d/50_mesa.json ]]; then
        export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
      fi
      echo "Using Mesa software GL fallback..."
    fi
    echo "Launching POS on Linux desktop..."
    echo "  app:  $APP"
    echo "  core: $CORE"
    exec flutter run -d linux
    ;;
  android|emulator)
    [[ -f android/gradlew ]] || flutter create --platforms=android .
    AVD="${2:-Pixel_Tablet}"
    # If no Android device is connected, launch the preferred emulator.
    if ! flutter devices --machine 2>/dev/null | grep -q '"platformType":"android"'; then
      echo "No Android device found — launching emulator: $AVD"
      flutter emulators --launch "$AVD" || true
      for _ in $(seq 1 60); do
        if flutter devices --machine 2>/dev/null | grep -q '"platformType":"android"'; then
          break
        fi
        sleep 2
      done
    fi
    echo "Launching POS on Android..."
    echo "  app:  $APP"
    echo "  core: $CORE"
    exec flutter run -d android
    ;;
  studio|android-studio)
    exec "$ROOT/open-studio.sh"
    ;;
  *)
    echo "Usage: $0 [web|linux|android|studio] [port|avd]" >&2
    exit 1
    ;;
esac
