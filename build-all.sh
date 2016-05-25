#!/bin/sh

#Options:
# MXE_PATH="..." (required): Path to MXE installation
# MKJOBS=X: Number of threads to build FFMPEG
# NO_UPLOAD=1: Do not upload build to the remote server.

#Build GPLv2 64bit DEBUG
env BUILD_DEBUG=1 NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BITS=64 sh build-ffmpeg.sh || exit 1

#Build GPLv2 64bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BITS=64 sh build-ffmpeg.sh || exit 1

#Build LGPL 64bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BITS=64 BUILD_LGPL=1 sh build-ffmpeg.sh  || exit 1

#Build GPLv2 32bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BITS=32 sh build-ffmpeg.sh  || exit 1

#Build LGPL 32bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BUILD_LGPL=1 BITS=32 sh build-ffmpeg.sh  || exit 1