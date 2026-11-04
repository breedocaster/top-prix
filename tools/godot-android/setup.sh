#!/usr/bin/env bash
# Install everything needed to export Godot projects to Android APKs, without Android Studio:
#   - official Godot editor (headless-capable) for GODOT_VERSION
#   - Android export templates (only the 2 APK templates are range-downloaded from the 1.3 GB .tpz)
#   - JDK 17 + apksigner + adb (apt), or the runner's Android SDK when ANDROID_HOME already has them
# Idempotent; everything lands in $GA_HOME (default ~/.cache/godot-android).
# Usage: setup.sh [godot_version]      e.g. setup.sh 4.7.2-stable   (default: $GODOT_VERSION or 4.7.2-stable)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER="${1:-${GODOT_VERSION:-4.7.2-stable}}"
GA_HOME="${GA_HOME:-$HOME/.cache/godot-android}"
TPL_DIR="$GA_HOME/data/godot/export_templates/${VER/-/.}"
BIN="$GA_HOME/godot-$VER"
REL="https://github.com/godotengine/godot/releases/download/$VER"
mkdir -p "$GA_HOME" "$TPL_DIR"

# 1) Java + signing tools
if ! command -v keytool >/dev/null || { [ -z "${ANDROID_HOME:-}" ] && ! command -v apksigner >/dev/null; }; then
  if command -v apt-get >/dev/null; then
    SUDO=""; [ "$(id -u)" != 0 ] && SUDO="sudo"
    $SUDO apt-get update -qq
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openjdk-17-jdk-headless apksigner adb unzip >/dev/null
  else
    echo "Install JDK 17, apksigner and adb, then re-run." >&2; exit 1
  fi
fi
JAVA_HOME="${JAVA_HOME_17_X64:-${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v keytool)")")")}}"

# 2) Godot editor
if [ ! -x "$BIN" ]; then
  echo "Downloading Godot $VER editor..."
  curl -fsSL -o "$GA_HOME/godot.zip" "$REL/Godot_v${VER}_linux.x86_64.zip"
  unzip -o -q "$GA_HOME/godot.zip" -d "$GA_HOME/godot-unzip"
  mv "$GA_HOME/godot-unzip/Godot_v${VER}_linux.x86_64" "$BIN"; chmod +x "$BIN"
  rm -rf "$GA_HOME/godot.zip" "$GA_HOME/godot-unzip"
fi

# 3) Android export templates (debug + release APK templates only)
if [ ! -f "$TPL_DIR/android_release.apk" ]; then
  echo "Fetching Android export templates..."
  python3 "$HERE/remote_zip.py" "$REL/Godot_v${VER}_export_templates.tpz" "$TPL_DIR" android_debug.apk android_release.apk version.txt
fi

# 4) Android SDK: use a real one if present, else a minimal layout Godot accepts (platform-tools/adb + build-tools/*/apksigner)
SDK="${ANDROID_HOME:-}"
if [ -z "$SDK" ] || ! ls "$SDK"/build-tools/*/apksigner >/dev/null 2>&1 || [ ! -e "$SDK/platform-tools/adb" ]; then
  SDK="$GA_HOME/sdk"
  mkdir -p "$SDK/platform-tools" "$SDK/build-tools/34.0.0"
  ln -sf "$(command -v adb)" "$SDK/platform-tools/adb"
  ln -sf "$(command -v apksigner)" "$SDK/build-tools/34.0.0/apksigner"
fi

cat > "$GA_HOME/env.sh" <<ENV
export GODOT_BIN="$BIN"
export JAVA_HOME="$JAVA_HOME"
export ANDROID_HOME="$SDK"
export XDG_DATA_HOME="$GA_HOME/data"
export XDG_CONFIG_HOME="$GA_HOME/config"
ENV
echo "Ready: Godot $VER, templates in $TPL_DIR, SDK $SDK  (source $GA_HOME/env.sh)"
