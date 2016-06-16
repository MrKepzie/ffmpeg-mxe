#!/bin/sh
# Written by Alexandre Gauthier-Foichat alexandre.gauthier-foichat@inria.fe
# 
#Options:
# BITS={32,64}
# BUILD_DEBUG=1: Builds a debug version of ffmpeg
# NO_MXE_PKG=1: Do not check if required MXE dependencies are installed for a faster build
# MXE_PATH="..." (required): Path to MXE installation
# MKJOBS=X: Number of threads to build FFMPEG
# BUILD_LGPL=1: Build a LGPL version of ffmpeg instead of the GPLv2 version
# NO_TAR=1: Do not create an archive with the build directory
# NO_UPLOAD=1: Do not upload build to the remote server.
# NO_BUILD=1: Do not build ffmpeg and pick the one on the target system instead. WARNING: This is dangerous since the license of the ffmpeg installed on the system is probably not the same as the license selected. Use this at your own risks.
#Usage:
# sh BITS=64 MXE_PATH=... build-ffmpeg.sh

if [ ! -f "local.sh" ]; then
    echo "Please create a local.sh file defining REMOTE_USER, REMOTE_HOST, REMOTE_HOST_PATH, THIRD_PARTY_SRC_URL"
    exit 1
fi
source `pwd`/local.sh || exit 1


#-----------Dependencies version------------------
GSM_TAR=gsm-1.0.13.tar.gz
WAVEPACK_TAR=wavpack-4.75.0.tar.bz2
#-------------------------------------------------

#-----------FFMPEG version------------------------
FFMPEG_TAR=ffmpeg-3.0.2.tar.xz
#-------------------------------------------------

REQUIRED_FILES="$FFMPEG_TAR $GSM_TAR $WAVEPACK_TAR"

FFMPEG_BASE_NAME=$(echo $FFMPEG_TAR | sed 's/.tar.bz2//;s/.tar.gz//;s/.tar.xz//')

if [ -z "$NO_UPLOAD" ]; then
    if [ -z "$REMOTE_USER" ]; then
        echo "You must set REMOTE_USER to the user on the server that will be used to upload the build."
        exit 1
    fi

    if [ -z "$REMOTE_HOST" ]; then
        echo "You must set REMOTE_HOST to the server address to which to upload the build."
        exit 1
    fi

    if [ -z "$REMOTE_HOST_PATH" ]; then
        echo "You must set REMOTE_HOST_PATH to the path on the server where to upload the build."
        exit 1
    fi

    if [ -z "$THIRD_PARTY_SRC_URL" ]; then
        echo "Please set THIRD_PARTY_SRC_URL to the location of the tarballs of the sources for the required libs. This location should contain the following files:"

        exit 1
    fi
fi

if [ "$BITS" == "32" ]; then
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


OUTPUT_NAME="${FFMPEG_BASE_NAME}-windows-${ARCH}-shared"
if [ ! -z "$BUILD_LGPL" ]; then
    OUTPUT_NAME_LICENSED="${OUTPUT_NAME}-LGPL"
else
    OUTPUT_NAME_LICENSED="${OUTPUT_NAME}-GPLv2"
fi

if [ "$BUILD_DEBUG" = "1" ]; then
    OUTPUT_NAME_LICENSED="$OUTPUT_NAME_LICENSED"-debug
fi

echo "Building ${OUTPUT_NAME_LICENSED} using $MKJOBS threads..."

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

# These configure options make tons of undefined reference if enabled
# --enable-libopus \
#	--enable-libass \
#	--enable-libfreetype \
#	--enable-fontconfig \
#	--enable-libfribidi \

CONF_OPTIONS_COMMON="--cross-prefix=$CROSS_PREFIX --enable-cross-compile --arch=$ARCH --target-os=mingw32 --prefix=${INSTALL_PATH} --disable-static --enable-shared --yasmexe=${CROSS_PREFIX}yasm --enable-memalign-hack --disable-doc --extra-libs=-mconsole --disable-pthreads --enable-w32threads --disable-sdl --enable-avresample --enable-swresample --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libmp3lame --enable-libopenjpeg --disable-libschroedinger --enable-libspeex --disable-libmodplug --enable-libgsm --enable-libwavpack --enable-lzma --enable-zlib --enable-pic --enable-runtime-cpudetect"

CONF_OPTIONS_GPLV2="--enable-gpl --enable-postproc --enable-libx264 --enable-libxvid"

if [ "$BUILD_DEBUG" = "1" ]; then
    CONF_OPTIONS_DEBUG="--enable-debug"
else
    CONF_OPTIONS_DEBUG="--disable-debug"
fi

if [ ! -z "$NO_BUILD" ]; then
    #Check that ffmpeg on the target system has the same license as the one requested
    HAS_GPL=$(strings ${INSTALL_PATH}/bin/ffmpeg.exe | grep "under the terms of the GNU General Public License")
    HAS_LGPL=$(strings ${INSTALL_PATH}/bin/ffmpeg.exe | grep "under the terms of the GNU Lesser General Public")
    if [ ! -z "$BUILD_LGPL" ] && [ ! -z "$HAS_GPL" ]; then
        echo "Installed FFmpeg version is GPLv2 but you requested a LGPL one."
        exit 1
    elif [ -z "$BUILD_LGPL" ] && [ ! -z "$HAS_LGPL" ]; then
        echo "Installed FFmpeg version is LGPL but you requested a GPLv2 one."
        exit 1
    fi
fi

if [ -z "$NO_BUILD" ]; then

    if [ ! -f $SRC_PATH/$FFMPEG_TAR ]; then
        wget $THIRD_PARTY_SRC_URL/$FFMPEG_TAR -O $SRC_PATH/$FFMPEG_TAR || exit 1
    fi
    tar xf $SRC_PATH/$FFMPEG_TAR || exit 1
    cd ffmpeg-* || exit 1


#    patch -p0< $CWD/patches/ffmpeg-configure.diff || exit 1
#    patch -p1< $CWD/patches/libopenjpegdec.c.patch || exit 1
#    patch -p1< $CWD/patches/libopenjpegenc.c.patch || exit 1

    if [ -z "$BUILD_LGPL" ]; then
        CONF_OPTIONS_COMMON="${CONF_OPTIONS_DEBUG} ${CONF_OPTIONS_COMMON} ${CONF_OPTIONS_GPLV2}"
    fi

    echo
    echo "Configure options:"
    echo "$CONF_OPTIONS_COMMON"
    ./configure ${CONF_OPTIONS_COMMON} || exit 1

    make -j${MKJOBS} || exit 1
    make install || exit 1
    cd $TMP_PATH || exit 1
# NO_BUILD
fi

if [ ! -z "$BUILD_LGPL" ]; then
    echo "FFMPEG build licensed under LGPL." > README.txt
else
    echo "FFMPEG build licensed under GPLv2." > README.txt
fi
echo "---------------configured with:----------------" >> README.txt
echo "$CONF_OPTIONS_COMMON" >> README.txt

rm -rf $TMP_PATH/$OUTPUT_NAME_LICENSED
mkdir $TMP_PATH/$OUTPUT_NAME_LICENSED || exit 1
mv README.txt $TMP_PATH/$OUTPUT_NAME_LICENSED
mkdir -p $TMP_PATH/$OUTPUT_NAME_LICENSED/bin  || exit 1
mkdir -p $TMP_PATH/$OUTPUT_NAME_LICENSED/lib  || exit 1
mkdir -p $TMP_PATH/$OUTPUT_NAME_LICENSED/lib/pkgconfig  || exit 1
mkdir -p $TMP_PATH/$OUTPUT_NAME_LICENSED/include || exit 1
cp ${INSTALL_PATH}/bin/ff*.exe $TMP_PATH/$OUTPUT_NAME_LICENSED/bin || exit 1
cp ${INSTALL_PATH}/lib/pkgconfig/{libav*.pc,libsw*.pc,libpostproc*.pc}  $TMP_PATH/$OUTPUT_NAME_LICENSED/lib/pkgconfig || exit 1
cp ${INSTALL_PATH}/lib/{libav*.dll.a,libsw*.dll.a,libpostproc*.dll.a} $TMP_PATH/$OUTPUT_NAME_LICENSED/lib || exit
cp ${INSTALL_PATH}/bin/{av*.dll,sw*.dll,postproc*.dll} $TMP_PATH/$OUTPUT_NAME_LICENSED/bin || exit 1
cp ${INSTALL_PATH}/bin/{av*.lib,sw*.lib,postproc*.lib} $TMP_PATH/$OUTPUT_NAME_LICENSED/bin || exit 1
cp -r ${INSTALL_PATH}/include/{libav*,libsw*,libpostproc*} $TMP_PATH/$OUTPUT_NAME_LICENSED/include || exit 1

#Check that the build has the correct license
HAS_GPL=$(strings $TMP_PATH/${OUTPUT_NAME_LICENSED}/bin/ffmpeg.exe | grep "under the terms of the GNU General Public License")
HAS_LGPL=$(strings $TMP_PATH/${OUTPUT_NAME_LICENSED}/bin/ffmpeg.exe | grep "under the terms of the GNU Lesser General Public")
if [ ! -z "$BUILD_LGPL" ] && [ ! -z "$HAS_GPL" ]; then
    echo "Error: built FFmpeg version is GPLv2 but you requested a LGPL one."
    echo "Removing build files..."
    rm -rf $TMP_PATH
    exit 1
elif [ -z "$BUILD_LGPL" ] && [ ! -z "$HAS_LGPL" ]; then
    echo "Error: build FFmpeg version is LGPL but you requested a GPLv2 one."
    echo "Removing build files..."
    rm -rf $TMP_PATH
    exit 1
fi

if [ -z "$NO_TAR" ]; then
    cd $TMP_PATH || exit 1
    echo "Creating ${OUTPUT_NAME_LICENSED}.tar.xz ..."
    tar cJf ${OUTPUT_NAME_LICENSED}.tar.xz $OUTPUT_NAME_LICENSED || exit 1
    mv ${OUTPUT_NAME_LICENSED}.tar.xz $CWD || exit 1
    echo "Done."
fi

cd $CWD || exit 1

if [ -z "$NO_UPLOAD" ]; then
    echo "Uploading to $REMOTE_HOST..."
    rsync -avz --progress -e ssh ${OUTPUT_NAME_LICENSED}.tar.xz ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOST_PATH}
    echo "Done."
fi

echo "Build of ${OUTPUT_NAME_LICENSED} eone."

