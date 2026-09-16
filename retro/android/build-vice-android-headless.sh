#!/usr/bin/env bash
# Build VICE's headless (no GTK UI) static libraries for Android arm64-v8a.
#
# This script did not exist. The Android CMakeLists consumed an object tree
# produced by ~/AndroidStudioProjects/VICEAndroid/tools/build-vice-android-headless.sh,
# a path on one machine, in a project that is not this one and is no longer on
# disk. The consequence was that nobody could rebuild the Android core from
# this repository at all: CI shipped a prebuilt libvicecore.so committed to
# jniLibs and never regenerated it.
#
# It is the Linux headless build with the NDK's toolchain and a --host triple.
# Everything else -- the feature switches, the reasons for them -- is the same,
# and both scripts must keep the same switches or the two platforms ship
# different emulators.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VICE_SRC="${VICE_SRC:-$(cd "$HERE/../../vice" && pwd)}"
BUILD_DIR="${VICE_BUILD_DIR:-$VICE_SRC/build-android-arm64-headless}"

NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/28.2.13676358}}"
API="${ANDROID_API:-26}"
ABI_TRIPLE="${ABI_TRIPLE:-aarch64-linux-android}"
JOBS="${JOBS:-$(nproc)}"

[ -d "$NDK" ] || { echo "NDK not found at $NDK" >&2; exit 1; }
[ -f "$VICE_SRC/configure.ac" ] || { echo "VICE source not found at $VICE_SRC" >&2; exit 1; }

# A source checkout has no generated configure; a release tarball does.
if [ ! -x "$VICE_SRC/configure" ]; then
    echo "==> no generated configure; running autogen.sh"
    ( cd "$VICE_SRC" && ./autogen.sh )
fi

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TOOLCHAIN/bin/${ABI_TRIPLE}${API}-clang"
export CXX="$TOOLCHAIN/bin/${ABI_TRIPLE}${API}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
[ -x "$CC" ] || { echo "no compiler at $CC" >&2; exit 1; }

# -fPIC because these objects go into a shared library. A non-PIC object only
# fails at LINK time, naming an object file rather than a target.
export CFLAGS="${CFLAGS:--fPIC -O2 -DANDROID}"
export CXXFLAGS="${CXXFLAGS:--fPIC -O2 -DANDROID}"
export LDFLAGS="${LDFLAGS:-}"

# As in the Linux build: these are only needed to regenerate files a release
# already ships, and are not installed on every machine.
export DOS2UNIX="${DOS2UNIX:-true}"
export XA="${XA:-true}"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
if [ "${VICE_CLEAN:-0}" = "1" ] && [ -f Makefile ]; then
    make clean
fi

# --without-residfp matters and is not cosmetic. The engine is on by default in
# the source tree, off in the 3.10 release tarball this core was originally
# built from, and its archive is at src/lib/libresidfp/src/.libs -- a nested
# libtool path that is in neither CMakeLists' static-library list. Enabled, the
# vsid library fails to link on reSIDfp::WaveformGenerator and friends, and the
# main core links anyway with 22 undefined symbols that would only surface as a
# dlopen failure on a device. The shipping cores contain no reSIDfp at all.
"$VICE_SRC/configure" \
  --host="$ABI_TRIPLE" \
  --enable-headlessui \
  --disable-html-docs \
  --disable-pdf-docs \
  --disable-realdevice \
  --disable-rs232 \
  --disable-ipv6 \
  --disable-openmp \
  --disable-usbsid \
  --without-alsa \
  --without-pulse \
  --without-sdlsound \
  --without-portaudio \
  --without-png \
  --without-gif \
  --without-flac \
  --without-mpg123 \
  --without-vorbis \
  --without-lame \
  --without-libcurl \
  --with-resid \
  --with-fastsid \
  --without-residfp

make -j"$JOBS"

echo
echo "Built Android arm64 VICE headless object tree:"
file "$BUILD_DIR/src/x64sc" || true
