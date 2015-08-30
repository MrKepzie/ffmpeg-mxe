#!/bin/sh

#Options:
# MXE_PATH="..." (required): Path to MXE installation
# MKJOBS=X: Number of threads to build FFMPEG
# NO_UPLOAD=1: Do not upload build to the remote server.

#Build GPLv2 64bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD sh build-ffmpeg.sh 64 || exit 1

#Build LGPL 64bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BUILD_LGPL=1 sh build-ffmpeg.sh 64  || exit 1

#Build GPLv2 32bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD sh build-ffmpeg.sh 32  || exit 1

#Build LGPL 32bit
env NO_MXE_PKG=1 MKJOBS=$MKJOBS MXE_PATH=$MXE_PATH NO_UPLOAD=$NO_UPLOAD BUILD_LGPL=1 sh build-ffmpeg.sh 32  || exit 1