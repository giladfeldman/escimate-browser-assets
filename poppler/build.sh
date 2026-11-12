#!/bin/bash
# Build Debian's poppler 25.03.0-5+deb13u4 (pdftotext, pdftoppm) to WebAssembly.
# Run in emscripten/emsdk:4.0.9 with this folder mounted at /src (patch_jpeg.py beside it).
# Output: /src/out2/{pdftotext,pdftoppm}.{js,wasm}. Sources: Debian's orig + debian
# tarballs (all Debian patches applied), plus freetype, zlib, libjpeg-turbo, lcms2 and
# openjpeg, linked statically.
set -euxo pipefail
cd /src
J=$(nproc)
apt-get update -qq && apt-get install -y -qq xz-utils patch pkg-config >/dev/null
if [ ! -d freetype-2.13.3 ]; then
  curl -sL https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz | tar xJ
fi
if [ ! -d poppler-25.03.0 ]; then
  curl -sL http://deb.debian.org/debian/pool/main/p/poppler/poppler_25.03.0.orig.tar.xz | tar xJ
  curl -sL http://deb.debian.org/debian/pool/main/p/poppler/poppler_25.03.0-5+deb13u4.debian.tar.xz | tar xJ -C poppler-25.03.0
  cd poppler-25.03.0
  while read -r p; do
    case "$p" in ''|'#'*) continue;; esac
    patch -p1 < "debian/patches/$p"
  done < debian/patches/series
  cd ..
fi
PREFIX=/src/prefix
python3 /src/patch_jpeg.py
if [ ! -d zlib-1.3.1 ]; then curl -sL https://zlib.net/fossils/zlib-1.3.1.tar.gz | tar xz; fi
if [ ! -f $PREFIX/lib/libz.a ]; then (cd zlib-1.3.1 && emconfigure ./configure --static --prefix=$PREFIX && emmake make -j$J install); fi
if [ ! -d libjpeg-turbo-2.1.5 ]; then curl -sL https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/2.1.5.tar.gz | tar xz; fi
if [ ! -f $PREFIX/lib/libjpeg.a ]; then mkdir -p jpg-build && (cd jpg-build && emcmake cmake ../libjpeg-turbo-2.1.5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_INSTALL_LIBDIR=lib -DENABLE_SHARED=OFF -DWITH_SIMD=0 -DWITH_TURBOJPEG=OFF && emmake make -j$J install); fi
mkdir -p $PREFIX/lib; [ -f $PREFIX/lib/libjpeg.a ] || cp jpg-build/libjpeg.a $PREFIX/lib/
if [ ! -d lcms2-2.16 ]; then curl -sL https://github.com/mm2/Little-CMS/releases/download/lcms2.16/lcms2-2.16.tar.gz | tar xz; fi
if [ ! -f $PREFIX/lib/liblcms2.a ]; then (cd lcms2-2.16 && emconfigure ./configure --prefix=$PREFIX --disable-shared --enable-static && emmake make -j$J install); fi
if [ ! -d openjpeg-2.5.3 ]; then curl -sL https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.3.tar.gz | tar xz; fi
if [ ! -f $PREFIX/lib/libopenjp2.a ]; then mkdir -p ojp-build && (cd ojp-build && emcmake cmake ../openjpeg-2.5.3 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF && emmake make -j$J install); fi
mkdir -p ft-build && cd ft-build
emcmake cmake ../freetype-2.13.3 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_ZLIB=ON
[ -f $PREFIX/lib/libfreetype.a ] || emmake make -j$J install
cd ..
rm -rf pop-build; mkdir -p pop-build && cd pop-build
emcmake cmake ../poppler-25.03.0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_PREFIX_PATH=$PREFIX -DZLIB_LIBRARY=$PREFIX/lib/libz.a -DZLIB_INCLUDE_DIR=$PREFIX/include -DFREETYPE_INCLUDE_DIRS=$PREFIX/include/freetype2 -DFREETYPE_LIBRARY=$PREFIX/lib/libfreetype.a \
  -DBUILD_SHARED_LIBS=OFF -DENABLE_UTILS=ON -DENABLE_CPP=OFF -DENABLE_GLIB=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF \
  -DENABLE_BOOST=OFF -DENABLE_LIBOPENJPEG=openjpeg2 -DENABLE_DCTDECODER=libjpeg -DENABLE_LCMS=ON -DJPEG_LIBRARY=$PREFIX/lib/libjpeg.a -DJPEG_LIBRARY_RELEASE=$PREFIX/lib/libjpeg.a -DHAVE_JPEG_MEM_SRC=1 -DJPEG_INCLUDE_DIR=$PREFIX/include -DLCMS2_LIBRARIES=$PREFIX/lib/liblcms2.a -DLCMS2_INCLUDE_DIR=$PREFIX/include -DOpenJPEG_DIR=$PREFIX/lib/cmake/openjpeg-2.5 -DENABLE_LIBCURL=OFF \
  -DENABLE_NSS3=OFF -DENABLE_GPGME=OFF -DENABLE_LIBTIFF=OFF -DWITH_PNG=OFF -DWITH_TIFF=OFF -DWITH_JPEG=ON -DWITH_Cairo=OFF \
  -DENABLE_ZLIB_UNCOMPRESS=OFF -DFONT_CONFIGURATION=generic -DBUILD_GTK_TESTS=OFF -DBUILD_QT5_TESTS=OFF -DBUILD_QT6_TESTS=OFF \
  -DBUILD_CPP_TESTS=OFF -DBUILD_MANUAL_TESTS=OFF -DENABLE_GOBJECT_INTROSPECTION=OFF -DRUN_GPERF_IF_PRESENT=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-sALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=4GB -sNODERAWFS=0 -sEXIT_RUNTIME=1 -sINVOKE_RUN=0 -sMODULARIZE=1 -sEXPORT_NAME=createPoppler -sEXPORTED_RUNTIME_METHODS=FS,callMain,HEAPU8 -sENVIRONMENT=web,node -sFORCE_FILESYSTEM=1 -sWASM_ASYNC_COMPILATION=0"
emmake make -j$J pdftotext pdftoppm
ls -la utils/pdftotext* utils/pdftoppm*
mkdir -p /src/out2 && cp utils/pdftotext.js utils/pdftotext.wasm utils/pdftoppm.js utils/pdftoppm.wasm /src/out2/
