#!/bin/sh
# Written by Alexandre Gauthier-Foichat alexandre.gauthier-foichat@inria.fe
# 
#Options:
# NO_MXE_PKG=1: Do not check if required MXE dependencies are installed for a faster build
# MXE_PATH="..." (required): Path to MXE installation
# MKJOBS=X: Number of threads to build FFMPEG
#Usage:
# sh build-ffmpeg.sh <BIT>
# BIT=32 or 64

THIRD_PARTY_SRC_URL=http://downloads.natron.fr/Third_Party_Sources
GSM_TAR=gsm-1.0.13.tar.gz
WAVEPACK_TAR=wavpack-4.75.0.tar.bz2
FFMPEG_TAR=ffmpeg-2.7.2.tar.bz2

if [ "$1" == "32" ]; then
	ARCH=i686
	TARGET=i686-w64-mingw32.static
else
	ARCH=x86_64
	TARGET=x86_64-w64-mingw32.static
fi

if [ -z "$MXE_PATH" ]; then
	echo "You must set MXE_PATH to point to the mxe directory."
	exit 1
fi

if [ -z "$MKJOBS" ]; then
	MKJOBS=8
fi

echo "Using $MKJOBS threads..."

CWD=$(pwd)

INSTALL_PATH="$MXE_PATH/usr/$TARGET"
CROSS_PREFIX="${TARGET}-"
PATCHES_DIR="$CWD/patches"

PATH=$MXE_PATH/usr/bin:$INSTALL_PATH/bin:$PATH
LD_LIBRARY_PATH=$INSTALL_PATH/lib:$LD_LIBRARY_PATH

SRC_PATH=$CWD/src
TMP_PATH=$CWD/tmp


rm -rf $TMP_PATH
mkdir -p $SRC_PATH 
mkdir -p $TMP_PATH 

if [ ! -f "${INSTALL_PATH}/lib/libgsm.a" ]; then 
	cd $TMP_PATH || exit 1
	if [ ! -f $SRC_PATH/$GSM_TAR ]; then
		wget $THIRD_PARTY_SRC_URL/$GSM_TAR -O $SRC_PATH/$GSM_TAR || exit 1
	fi
	tar xvf $SRC_PATH/$GSM_TAR || exit 1
	cd gsm* || exit 1
	GSM_PATCHES=$PATCHES_DIR/gsm
	patch -p1 -i ${GSM_PATCHES}/0001-adapt-makefile-to.mingw.patch || exit 1
    patch -p1 -i ${GSM_PATCHES}/0002-adapt-config-h-to.mingw.patch || exit 1
    patch -p1 -i ${GSM_PATCHES}/0003-fix-ln.mingw.patch || exit 1
	make CC=${CROSS_PREFIX}gcc CXX=${CROSS_PREFIX}g++ AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib STRIP=${CROSS_PREFIX}strip LD=${CROSS_PREFIX}gcc AS=${CROSS_PREFIX}as NM=${CROSS_PREFIX}nm DLLTOOL==${CROSS_PREFIX}dlltool OBJDUMP=${CROSS_PREFIX}objdump RESCOMP=${CROSS_PREFIX}windres -j${MKJOBS} || exit 1
	make INSTALL_ROOT=${INSTALL_PATH} install || exit 1
fi

if [ ! -f "${INSTALL_PATH}/lib/libwavpack.a" ]; then
	cd $TMP_PATH || exit 1
	if [ ! -f $SRC_PATH/$WAVEPACK_TAR ]; then
		wget $THIRD_PARTY_SRC_URL/$WAVEPACK_TAR -O $SRC_PATH/$WAVEPACK_TAR || exit 1
	fi
	tar xvf $SRC_PATH/$WAVEPACK_TAR || exit 1
	cd wavpack* || exit 1
	
  	./configure \
    --prefix=${INSTALL_PATH} \
    --host=${TARGET} \
    --disable-shared \
    --enable-static || exit 1
	make -j${MKJOBS} || exit 1
  	make  install || exit 1
fi

cd $MXE_PATH || exit 1
if [ "$NO_MXE_PKG" != "1" ]; then
make vorbis
make x264
make xvidcore
fi

cd $TMP_PATH || exit 1
if [ ! -f $SRC_PATH/$FFMPEG_TAR ]; then
	wget $THIRD_PARTY_SRC_URL/$FFMPEG_TAR -O $SRC_PATH/$FFMPEG_TAR || exit 1
fi
tar xvf $SRC_PATH/$FFMPEG_TAR || exit 1
cd ffmpeg-2* || exit 1


# These configure options make tons of undefined reference if enabled	
# --enable-libopus \
#	--enable-libass \
#	--enable-libfreetype \
#	--enable-fontconfig \
#	--enable-libfribidi \
	
 #Compile GPL-v2 version of ffmpeg
./configure \
	--cross-prefix="$CROSS_PREFIX" \
	--enable-cross-compile \
	--arch=$ARCH \
	--target-os=mingw32 \
	--prefix="${INSTALL_PATH}" \
	--disable-static --enable-shared \
	--yasmexe="${CROSS_PREFIX}yasm" \
	--disable-debug \
    --enable-memalign-hack \
    --disable-doc \
    --extra-libs='-mconsole' \
    --disable-pthreads \
    --enable-w32threads \
    --disable-sdl  \
    --enable-avresample \
    --enable-swresample \
    --enable-gpl \
	--enable-postproc \
	--enable-libx264 \
	--enable-libxvid \
	--enable-libtheora \
	--enable-libvorbis \
	--enable-libvpx \
	--enable-libmp3lame \
	--enable-libopenjpeg \
	--enable-libschroedinger \
	--enable-libspeex \
	--enable-libmodplug \
	--enable-libgsm \
    --enable-libwavpack \
	--enable-lzma \
	--enable-zlib \
    --enable-pic \
    --enable-runtime-cpudetect || exit 1
make -j${MKJOBS} || exit 1
make install || exit 1