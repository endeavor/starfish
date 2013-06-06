#!/bin/bash

if [ ! -d "WebKit" ]; then
   echo "Could not find WebKit directory"
   exit 1
fi

if [ ! -d "qtsdk/qtbase" ]; then
   echo "Could not find qtsdk/qtbase directory"
   exit 1
fi

export QTDIR=`pwd`"/qtsdk/qtbase"

cd WebKit
WEBKIT_ROOT=$(pwd)
export WEBKITOUTPUTDIR="WebKitBuild/desktop"
export QMAKEPATH=`pwd`"/Tools/qmake"
export PATH=$QTDIR/bin:$PATH

JOBS="-j 8"

echo " WEBKIT_ROOT=$WEBKIT_ROOT"
echo "   QMAKEPATH=$QMAKEPATH"
echo "       QTDIR=$QTDIR"
echo "        JOBS=$JOBS"
#exit 0

mkdir -p $WEBKITOUTPUTDIR
cd $WEBKITOUTPUTDIR

QMAKE=$QTDIR/bin/qmake
$WEBKIT_ROOT/Tools/Scripts/build-webkit \
   --qmake=${QMAKE} \
   --qmakearg="QMAKE_CXXFLAGS+=-Wno-unused-variable" \
   --qmakearg="QMAKE_CXXFLAGS+=-Wno-ignored-qualifiers" \
   --qmakearg="QMAKE_CXXFLAGS+=-Wno-deprecated-declarations" \
   --qmakearg="QMAKE_LFLAGS+=-L$WEBKIT_ROOT/$WEBKITOUTPUTDIR/Release/lib" \
   --qmakearg="QMAKE_RPATHDIR+=$QTDIR/lib" \
   --qmakearg="QMAKE_RPATHDIR+=$QTDIR/usr/lib" \
   --qmakearg="WEBKIT_CONFIG-=palm_service_bridge" \
   --qmakearg="WEBKIT_CONFIG-=use_umediaserver" \
   --qmakearg="DEFINES+=WEBOS_DESKTOP" \
   --qmakearg="WEBKIT_CONFIG-=use_gstreamer"
