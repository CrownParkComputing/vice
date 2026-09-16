#!/usr/bin/env bash
# Cross-compiles libvicecore.so / libvicecore_vsid.so for arm64-v8a using the
# NDK's CMake toolchain file.
#
# It needs an Android VICE object tree first: run build-vice-android-headless.sh
# beside this script. Output lands in retro/android/prebuilt/arm64-v8a unless
# JNI_LIBS_DIR points somewhere else, which is how a consuming application asks
# for it in its own jniLibs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/28.2.13676358}}"
API="${ANDROID_API:-26}"
BUILD_DIR="${BUILD_DIR:-$HERE/build}"
JNI_LIBS_DIR="${JNI_LIBS_DIR:-$HERE/prebuilt/arm64-v8a}"

if [ ! -f "$NDK/build/cmake/android.toolchain.cmake" ]; then
  echo "NDK toolchain file not found under $NDK" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# VICE_SRC and VICE_BUILD_DIR are documented as overrides, so they have to
# reach CMake -- setting them in the environment alone did nothing, and the
# failure was CMake reporting the DEFAULT path as missing while the caller was
# looking at the one they had just built.
VICE_ARGS=()
[ -n "${VICE_SRC:-}" ]       && VICE_ARGS+=(-DVICE_SRC="$VICE_SRC")
[ -n "${VICE_BUILD_DIR:-}" ] && VICE_ARGS+=(-DVICE_BUILD_DIR="$VICE_BUILD_DIR")

cmake \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM="android-${API}" \
  -DCMAKE_BUILD_TYPE=Release \
  "${VICE_ARGS[@]}" \
  "$HERE"

cmake --build . -j"${JOBS:-4}"

mkdir -p "$JNI_LIBS_DIR"
cp -v "$BUILD_DIR/libvicecore.so" "$JNI_LIBS_DIR/"
if [ -f "$BUILD_DIR/libvicecore_vsid.so" ]; then
  cp -v "$BUILD_DIR/libvicecore_vsid.so" "$JNI_LIBS_DIR/"
fi

echo "Done. Libraries in $JNI_LIBS_DIR:"
ls -la "$JNI_LIBS_DIR"
