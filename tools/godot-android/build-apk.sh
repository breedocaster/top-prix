#!/usr/bin/env bash
# Export a Godot project to an APK.
# Usage: build-apk.sh <project_dir> [debug|release] [out.apk] [preset_name]
#   debug   : signed with the shared debug keystore in this folder (same key every build, so updates
#             install over each other). Override with GODOT_ANDROID_KEYSTORE_DEBUG_PATH/_USER/_PASSWORD.
#   release : needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER (alias) and _PASSWORD (your upload key).
# Env: GODOT_VERSION (default: detected from the project's config/features), GA_HOME.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "${1:?project dir}" && pwd)"; MODE="${2:-debug}"; PRESET="${4:-Android}"
NAME="$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$PROJ/project.godot" | tr -cd '[:alnum:]')"
OUT="${3:-$PWD/${NAME:-game}-$MODE.apk}"
if [ -z "${GODOT_VERSION:-}" ]; then
  FEAT="$(sed -n 's/^config\/features=PackedStringArray("\([0-9.]*\)".*/\1/p' "$PROJ/project.godot")"
  case "$FEAT" in 4.7) GODOT_VERSION=4.7.2-stable;; 4.6) GODOT_VERSION=4.6.1-stable;; *) GODOT_VERSION=4.7.2-stable;; esac
fi
bash "$HERE/setup.sh" "$GODOT_VERSION" >/dev/null
GA_HOME="${GA_HOME:-$HOME/.cache/godot-android}"; source "$GA_HOME/env.sh"
rm -f "$XDG_CONFIG_HOME"/godot/editor_settings-*.tres     # pick up JAVA_HOME / ANDROID_HOME fresh
if [ "$MODE" = debug ]; then
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HERE/debug.keystore}"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
else
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set the release keystore path}" "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?set the key alias}" "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?set the keystore password}"
fi
mkdir -p "$(dirname "$OUT")"
"$GODOT_BIN" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path "$PROJ" "--export-$MODE" "$PRESET" "$OUT" 2>&1 | grep -E "ERROR|error:|Signed|Unable" | grep -v "connect to daemon" || true
[ -s "$OUT" ] || { echo "Export failed (no APK written)." >&2; exit 1; }
SIGNER="$(ls "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)"
"$SIGNER" verify "$OUT" >/dev/null 2>&1 || { echo "APK signature check failed." >&2; exit 1; }
echo "OK $OUT ($(du -h "$OUT" | cut -f1), $MODE, Godot $GODOT_VERSION)"
