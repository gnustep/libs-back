#!/bin/bash
#
# Cross-build everything libs-gui needs on Android, into $GS_PREFIX.
#
# This is libs-base's dependency script with the four image libraries AppKit
# uses added to it: libs-gui builds against libs-base, so both sets are needed.
#
# Every component is skipped if its output is already present, so a restored
# cache short-circuits the whole script.  Versions are pinned: a CI that
# follows upstream releases fails for reasons unrelated to libs-gui.
#
set -eu

: "${ANDROID_NDK_HOME:?}"
: "${GS_PREFIX:?}"
: "${GS_API:=31}"
: "${GS_ABI:=x86_64}"
: "${GS_TRIPLE:=x86_64-linux-android}"
GS_SRC="${GS_SRC:-$HOME/gs-src}"
GS_DISPATCH_PREFIX="${GS_DISPATCH_PREFIX:-$GS_PREFIX/../dispatch-prefix}"

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
CCPREFIX="$TOOLCHAIN/bin/${GS_TRIPLE}${GS_API}"
export PATH="$TOOLCHAIN/bin:$PATH"
mkdir -p "$GS_SRC" "$GS_PREFIX" "$GS_DISPATCH_PREFIX"
GS_DISPATCH_PREFIX=$(cd "$GS_DISPATCH_PREFIX" && pwd)

JOBS=$(nproc)
say() { echo "== $*"; }

# fetch <url> [mirror ...] -> echoes the extracted source directory.
#
# A download that fails must fail HERE, naming the URL.  Letting it fall through
# leaves tar reading a file that is not there and then ./configure missing,
# which reports as exit 127 and says nothing about the real cause.  Mirrors are
# tried in order: gmplib.org refuses connections from hosted runners often
# enough to break an otherwise good run.
fetch() {
  local f d url got
  f=$(basename "$1")
  cd "$GS_SRC"
  if [ ! -s "$f" ]; then
    got=""
    for url in "$@"; do
      if curl -fsSL --connect-timeout 30 --retry 3 --retry-delay 5 \
              -o "$f.part" "$url"; then
        mv "$f.part" "$f"; got=$url; break
      fi
      echo "   download failed, trying the next source: $url" >&2
      rm -f "$f.part"
    done
    [ -n "$got" ] || { echo "could not download $f from any source" >&2; return 1; }
  fi
  [ -s "$f" ] || { echo "$f downloaded empty" >&2; return 1; }
  case "$f" in
    *.tar.gz|*.tgz) d=$(tar tzf "$f" | head -1 | cut -d/ -f1) ;;
    *)              d=$(tar tf  "$f" | head -1 | cut -d/ -f1) ;;
  esac
  [ -n "$d" ] || { echo "$f is not readable as an archive" >&2; return 1; }
  [ -d "$d" ] || tar xf "$f"
  echo "$GS_SRC/$d"
}

# ---------------------------------------------------------------- libobjc2
if [ ! -f "$GS_PREFIX/lib/libobjc.so" ]; then
  say "libobjc2"
  [ -d "$GS_SRC/libobjc2" ] || git clone -q --depth 1 --recurse-submodules \
    https://github.com/gnustep/libobjc2.git "$GS_SRC/libobjc2"
  cmake -B "$GS_SRC/libobjc2/build" -S "$GS_SRC/libobjc2" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$GS_ABI" -DANDROID_PLATFORM="android-$GS_API" \
    -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$GS_PREFIX" \
    -DGNUSTEP_INSTALL_TYPE=NONE \
    -DTESTS=OFF -DCMAKE_FIND_USE_CMAKE_PATH=false \
    -DCMAKE_C_COMPILER="$CCPREFIX-clang" \
    -DCMAKE_CXX_COMPILER="$CCPREFIX-clang++" \
    -DCMAKE_OBJC_COMPILER="$CCPREFIX-clang" \
    -DCMAKE_OBJCXX_COMPILER="$CCPREFIX-clang++" >/dev/null
  cmake --build "$GS_SRC/libobjc2/build" -j "$JOBS" >/dev/null
  cmake --install "$GS_SRC/libobjc2/build" >/dev/null
fi

# ------------------------------------------------------------------ libffi
if [ ! -f "$GS_PREFIX/lib/libffi.a" ] && [ ! -f "$GS_PREFIX/lib64/libffi.a" ]; then
  say "libffi"
  d=$(fetch https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ----------------------------------------------------------------- libxml2
if [ ! -f "$GS_PREFIX/lib/libxml2.a" ]; then
  say "libxml2"
  d=$(fetch https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --without-python --without-icu --without-lzma --without-zlib \
    --disable-shared --enable-static --with-pic \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ---------------------------------------------------------------- libiconv
# bionic's iconv is in libc but thin: 16 encodings against glibc's 68.
if [ ! -f "$GS_PREFIX/lib/libiconv.so" ]; then
  say "GNU libiconv"
  d=$(fetch https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-pic CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# --------------------------------------------------------------------- ICU
# The cross build runs the host's own data tools, so a native build first.
if [ ! -f "$GS_PREFIX/lib/libicuuc.so" ]; then
  say "ICU (native, for the cross build's tools)"
  d=$(fetch https://github.com/unicode-org/icu/releases/download/release-74-2/icu4c-74_2-src.tgz)
  ICUSRC="$d/source"
  if [ ! -d "$GS_SRC/icu-native" ]; then
    mkdir -p "$GS_SRC/icu-native"
    cd "$GS_SRC/icu-native" && "$ICUSRC/runConfigureICU" Linux >/dev/null
    make -j"$JOBS" >/dev/null
  fi
  say "ICU (cross)"
  mkdir -p "$GS_SRC/icu-android"
  cd "$GS_SRC/icu-android"
  "$ICUSRC/configure" --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-cross-build="$GS_SRC/icu-native" \
    --disable-tests --disable-samples --disable-extras \
    CC="$CCPREFIX-clang" CXX="$CCPREFIX-clang++" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ----------------------------------------------------------------- libcurl
if [ ! -f "$GS_PREFIX/lib/libcurl.a" ]; then
  say "libcurl"
  d=$(fetch https://curl.se/download/curl-8.11.1.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-pic --disable-shared --enable-static \
    --without-ssl --without-libpsl --without-brotli --without-zstd \
    --without-nghttp2 --without-libidn2 --disable-ldap --disable-ldaps \
    CC="$CCPREFIX-clang" AR="$TOOLCHAIN/bin/llvm-ar" \
    RANLIB="$TOOLCHAIN/bin/llvm-ranlib" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ------------------------------------------------- shared flags from here on
export CFLAGS="-fPIC -O2"
export CPPFLAGS="-I$GS_PREFIX/include"
export LDFLAGS="-L$GS_PREFIX/lib"
export PKG_CONFIG_PATH="$GS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$GS_PREFIX/lib/pkgconfig"
export CC="$CCPREFIX-clang" CXX="$CCPREFIX-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
       NM="$TOOLCHAIN/bin/llvm-nm"

# ------------------------------------------------- GMP, nettle, tasn1, TLS
if [ ! -f "$GS_PREFIX/lib/libgmp.a" ]; then
  say "GMP"
  d=$(fetch https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz \
            https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi
if [ ! -f "$GS_PREFIX/lib/libhogweed.a" ]; then
  say "nettle"
  d=$(fetch https://ftp.gnu.org/gnu/nettle/nettle-3.10.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --disable-openssl --disable-documentation \
    --with-include-path="$GS_PREFIX/include" --with-lib-path="$GS_PREFIX/lib" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi
if [ ! -f "$GS_PREFIX/lib/libtasn1.a" ]; then
  say "libtasn1"
  d=$(fetch https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic --disable-doc >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi
if [ ! -f "$GS_PREFIX/lib/libgnutls.a" ]; then
  say "GnuTLS"
  d=$(fetch https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --with-included-unistring --without-p11-kit --without-idn \
    --without-tpm --without-tpm2 --disable-doc --disable-cxx \
    --disable-tests --disable-guile --disable-libdane --disable-nls \
    --with-default-trust-store-dir=/system/etc/security/cacerts/ >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ---------------------------------------------------------------- libxslt
if [ ! -f "$GS_PREFIX/lib/libxslt.a" ]; then
  say "libxslt"
  d=$(fetch https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.43.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-libxml-prefix="$GS_PREFIX" --without-python --without-crypto \
    --without-debug --disable-shared --enable-static --with-pic >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ======================= the image libraries AppKit uses =====================
# zlib comes from the NDK sysroot and is not built here.

# ------------------------------------------------------------------- libpng
if [ ! -f "$GS_PREFIX/lib/libpng16.a" ]; then
  say "libpng"
  d=$(fetch https://download.sourceforge.net/libpng/libpng-1.6.44.tar.gz \
            https://ftp-osl.osuosl.org/pub/libpng/src/libpng16/libpng-1.6.44.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ------------------------------------------------------------ libjpeg-turbo
# Built through its CMake path; the autotools path is not maintained upstream.
if [ ! -f "$GS_PREFIX/lib/libjpeg.a" ]; then
  say "libjpeg-turbo"
  d=$(fetch https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.4/libjpeg-turbo-3.0.4.tar.gz)
  cmake -B "$d/build" -S "$d" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$GS_ABI" -DANDROID_PLATFORM="android-$GS_API" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$GS_PREFIX" \
    -DENABLE_SHARED=FALSE -DENABLE_STATIC=TRUE \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON >/dev/null
  cmake --build "$d/build" -j "$JOBS" >/dev/null
  cmake --install "$d/build" >/dev/null
fi

# ------------------------------------------------------------------ libtiff
# NSBitmapImageRep reads TIFF, so this is not optional in practice.  webp,
# zstd and lzma are off: further cross builds for formats the tests do not
# exercise.
if [ ! -f "$GS_PREFIX/lib/libtiff.a" ]; then
  say "libtiff"
  d=$(fetch https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --disable-webp --disable-zstd --disable-lzma \
    --disable-tests --disable-tools --disable-docs >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ------------------------------------------------------------------ giflib
# No configure script upstream; drive the Makefile and install only the static
# library and its header.  The `all` target builds utilities needing a host
# compiler, which are not wanted here.
if [ ! -f "$GS_PREFIX/lib/libgif.a" ]; then
  say "giflib"
  d=$(fetch https://download.sourceforge.net/giflib/giflib-5.2.2.tar.gz)
  cd "$d"
  make -j"$JOBS" libgif.a CC="$CC" CFLAGS="$CFLAGS -std=gnu99" >/dev/null
  install -d "$GS_PREFIX/lib" "$GS_PREFIX/include"
  install -m 644 libgif.a "$GS_PREFIX/lib/libgif.a"
  install -m 644 gif_lib.h "$GS_PREFIX/include/gif_lib.h"
fi

# -------------------------------------------------------------- libdispatch
# Its own prefix: it installs a Block.h that collides with libobjc2's.
if [ ! -f "$GS_DISPATCH_PREFIX/lib/libdispatch.so" ]; then
  say "libdispatch"
  [ -d "$GS_SRC/libdispatch" ] || git clone -q --depth 1 \
    https://github.com/swiftlang/swift-corelibs-libdispatch.git "$GS_SRC/libdispatch"
  cmake -B "$GS_SRC/libdispatch/build" -S "$GS_SRC/libdispatch" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$GS_ABI" -DANDROID_PLATFORM="android-$GS_API" \
    -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$GS_DISPATCH_PREFIX" \
    -DBUILD_SHARED_LIBS=YES -DENABLE_SWIFT=NO -DBUILD_TESTING=NO \
    -DINSTALL_PRIVATE_HEADERS=YES -DCMAKE_FIND_USE_CMAKE_PATH=false >/dev/null
  cmake --build "$GS_SRC/libdispatch/build" -j "$JOBS" >/dev/null
  cmake --install "$GS_SRC/libdispatch/build" >/dev/null
  # It leaves _Block_copy and friends undefined but still links its own
  # BlocksRuntime, which duplicates libobjc2's.  Point it at libobjc2 instead.
  patchelf --replace-needed libBlocksRuntime.so libobjc.so \
    "$GS_DISPATCH_PREFIX/lib/libdispatch.so"
fi

# --------------------------------------------------------------------- zlib
# zlib comes from the NDK sysroot and is not cross-built, but the NDK ships no
# pkg-config file for it.  libpng16.pc says "Requires.private: zlib", so
# without this every "pkg-config --exists libpng16" fails and freetype reports
# "libpng support requested but library not found" while libpng16.a is present.
if [ ! -f "$GS_PREFIX/lib/pkgconfig/zlib.pc" ]; then
  say "zlib.pc for the NDK's zlib"
  SYSROOT="$TOOLCHAIN/sysroot"
  ZVER=$(sed -n 's/^#define ZLIB_VERSION "\([^"]*\)".*/\1/p' \
           "$SYSROOT/usr/include/zlib.h" | head -1)
  [ -n "$ZVER" ] || { echo "could not read ZLIB_VERSION from the NDK sysroot" >&2; exit 1; }
  mkdir -p "$GS_PREFIX/lib/pkgconfig"
  cat > "$GS_PREFIX/lib/pkgconfig/zlib.pc" <<EOF
prefix=$SYSROOT/usr
includedir=\${prefix}/include
libdir=\${prefix}/lib/$GS_TRIPLE/$GS_API

Name: zlib
Description: zlib compression library, from the Android NDK sysroot
Version: $ZVER
Libs: -lz
Cflags: -I\${includedir}
EOF
fi

# -------------------------------------------------------------------- expat
if [ ! -f "$GS_PREFIX/lib/libexpat.a" ]; then
  say "expat"
  d=$(fetch https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --without-docbook --without-examples --without-tests \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ----------------------------------------------------------------- freetype
# png is taken from the cross prefix on purpose: FT_Open_Face on an embedded
# PNG bitmap is compiled out otherwise.  harfbuzz would drag in a C++ cross
# build for no benefit here, and brotli only decodes WOFF2.
if [ ! -f "$GS_PREFIX/lib/libfreetype.a" ]; then
  say "freetype"
  d=$(fetch https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --with-zlib=yes --with-png=yes \
    --with-harfbuzz=no --with-brotli=no --with-bzip2=no \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# --------------------------------------------------------------- fontconfig
# --disable-cache-build: the install hook runs the freshly built fc-cache,
# which is a TARGET binary here.  The config and cache directories compiled in
# are the DEVICE's, so the install tries to create /data on the build host and
# dies AFTER installing the library, leaving no fontconfig.pc; DESTDIR puts
# that directory inside a staging tree instead.  The guard is on the .pc for
# the same reason.
if [ ! -f "$GS_PREFIX/lib/pkgconfig/fontconfig.pc" ]; then
  say "fontconfig"
  command -v gperf >/dev/null || { echo "gperf is required by fontconfig's configure" >&2; exit 1; }
  d=$(fetch https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz)
  cd "$d"
  [ -f config.status ] || ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --disable-docs --disable-cache-build --disable-nls \
    --with-expat="$GS_PREFIX" \
    --with-default-fonts=/system/fonts \
    --with-cache-dir=/data/local/tests/fontconfig/cache \
    --with-baseconfigdir=/data/local/tests/fontconfig \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null
  rm -rf "$GS_SRC/fc-stage"
  make install DESTDIR="$GS_SRC/fc-stage" >/dev/null
  cp -a "$GS_SRC/fc-stage$GS_PREFIX/." "$GS_PREFIX/"
  [ -f "$GS_PREFIX/lib/pkgconfig/fontconfig.pc" ] \
    || { echo "fontconfig installed no fontconfig.pc" >&2; exit 1; }
fi

# ------------------------------------------------------------------- pixman
# 0.42.2 still ships autotools; 0.44 is meson-only.
if [ ! -f "$GS_PREFIX/lib/libpixman-1.a" ]; then
  say "pixman"
  d=$(fetch https://www.x.org/releases/individual/lib/pixman-0.42.2.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --disable-gtk --disable-libpng \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# -------------------------------------------------------------------- cairo
# cairo 1.18.2 is meson-only; the last autotools cairo is 1.16.0, from 2018.
# Every window-system backend is off: this build rasterises into an image
# surface, and xlib or xcb would look for X headers Android does not have.
# --wrap-mode=nofallback stops meson quietly building a bundled copy of a
# dependency it cannot find.
if [ ! -f "$GS_PREFIX/lib/libcairo.a" ]; then
  say "cairo"
  command -v meson >/dev/null || { echo "meson is required to build cairo" >&2; exit 1; }
  # meson does not expand environment variables inside a cross file, so it is
  # written here with the paths already substituted.  -lexpat is needed because
  # fontconfig is static and meson resolves it with the non-static pkg-config
  # line, which omits Libs.private; cairo's script utilities fail without it.
  cat > "$GS_SRC/android.cross" <<EOF
[binaries]
c = '$CCPREFIX-clang'
cpp = '$CCPREFIX-clang++'
ar = '$TOOLCHAIN/bin/llvm-ar'
strip = '$TOOLCHAIN/bin/llvm-strip'
pkg-config = 'pkg-config'

[built-in options]
c_args = ['-fPIC', '-O2', '-I$GS_PREFIX/include']
c_link_args = ['-L$GS_PREFIX/lib', '-lexpat']

[properties]
pkg_config_libdir = '$GS_PREFIX/lib/pkgconfig'
needs_exe_wrapper = true

[host_machine]
system = 'android'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
  d=$(fetch https://www.cairographics.org/releases/cairo-1.18.2.tar.xz)
  cd "$d"
  rm -rf build-android
  meson setup build-android \
    --cross-file "$GS_SRC/android.cross" \
    --prefix="$GS_PREFIX" \
    --default-library=static \
    --wrap-mode=nofallback \
    -Dxlib=disabled -Dxcb=disabled -Dquartz=disabled -Dtee=disabled \
    -Dglib=disabled -Dspectre=disabled -Dsymbol-lookup=disabled \
    -Dgtk_doc=false -Dtests=disabled \
    -Dfreetype=enabled -Dfontconfig=enabled -Dpng=enabled -Dzlib=enabled \
    >/dev/null
  ninja -C build-android >/dev/null
  ninja -C build-android install >/dev/null
fi

# The cairo font path is not optional: CairoFaceInfo.m calls
# cairo_ft_font_face_create_for_pattern, so a cairo built without FT_FONT
# compiles the whole font layer out and the backend draws no text at all.
for f in CAIRO_HAS_FT_FONT CAIRO_HAS_FC_FONT CAIRO_HAS_PNG_FUNCTIONS CAIRO_HAS_IMAGE_SURFACE; do
  grep -q "^#define $f 1" "$GS_PREFIX/include/cairo/cairo-features.h" \
    || { echo "$f is not set; the cairo build is not usable"; exit 1; }
done
say "cairo features checked"

say "dependency prefix ready"
ls "$GS_PREFIX/lib" | sed 's/^/    /'
