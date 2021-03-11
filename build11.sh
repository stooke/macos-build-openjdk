s!/bin/bash

# define JDK and repo
JDK_BASE=jdk11u-dev
#JDK_TAG=jdk-11.0.9+10

# set true to build Shanendoah, false for normal build
BUILD_SHENANDOAH=true

# set true to build javaFX, false for no javaFX
BUILD_JAVAFX=true

## release, fastdebug, slowdebug
DEBUG_LEVEL=fastdebug

### no need to change anything below this line unless something went wrong

set -x
set -e

# define build environment
BUILD_DIR=`pwd`
pushd `dirname $0`
SCRIPT_DIR=`pwd`
PATCH_DIR="$SCRIPT_DIR/jdk11u-patch"
TOOL_DIR="$BUILD_DIR/tools"
popd
JDK_DIR="$BUILD_DIR/$JDK_BASE"
JDK_CONF=macosx-x86_64-normal-server-$DEBUG_LEVEL

JDK_REPO=http://hg.openjdk.java.net/jdk-updates/$JDK_BASE

if $BUILD_SHENANDOAH ; then
  JDK_CONF="${JDK_CONF}-shenandoah"
fi

if $BUILD_JAVAFX ; then
  JAVAFX_REPO=http://hg.openjdk.java.net/openjfx/jfx-dev/rt
  JAVAFX_BUILD_DIR="$BUILD_DIR/jfx11"
fi

### JDK

clone_jdk() {
    progress "cloning jdk repo"
	if ! test -d "$JDK_DIR" ; then
		hg clone $JDK_REPO "$JDK_DIR"
	else
		pushd "$JDK_DIR"
		hg pull -u
		popd
	fi
	if [ "x$JDK_TAG" != "x" ] ; then
		pushd "$JDK_DIR"
		hg update -r "$JDK_TAG"
		popd
	fi
}

patch_jdk() {
    progress "patching jdk repo"
	if test -f "$PATCH_DIR/mac-jdk11u.patch" ; then
		pushd "$JDK_DIR"
		hg import -f --no-commit "$PATCH_DIR/mac-jdk11u.patch"
		popd
	fi
}

configure_jdk() {
    progress "configuring jdk build"
	pushd "$JDK_DIR"
	if $BUILD_JAVAFX ; then
		CONFIG_ARGS=--with-import-modules=$JAVAFX_BUILD_DIR/build/modular-sdk
	fi 
    if $BUILD_SHENANDOAH ; then
        CONFIG_ARGS="$CONFIG_ARGS --with-jvm-features=shenandoahgc"
    fi
	chmod 755 ./configure
	./configure --with-toolchain-type=clang \
            --includedir=$XCODE_DEVELOPER_PREFIX/Toolchains/XcodeDefault.xctoolchain/usr/include \
            --with-debug-level=$DEBUG_LEVEL \
            --with-jtreg="$TOOL_DIR/jtreg" \
            --with-boot-jdk=$JAVA_HOME $CONFIG_ARGS
	popd
}

clean_jdk() {
    progress "cleaning jdk repo"
	rm -fr "$JDK_DIR/build"
	find "$JDK_DIR" -name \*.rej  -exec rm {} \; 2>/dev/null || true 
	find "$JDK_DIR" -name \*.orig -exec rm {} \; 2>/dev/null || true
}

revert_jdk() {
    progress "reverting jdk repo"
	pushd "$JDK_DIR"
	hg revert .
	popd
}

build_jdk() {
    progress "building jdk"
	pushd "$JDK_DIR"
	#IMAGES="bootcycle-images legacy-images"
	IMAGES="images"
	make $IMAGES CONF=$JDK_CONF
	popd
}

test_jdk() {
	TESTS=$*
	JDK_HOME="$JDK_DIR/build/$JDK_CONFIG/images/jdk"
	JT_WORK="$BUILD_DIR/jtreg"
	pushd "$JDK_DIR"
	jtreg -w "$JT_WORK/work" -r "$JT_WORK/report" -jdk:$JDK_HOME $TESTS
	popd
}

test_tier1() {
	TESTS=$*
	JDK_HOME="$JDK_DIR/build/$JDK_CONF/images/jdk"
	pushd "$JDK_DIR"
#	make run-test-tier1
	make run-test TEST="jtreg:test/hotspot:tier1"
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
    progress "cloning javafx repo"
    cd `dirname $JAVAFX_BUILD_DIR`
    git clone https://github.com/openjdk/jfx.git "$JAVAFX_BUILD_DIR"
    #hg clone $JAVAFX_REPO "$JAVAFX_BUILD_DIR"
  fi
  chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
}

patch_javafx() {
    progress "patch javafx repo"
	pushd "$JAVAFX_BUILD_DIR"
	if [ -f "$SCRIPT_DIR/javafx11.patch" ] ; then
		#hg import -f --no-commit "$SCRIPT_DIR/javafx11.patch"
		git apply "$SCRIPT_DIR/javafx11.patch"
	fi
	chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
	popd
}

revert_javafx() {
    progress "revert javafx repo"
    pushd "$JAVAFX_BUILD_DIR"
    #hg revert .
    git restore .
    popd
}

test_javafx() {
    progress "test javafx"
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew --info cleanTest :base:test
}

build_javafx() {
    progress "build javafx"
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew
}

build_javafx_demos() {
    progress "build javafx demos"
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew :apps:build
}

clean_javafx() {
    progress "cleaning javafx"
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
    ./gradlew clean
    rm -fr build
}

progress() {
   echo $1
}

#### build the world

if $BUILD_JAVAFX ; then
	JAVAFX_TOOLS="ant cmake mvn" 
else
	unset JAVAFX_TOOLS
fi

. "$SCRIPT_DIR/tools.sh" "$TOOL_DIR" autoconf mercurial bootstrap_jdk10 bootstrap_jdk11 jtreg webrev $JAVAFX_TOOLS


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
#clean_jdk
#revert_jdk
#patch_jdk
configure_jdk
build_jdk

#test_gtest test/hotspot/gtest/classfile/test_symbolTable.cpp
#test_jdk jdk/java/net/httpclient/ByteArrayPublishers.java
#test_tier1

JDK_IMAGE_DIR="$JDK_DIR/build/$JDK_CONF/images/jdk"

if $BUILD_JAVAFX ; then
	WITH_JAVAFX_STR=-javafx
fi

if $BUILD_SHENANDOAH ; then
	WITH_SHENANDOAH_STR=-shenandoah
fi

# create distribution zip
pushd "$JDK_IMAGE_DIR"
zip -r "$BUILD_DIR/$JDK_BASE$WITH_JAVAFX_STR${WITH_SHENANDOAH_STR}-debug.zip" `find . -name \*.dSYM`
zip "$BUILD_DIR/$JDK_BASE$WITH_JAVAFX_STR$WITH_SHENANDOAH_STR.zip" `find . | grep -v \*\.dSYM`
popd

