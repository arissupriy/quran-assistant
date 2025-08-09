#!/usr/bin/env bash
set -euo pipefail

# ==== KONFIGURASI UBAH SESUAI LOKAL ====
NDK_DIR="/home/arissupriy/Android/Sdk/ndk/29.0.13599879"
NINJA_BIN="/usr/bin/ninja"
PROJECT_DIR="/home/arissupriy/Projects/quran-assistant"

# ==== CEK PRASYARAT ====
[[ -d "$NDK_DIR" ]] || { echo "NDK not found at $NDK_DIR"; exit 1; }
[[ -x "$NINJA_BIN" ]] || { echo "ninja not found at $NINJA_BIN"; exit 1; }
command -v flutter >/dev/null || { echo "flutter not found in PATH"; exit 1; }
command -v rustup  >/dev/null || { echo "rustup not found in PATH"; exit 1; }

# ==== TARGET RUST ====
rustup target add aarch64-linux-android >/dev/null || true

# ==== PATH TOOLCHAIN ====
TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="$TOOLCHAIN/bin/clang"
CLANGXX="$TOOLCHAIN/bin/clang++"
AR="$TOOLCHAIN/bin/llvm-ar"

# ==== ENV NDK / CMAKE ====
export ANDROID_NDK="$NDK_DIR"
export ANDROID_NDK_HOME="$NDK_DIR"
export ANDROID_NDK_ROOT="$NDK_DIR"

export CMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
export CMAKE_GENERATOR="Ninja"
export CMAKE_MAKE_PROGRAM="$NINJA_BIN"

# Target ABI & API level
export ANDROID_ABI="arm64-v8a"
export ANDROID_PLATFORM="23"          # (bisa juga "android-23")

# Paksa CMake ke aarch64
export CMAKE_SYSTEM_NAME="Android"
export CMAKE_SYSTEM_PROCESSOR="aarch64"
export CMAKE_C_COMPILER="$CLANG"
export CMAKE_CXX_COMPILER="$CLANGXX"
export CMAKE_C_COMPILER_TARGET="aarch64-linux-android23"
export CMAKE_CXX_COMPILER_TARGET="aarch64-linux-android23"
export CMAKE_TRY_COMPILE_TARGET_TYPE="STATIC_LIBRARY"

# Bindgen header fix (set keduanya karena whisper-rs-sys ngecek 2 nama var)
SYSROOT="$TOOLCHAIN/sysroot"
CLANG_INC="$TOOLCHAIN/lib/clang/20/include"

export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$SYSROOT -I$CLANG_INC"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="$BINDGEN_EXTRA_CLANG_ARGS"
# export BINDGEN_EXTRA_CLANG_ARGS_aarch64-linux-android="$BINDGEN_EXTRA_CLANG_ARGS"

# Tambahan nice-to-have
export CC_aarch64_linux_android="$TOOLCHAIN/bin/aarch64-linux-android23-clang"
export CXX_aarch64_linux_android="$TOOLCHAIN/bin/aarch64-linux-android23-clang++"
export AR_aarch64_linux_android="$AR"

echo "== Env singkat =="
echo "NDK_DIR=$NDK_DIR"
echo "ABI=$ANDROID_ABI  API=$ANDROID_PLATFORM"
echo "CMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
echo "CMAKE_GENERATOR=$CMAKE_GENERATOR"
echo "CMAKE_TRY_COMPILE_TARGET_TYPE=$CMAKE_TRY_COMPILE_TARGET_TYPE"
echo

cd "$PROJECT_DIR"

# Opsional bersih-bersih kalau butuh
# flutter clean
# cargo clean -p rust_lib_quran_assistant || true

# Build!
flutter build apk --debug --no-tree-shake-icons --no-shrink
