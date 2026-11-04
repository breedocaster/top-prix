# godot-android: APKs from any Godot project, anywhere

Builds Android APKs with the **official Godot editor in headless mode**, without Android Studio or Gradle. It works the same in three places:

- a Claude session,
- any Linux box (Ubuntu/Debian; other distros need JDK 17, `apksigner` and `adb` installed first),
- GitHub Actions.

```bash
tools/godot-android/build-apk.sh <project_dir> [debug|release] [out.apk] [preset]
tools/godot-android/build-apk.sh godot                  # -> ./TopPrix-debug.apk
```

`setup.sh` runs automatically on first use and caches everything in `~/.cache/godot-android` (override with `GA_HOME`):

- **Godot editor:** the version matches the project's `config/features`, or set `GODOT_VERSION=4.7.2-stable`.
- **Android export templates:** only the two APK templates are range-downloaded out of the 1.3 GB `.tpz` (`remote_zip.py`).
- **JDK 17, `apksigner`, `adb`:** installed from apt. If `ANDROID_HOME` already has `build-tools/*/apksigner` and `platform-tools/adb`, as GitHub runners do, that SDK is used instead.

A cold start takes about 20 s here. After that a build is just Godot's export time.

## Signing

- **debug:** signed with `debug.keystore` from this folder (alias `androiddebugkey`, password `android`). The same key signs every build on every machine, so a new APK installs as an update. The key is public on purpose and is only for testing. Override it with `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `_USER` and `_PASSWORD`.
- **release:** set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` (key alias) and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` to your **upload key**. Never commit that key. In CI, store it as repo secrets:
  - `ANDROID_KEYSTORE_B64` (`base64 -w0 upload.keystore`)
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`

Godot reads these variables in `platform/android/export/export_plugin.h`.

## Project requirements

- An Android export preset (`export_presets.cfg`) with `gradle_build/use_gradle_build=false`.
- `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`.
- Plain data files such as `*.json` need `include_filter`, because Godot only exports imported resources by default.
- For LAN games, enable the `internet`, `access_network_state`, `access_wifi_state` and `change_wifi_multicast_state` permissions.

## CI

`.github/workflows/godot-android.yml` builds APKs:

- on pushes to `main`,
- on `v*` tags (APKs are attached to the release),
- on demand from the Actions tab.

Other repos can call the same workflow as a reusable workflow; the snippet is at the top of the file.
