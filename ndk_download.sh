#!/usr/bin/env bash
set -euo pipefail

NDK_VER="${NDK_VER:-27.0.12077973}"

echo "==> Target NDK: $NDK_VER"

# 1) Cari Android SDK root
SDK="${ANDROID_SDK_ROOT:-}"
if [ -z "${SDK}" ]; then
  SDK="${ANDROID_HOME:-}"
fi
if [ -z "${SDK}" ]; then
  for d in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" "$HOME/Android/sdk" "/usr/local/android-sdk"; do
    if [ -d "$d" ]; then SDK="$d"; break; fi
  done
fi
if [ -z "${SDK}" ]; then
  echo "!! Gagal menemukan Android SDK. Set ANDROID_SDK_ROOT atau instal Android SDK + Command-line Tools dulu."
  exit 1
fi
echo "==> Android SDK: $SDK"

# 2) Pastikan sdkmanager ada
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  # Coba lokasi lama
  if [ -x "$SDK/tools/bin/sdkmanager" ]; then
    SDKMANAGER="$SDK/tools/bin/sdkmanager"
  else
    echo "!! sdkmanager tidak ditemukan."
    echo "   Instal Android SDK Command-line Tools (via Android Studio → SDK Manager → SDK Tools) lalu ulangi."
    exit 1
  fi
fi
echo "==> sdkmanager: $SDKMANAGER"

# 3) Install NDK 27 (idempotent)
yes | "$SDKMANAGER" --install "ndk;$NDK_VER"

NDK_PATH="$SDK/ndk/$NDK_VER"
if [ ! -d "$NDK_PATH" ]; then
  echo "!! NDK seharusnya terpasang tapi folder tidak ditemukan: $NDK_PATH"
  exit 1
fi
echo "==> NDK terpasang: $NDK_PATH"

# 4) Update local.properties (kalau ada folder android/)
if [ -d "./android" ]; then
  LP="./android/local.properties"
  touch "$LP"
  # Hapus baris ndk.dir lama, lalu tulis yang baru
  if grep -q '^ndk\.dir=' "$LP"; then
    sed -i.bak '/^ndk\.dir=/d' "$LP" || true
  fi
  # Escape slashes untuk macOS sed
  ESCAPED=$(printf '%s\n' "$NDK_PATH" | sed 's/[\/&]/\\&/g')
  echo "ndk.dir=$ESCAPED" >> "$LP"
  echo "==> local.properties diupdate: ndk.dir=$NDK_PATH"
fi

# 5) Info tambahan untuk CMake/Gradle
echo
echo "Selesai ✅"
echo "Tips:"
echo "- Di module-level build.gradle tambahkan:"
echo "  android {"
echo "      ndkVersion \"$NDK_VER\""
echo "  }"
echo "- Atau set di VS Code settings.json:"
echo "  \"cmake.androidNdkPath\": \"$NDK_PATH\""
