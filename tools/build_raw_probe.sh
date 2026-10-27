#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output_dir="$script_dir/bin"
mkdir -p "$output_dir"
probe="$output_dir/camera41_raw_probe"
manifest="$output_dir/camera41_raw_probe_build.json"
target_arch="${CAMERA41_RAW_ARCHITECTURE:-}"
if [ -z "$target_arch" ]; then
  if [ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ]; then target_arch=arm64; else target_arch=x86_64; fi
fi
case "$target_arch" in arm64|x86_64) ;; *) echo "Unsupported RAW-reader architecture: $target_arch" >&2; exit 1;; esac

write_manifest() {
  expected_args="--expected-architecture $target_arch"
  if [ "${CAMERA41_RELEASE_BUILD:-0}" = "1" ]; then
    expected_args="--expected-architecture $target_arch --expected-libraw 0.22.1-Release"
  fi
  # expected_args contains only controlled literals defined above.
  python3 "$script_dir/verify_raw_probe_build.py" \
    --binary "$probe" --source "$script_dir/camera41_raw_probe.cpp" \
    --output "$manifest" $expected_args
  cp "$probe" "$output_dir/camera41_raw_probe_$target_arch"
  cp "$manifest" "$output_dir/camera41_raw_probe_build_$target_arch.json"
}

if [ -n "${CAMERA41_LIBRAW_SOURCE:-}" ] && \
    [ -f "$CAMERA41_LIBRAW_SOURCE/lib/libraw.a" ]; then
  /usr/bin/lipo -verify_arch "$target_arch" "$CAMERA41_LIBRAW_SOURCE/lib/libraw.a"
  /usr/bin/clang++ -arch "$target_arch" -std=c++17 -O2 -Wall -Wextra -pedantic \
    -DLIBRAW_NOTHREADS -I"$CAMERA41_LIBRAW_SOURCE" \
    "$script_dir/camera41_raw_probe.cpp" \
    "$CAMERA41_LIBRAW_SOURCE/lib/libraw.a" -lz \
    -o "$probe"
  write_manifest
  exit 0
fi

pkg_config=""
preferred_prefix=/usr/local
if [ "$target_arch" = arm64 ]; then preferred_prefix=/opt/homebrew; fi
for candidate in "$preferred_prefix/bin/pkg-config" /opt/homebrew/bin/pkg-config /usr/local/bin/pkg-config "$(command -v pkg-config || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ] && "$candidate" --exists libraw; then
    candidate_libraw=$("$candidate" --variable=libdir libraw)/libraw.dylib
    if /usr/bin/lipo -verify_arch "$target_arch" "$candidate_libraw" >/dev/null 2>&1; then
      pkg_config="$candidate"
      break
    fi
  fi
done
if [ -z "$pkg_config" ]; then
  echo "ERROR: pkg-config with a matching ${target_arch} LibRaw installation was not found." >&2
  echo "Checked /opt/homebrew/bin, /usr/local/bin and the current PATH." >&2
  exit 1
fi
libraw_binary=$($pkg_config --variable=libdir libraw)/libraw.dylib
if ! /usr/bin/lipo -verify_arch "$target_arch" "$libraw_binary"; then
  echo "ERROR: LibRaw does not contain $target_arch. Install a matching LibRaw build; native Apple Silicon commonly uses /opt/homebrew." >&2
  exit 1
fi
compiler="/usr/bin/clang++ -arch $target_arch"

# Homebrew's current LibRaw headers include omp.h.  Keep this explicit:
# pkg-config for libraw does not consistently propagate the libomp include
# directory across Homebrew releases.
omp_prefix=""
for candidate in /opt/homebrew/opt/libomp /usr/local/opt/libomp; do
  if [ -f "$candidate/include/omp.h" ] && [ -f "$candidate/lib/libomp.dylib" ] && /usr/bin/lipo -verify_arch "$target_arch" "$candidate/lib/libomp.dylib" 2>/dev/null; then
    omp_prefix="$candidate"
    break
  fi
done
if [ -z "$omp_prefix" ]; then
  echo "ERROR: LibRaw requires libomp on this macOS installation. Run: brew install libomp" >&2
  exit 1
fi

$compiler -std=c++17 -O2 -Wall -Wextra -pedantic \
  "$script_dir/camera41_raw_probe.cpp" \
  $($pkg_config --cflags --libs libraw) -I"$omp_prefix/include" -L"$omp_prefix/lib" -lomp \
  -o "$probe"

write_manifest
