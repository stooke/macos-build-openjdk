#!/bin/bash

# define JDK and repo
JDK_BASE=jdk

# set true to build Shanendoah, false for normal build
BUILD_SHENANDOAH=true

# set true to build javaFX, false for no javaFX
BUILD_JAVAFX=false

## release, fastdebug, slowdebug
DEBUG_LEVEL=fastdebug

### no need to change anything below this line unless something went wrong

set -e
set -x
# define build environment
BUILD_DIR=`pwd`
pushd `dirname $0`
SCRIPT_DIR=`pwd`
PATCH_DIR="$SCRIPT_DIR/jdk11u-patch"
TOOL_DIR="$BUILD_DIR/tools"
popd
JDK_DIR="$BUILD_DIR/$JDK_BASE"
JDK_CONF=macosx-x86_64-server-$DEBUG_LEVEL
JDK_REPO=http://github.com/openjdk/jdk

if $BUILD_JAVAFX ; then
  JAVAFX_REPO=http://hg.openjdk.java.net/openjfx/jfx-dev/rt
  JAVAFX_BUILD_DIR="$BUILD_DIR/jfx"
fi

### JDK

clone_jdk() {
	if ! test -d "$JDK_DIR" ; then
		git clone $JDK_REPO "$JDK_DIR"
	else
		pushd "$JDK_DIR"
		git pull 
		popd
	fi
}

patch_jdk() {
	if test -f "$PATCH_DIR/mac-jdk14.patch" ; then
		pushd "$JDK_DIR"
		git apply "$PATCH_DIR/mac-jdk14.patch"
		popd
	fi
}

configure_jdk() {
	pushd "$JDK_DIR"
	if $BUILD_JAVAFX ; then
		CONFIG_ARGS=--with-import-modules=$JAVAFX_BUILD_DIR/build/modular-sdk
	fi 
	chmod 755 ./configure
	./configure --with-toolchain-type=clang \
            --includedir=$XCODE_DEVELOPER_PREFIX/Toolchains/XcodeDefault.xctoolchain/usr/include \
            --with-debug-level=$DEBUG_LEVEL \
            --with-conf-name=$JDK_CONF \
            --with-jtreg="$TOOL_DIR/jtreg" \
            --with-boot-jdk=$JAVA_HOME $CONFIG_ARGS
	popd
}

clean_jdk() {
	rm -fr "$JDK_DIR/build"
	find "$JDK_DIR" -name \*.rej  -exec rm {} \; 2>/dev/null || true 
	find "$JDK_DIR" -name \*.orig -exec rm {} \; 2>/dev/null || true
}

revert_jdk() {
	pushd "$JDK_DIR"
	git restore -- .
	popd
}

build_jdk() {
	pushd "$JDK_DIR"
	IMAGES="bootcycle-images legacy-images"
	make $IMAGES CONF=$JDK_CONF
	popd
}

test_jdk() {
	TESTS=$*
	JDK_HOME="$JDK_DIR/build/$JDK_CONF/images/jdk"
	JT_WORK="$BUILD_DIR/jtreg"
	pushd "$JDK_DIR"
	jtreg -w "$JT_WORK/work" -r "$JT_WORK/report" -jdk:$JDK_HOME $TESTS
	popd
}

test_gtest() {
	TESTS=$*
	JDK_HOME="$JDK_DIR/build/$JDK_CONF/images/jdk"
	pushd "$JDK_DIR"
	make test-hotspot-gtest
	popd
}

#### Java FX

clone_javafx() {
  if [ ! -d $JAVAFX_BUILD_DIR ] ; then
    cd `dirname $JAVAFX_BUILD_DIR`
    hg clone $JAVAFX_REPO "$JAVAFX_BUILD_DIR"
  fi
  chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
}

patch_javafx() {
	pushd "$JAVAFX_BUILD_DIR"
	if [ -f "$SCRIPT_DIR/javafx11.patch" ] ; then
		hg import -f --no-commit "$SCRIPT_DIR/javafx11.patch"
	fi
	chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
	popd
}

revert_javafx() {
	pushd "$JAVAFX_BUILD_DIR"
	hg revert .
	popd
}

test_javafx() {
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew --info cleanTest :base:test
}

build_javafx() {
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew
}

build_javafx_demos() {
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew :apps:build
}

clean_javafx() {
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew clean
    rm -fr build
}

#### build the world

if $BUILD_JAVAFX ; then
	JAVAFX_TOOLS="ant cmake mvn" 
else
	unset JAVAFX_TOOLS
fi

. "$SCRIPT_DIR/tools.sh" "$TOOL_DIR" autoconf mercurial bootstrap_jdk15 jtreg webrev $JAVAFX_TOOLS


if $BUILD_JAVAFX ; then
	clone_javafx
	revert_javafx
	patch_javafx
	#clean_javafx
	build_javafx
	#test_javafx
	build_javafx_demos
fi

clone_jdk
clean_jdk
revert_jdk
patch_jdk
configure_jdk
build_jdk
#test_gtest test/hotspot/gtest/classfile/test_symbolTable.cpp
#test_jdk jdk/java/net/httpclient/ByteArrayPublishers.java

JDK_IMAGE_DIR="$JDK_DIR/build/$JDK_CONF/images/jdk"

if $BUILD_JAVAFX ; then
	WITH_JAVAFX_STR=-javafx
fi

if $BUILD_SHENANDOAH ; then
	WITH_SHENANDOAH_STR=-shenandoah
fi

# create distribution zip
pushd "$JDK_IMAGE_DIR"
zip -r "$BUILD_DIR/$JDK_BASE$WITH_JAVAFX_STR$WITH_SHENANDOAH_STR.zip" .
popd

