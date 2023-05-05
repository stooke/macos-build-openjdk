#! /bin/bash

set -x
set -e

JDK_VER=17
BUILD_JDKS=false
BUILD_DIR=`pwd`
pushd `dirname $0`
SCRIPT_DIR=`pwd`
popd
BUILD_SCRIPT="$SCRIPT_DIR/build${JDK_VER}.sh"
JDK_DIR="$BUILD_DIR/jdk${JDK_VER}u-dev"
SRC1="$JDK_DIR/build/macos-aarch64-server-fastdebug/images/jdk"
SRC2="$JDK_DIR/build/macos-x86_64-server-fastdebug/images/jdk"


if [ ! -d "$SRC2" ] ; then
    BUILD_TARGET_ARCH=x86_64  "$BUILD_SCRIPT"
fi

if [ ! -d "$SRC1" ] ; then
    BUILD_TARGET_ARCH=aarch64 "$BUILD_SCRIPT"
fi

FAT_JDK_DEST="$BUILD_DIR/fatjdk"
FAT_DSYM_DEST="$BUILD_DIR/fatdsym"

rm -fr "$FAT_JDK_DEST"
cp -r "$SRC1" "$FAT_JDK_DEST"
cd "$FAT_JDK_DEST"
find . -type f -exec bash -c "file {} | grep -qc Mach-O" \; -print -exec rm -f "$FAT_JDK_DEST/{}" \; -exec lipo -create -output "$FAT_JDK_DEST/{}" "$SRC1/{}" "$SRC2/{}" \;

cd "$FAT_JDK_DEST"
find . -type d -name \*.dSYM -exec echo {} \; -exec mkdir -p $FAT_DSYM_DEST/{} \; -exec mv {} "$FAT_DSYM_DEST/{}/.." \; -prune

cd "$FAT_JDK_DEST"
zip -r "$FAT_JDK_DEST.zip" .

cd "$FAT_DSYM_DEST"
zip -r "$FAT_DSYM_DEST.zip" .



