# retro/ — the embedding layer

Crown Park Computing's. It turns VICE from an application into two shared
libraries with a plain C ABI, which a Flutter front end drives over `dart:ffi`:

- `libvicecore.so` — the C64 machine (x64sc).
- `libvicecore_vsid.so` — the standalone SID player.

| Path | What |
|---|---|
| `bridge/` | The C ABI (`vice_bridge.c`, `vice_vsid_bridge.c`) and the audio backends. |
| `linux/` | `build-vice-linux-headless.sh` builds VICE itself; `CMakeLists.txt` links the bridge on top. Tests and an SDL3 viewer alongside. |
| `android/` | `build-vice-android-headless.sh` then `build.sh`, same two steps for arm64-v8a. |
| `ios/` | Cross-build toolchain files. |

VICE itself is not patched: `--enable-headlessui` means no GTK, and everything
we add lives in this directory.

## Building

```sh
./retro/linux/build-vice-linux-headless.sh     # VICE static libs
cmake -S retro/linux -B build && cmake --build build
```

The VICE source is this repository's `vice/`. A source checkout has no
generated `configure`, so both build scripts run `autogen.sh` when one is
missing — a release tarball ships one, a checkout does not.

## --without-residfp is load-bearing

Both scripts pass it and both must keep passing it. reSIDfp is **on** by
default in the source tree and was **off** in the 3.10 release tarball this
core was first built from, so enabling it silently changes what ships. Its
archive sits at `src/lib/libresidfp/src/.libs/libresidfp.a`, a nested libtool
path that is in neither CMakeLists' static-library list, and the result is:

- `libvicecore_vsid.so` fails to link on `reSIDfp::WaveformGenerator` and friends;
- `libvicecore.so` links **anyway**, carrying 22 undefined symbols that would
  surface only as a `dlopen` failure on a device.

The cores that shipped contain no reSIDfp at all.

## The ABI gate

```sh
nm -D --defined-only libvicecore.so | grep ' T ' | grep -c '^vice_'
```

The two libraries together must export every `vice_*` symbol the front end
looks up — 32 of them at the time of writing. A missing one is a `dlopen` that
succeeds and a call that crashes.

## Who consumes this

- **Retro-C64** — the Android application.
- **Breadbin** — the iOS application.
