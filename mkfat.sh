#!/bin/bash

set -x
set -e

BUILD_DIR=`pwd`
pushd `dirname $0`
SCRIPT_DIR=`pwd`
popd

BUILD_TARGET_ARCH=x86_64  $SCRIPT_DIR/buildjdk.sh
BUILD_TARGET_ARCH=aarch64 $SCRIPT_DIR/buildjdk.sh

JDK_DEST="$BUILD_DIR/fatjdk"
DSYM_DEST="$BUILD_DIR/fatdsym"
SRC1="$BUILD_DIR/jdk/build/macos-aarch64-server-fastdebug/images/jdk"
SRC2="$BUILD_DIR/jdk/build/macos-x86_64-server-fastdebug/images/jdk"

cp -r "$SRC1" "$JDK_DEST"
cd "$SRC1"
find . -type f -exec bash -c "file {} | grep -qc Mach-O" \; -print -exec lipo -create -output "$JDK_DEST/{}" "{}" "$SRC2/{}" \;

cd "$JDK_DEST"
find . -type d -name \*.dSYM -exec echo {} \; -exec mkdir -p $DSYM_DEST/{} \; -exec mv {} "$DSYM_DEST/{}/.." \; -prune

cd "$JDK_DEST"
zip -r "$JDK_DEST.zip" .

cd "$DSYM_DEST"
zip -r "$DSYM_DEST.zip" .

