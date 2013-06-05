#!/bin/bash

export WEBKITOUTPUTDIR="WebKitBuild/desktop"
WEBKIT_ROOT=$(pwd)
export QMAKEPATH=`pwd`"/Tools/qmake"

LUNA_STAGING=`pwd`"/../staging"
JOBS="-j 8"

echo " WEBKIT_ROOT=$WEBKIT_ROOT"
echo "   QMAKEPATH=$QMAKEPATH"
echo "LUNA_STAGING=$LUNA_STAGING"
echo "        JOBS=$JOBS"
#exit 0

export QTDIR=$LUNA_STAGING
export PATH=$LUNA_STAGING/bin:$PATH
###export WEBKIT_TESTFONTS=$HOME/work/goldfinger/project/upstream-webkit-build-bot/testfonts
###export TZ=America/Los_Angeles

mkdir -p $WEBKITOUTPUTDIR
cd $WEBKITOUTPUTDIR

QMAKE=$LUNA_STAGING/bin/qmake
$WEBKIT_ROOT/Tools/Scripts/build-webkit \
   --qmake=${QMAKE} \
   --qmakearg="QMAKE_CXXFLAGS+=-Wno-unused-variable" \
   --qmakearg="QMAKE_CXXFLAGS+=-Wno-ignored-qualifiers" \
   --qmakearg="QMAKE_CXXFLAGS+=-Wno-deprecated-declarations" \
   --qmakearg="QMAKE_LFLAGS+=-L$WEBKIT_ROOT/$WEBKITOUTPUTDIR/Release/lib" \
   --qmakearg="QMAKE_RPATHDIR+=$LUNA_STAGING/lib" \
   --qmakearg="QMAKE_RPATHDIR+=$LUNA_STAGING/usr/lib" \
   --qmakearg="WEBKIT_CONFIG-=palm_service_bridge" \
   --qmakearg="WEBKIT_CONFIG-=use_umediaserver" \
   --qmakearg="DEFINES+=WEBOS_DESKTOP" \
   --qmakearg="WEBKIT_CONFIG-=use_gstreamer"

   #--qmakearg="WEBKIT_CONFIG+=build_qttestsupport" \ [ $? -eq 0 ] || fail "Failed building Webkit"

make $JOBS 
# && cd $WEBKIT_ROOT/$WEBKITOUTPUTDIR/Release && make install
