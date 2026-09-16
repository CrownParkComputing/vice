#!/usr/bin/env bash
# Build VICE's headless (no GTK UI) object files and static libs for the
# native Linux x86_64 host.
#
# The VICE source is this repository's vice/ directory. It used to be a
# checkout somewhere in $HOME, which is why nothing could build this core on
# any other machine -- including CI, which shipped a prebuilt .so instead and
# never rebuilt it.
#
# Unlike a release tarball, a source checkout has no generated configure, so
# autogen.sh runs first if one is missing.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VICE_SRC="${VICE_SRC:-$(cd "$HERE/../../vice" && pwd)}"
BUILD_DIR="${VICE_BUILD_DIR:-$VICE_SRC/build-linux-x64-headless}"

if [ ! -f "$VICE_SRC/configure.ac" ]; then
  echo "VICE source not found at $VICE_SRC" >&2
  exit 1
fi
if [ ! -x "$VICE_SRC/configure" ]; then
  echo "==> no generated configure; running autogen.sh"
  ( cd "$VICE_SRC" && ./autogen.sh )
fi

mkdir -p "$BUILD_DIR"

export CC="${CC:-gcc}"
export CXX="${CXX:-g++}"
export CFLAGS="${CFLAGS:--fPIC -O2}"
export CXXFLAGS="${CXXFLAGS:--fPIC -O2}"
export LDFLAGS="${LDFLAGS:-}"
export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"

# As with the Android build, treat the release tarball's already-generated
# files as good enough; these external tools aren't needed for a headless
# build and may not be installed.
export DOS2UNIX="${DOS2UNIX:-true}"
export XA="${XA:-true}"

cd "$BUILD_DIR"
if [ "${VICE_CLEAN:-0}" = "1" ] && [ -f Makefile ]; then
  make clean
fi

"$VICE_SRC/configure" \
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

make -j"${JOBS:-$(nproc)}"

echo "Built Linux x64 VICE headless binaries:"
file "$BUILD_DIR/src/x64sc" || true
