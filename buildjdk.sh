#!/bin/bash

# define JDK and repo
JDK_VER=
JDK_BASE=jdk$JDK_VER
#JDK_TAG=

# set true to build Shanendoah, false for normal build
BUILD_SHENANDOAH=true

# set true to build javaFX, false for no javaFX
BUILD_JAVAFX=false
#BUILD_JAVAFX=true
INCLUDE_JAVAFX=$BUILD_JAVAFX

## release, fastdebug, slowdebug
DEBUG_LEVEL=fastdebug
MAKELOGLEVEL=LOG=info

CLEAN_JDK=true
#CLEAN_JDK=false
CONFIGURE_JDK=true
#CONFIGURE_JDK=false
BUILD_JDK=true
#BUILD_JDK=false
BUILD_IMAGES=true
TEST_JDK=false
MAKE_ZIPS=false

# NOTE: always true - downloading tools also adds them to the path
DOWNLOAD_TOOLS=true
CLEAN_TOOLS=false

usage()
{
  script=`basename $0`
  echo "usage : $script [ aarch64 | x86_64 ]"
  exit 1
}

if [ $# -gt 1 ]; then
  usage
fi

# first, figure out what is the target platform: aarch64 or x86_64

# did the user specify the platform?
if [ $# -gt 0 ] ; then
  if [ $1 == "x86_64" ] ; then
    echo "build target x86_64"
    export BUILD_TARGET_ARCH=x86_64
  elif [ $1 == "aarch64" ] ; then
    echo "build target aarch64"
    export BUILD_TARGET_ARCH=aarch64
  elif [ $1 == "arm64" ] ; then
    echo "build target aarch64"
    export BUILD_TARGET_ARCH=aarch64
  else
    usage
  fi
fi

# use the default, the build platform
if [ .$BUILD_TARGET_ARCH == . ] ; then
	# default to build system architecture
	if [ "`uname -m`" = "arm64" ] ; then
		echo "defaulting to build aarch64"
		export BUILD_TARGET_ARCH=aarch64
	else
		echo "defaulting to build x86_64"
		export BUILD_TARGET_ARCH=x86_64
	fi
fi

# if we're on aarch64 and want to build x86_64, use rosetta
RUN_UNDER_ROSETTA=false
if [ "`uname -m`" = "arm64" ] ; then
	if [ "$BUILD_TARGET_ARCH" = "x86_64" ] ; then
		RUN_UNDER_ROSETTA=true
	fi
fi


# if we're on a macos arm64 machine, we can run in x86_64 or native aarch64/arm64 mode.
if $RUN_UNDER_ROSETTA ; then
	if [ "`uname`" = "Darwin" ] ; then
		if [ "`uname -m`" = "arm64" ] ; then
			echo "building on aarch64 - restarting in x86_64 mode"
			arch -x86_64 "$0" $BUILD_TARGET_ARCH
			exit $?
		fi
	fi
fi

TARGET_ARGS=
if [ .$BUILD_TARGET_ARCH == .aarch64 ] ; then 
	if [ "`uname -m`" != "arm64" ] ; then
		TARGET_ARGS="--host=aarch64-apple-darwin"
	fi
fi

### no need to change anything below this line unless something went wrong

set -e

if $BUILD_JAVAFX ; then
	WITH_JAVAFX_STR=-javafx
fi

if $BUILD_SHENANDOAH ; then
	WITH_SHENANDOAH_STR=-shenandoah
fi

# define build environment
BUILD_DIR=`pwd`
pushd `dirname $0`
SCRIPT_DIR=`pwd`
PATCH_DIR="$SCRIPT_DIR/jdk$JDK_VER-patch"
TOOL_DIR="$BUILD_DIR/tools"
popd
JDK_DIR="$BUILD_DIR/$JDK_BASE"
JDK_CONF=macos-${BUILD_TARGET_ARCH}-${DEBUG_LEVEL}${WITH_JAVAFX_STR}${WITH_SHENANDOAH_STR}
JDK_REPO=http://github.com/openjdk/${JDK_BASE}

if $BUILD_JAVAFX ; then
  JAVAFX_REPO=https://github.com/openjdk/jfx.git
  JAVAFX_BUILD_DIR="$BUILD_DIR/jfx"
fi

### JDK

clone_jdk() {
    progress "cloning jdk repo"
	if ! test -d "$JDK_DIR" ; then
		git clone $JDK_REPO "$JDK_DIR"
	else
		pushd "$JDK_DIR"
		git pull 
		popd
	fi
	if [ "x$JDK_TAG" != "x" ] ; then
		pushd "$JDK_DIR"
		git checkout "$JDK_TAG"
		popd
	fi
}

patch_jdk() {
	progress "patching jdk repo"
	if test -f "$PATCH_DIR/mac-jdk$JDK_VER.patch" ; then
		pushd "$JDK_DIR"
		git apply "$PATCH_DIR/mac-jdk$JDK_VER.patch"
		popd
	fi
}

configure_jdk() {
	progress "configuring jdk build"
	pushd "$JDK_DIR"
	if $INCLUDE_JAVAFX ; then
		CONFIG_ARGS=--with-import-modules=${JAVAFX_BUILD_DIR}/build/modular-sdk
	fi
	if $BUILD_SHENANDOAH ; then
		CONFIG_ARGS="${CONFIG_ARGS} --enable-jvm-feature-shenandoahgc"
	fi
	chmod 755 ./configure
	./configure --with-toolchain-type=clang \
            --includedir=$XCODE_DEVELOPER_PREFIX/Toolchains/XcodeDefault.xctoolchain/usr/include \
            --with-debug-level=$DEBUG_LEVEL \
            --enable-jvm-feature-jvmti \
            --enable-jvm-feature-jvmci \
            --enable-jvm-feature-jfr \
            --enable-unlimited-crypto=yes \
            --with-conf-name=$JDK_CONF \
            --with-jtreg="$TOOL_DIR/jtreg" \
            --disable-warnings-as-errors \
            --with-boot-jdk=$JAVA_HOME ${CONFIG_ARGS} ${TARGET_ARGS}
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
	git restore .
	popd
}

build_jdk_images() {
	progress "building jdk"
	pushd "$JDK_DIR"
	#IMAGES="bootcycle-images"
	IMAGES="images"
	#make CONF=${JDK_CONF} reconfigure
	make ${IMAGES} CONF=${JDK_CONF} ${MAKELOGLEVEL}
	popd
}

build_hotspot() {
	progress "building jdk"
	pushd "$JDK_DIR"
	#IMAGES="bootcycle-images"
	IMAGES="hotspot"
	make ${IMAGES} CONF=${JDK_CONF} ${MAKELOGLEVEL}
	popd
}

test_jdk() {
	TESTS=$*
	JDK_HOME="$JDK_DIR/build/$JDK_CONF/images/jdk"
	JT_WORK="$BUILD_DIR/jtreg"
	rm -fr "$JT_WORK"
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
		git clone $JAVAFX_REPO "$JAVAFX_BUILD_DIR"
	fi
	chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
}

patch_javafx() {
	progress "patch javafx repo"
	pushd "$JAVAFX_BUILD_DIR"
	if [ -f "$SCRIPT_DIR/javafx11.patch" ] ; then
		git apply "$SCRIPT_DIR/javafx11.patch"
	fi
	chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
	popd
}

revert_javafx() {
	progress "revert javafx repo"
	pushd "$JAVAFX_BUILD_DIR"
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
    uname -m
env
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
set -x
    cd "$JAVAFX_BUILD_DIR"
    chmod 755 "$JAVAFX_BUILD_DIR/gradlew"
echo $PATH
echo $JAVA_HOME
echo $JDK_HOME
    ./gradlew clean
    rm -fr build
}

progress() {
   echo $1
}

#### build the world

if $DOWNLOAD_TOOLS ; then
	. "$SCRIPT_DIR/fetchjdk.sh" "$TOOL_DIR" bootstrap_jdk23
	if $BUILD_JAVAFX ; then
		JAVAFX_TOOLS="ant cmake mvn" 
	else
		unset JAVAFX_TOOLS
	fi
	. "$SCRIPT_DIR/tools.sh" "$TOOL_DIR" autoconf jtreg $JAVAFX_TOOLS
fi

set -x

# build JavaFX using boot JDK
if $BUILD_JAVAFX ; then
#    export JDK_HOME=$JDK_IMAGE_DIR
#    export PATH=$JDK_HOME/bin:$PATH
	clone_javafx
	revert_javafx
	patch_javafx
	clean_javafx
	time build_javafx
	#test_javafx
	build_javafx_demos
fi

if $BUILD_JDK ; then
	#clone_jdk
	if $CLEAN_JDK ; then
		clean_jdk
	fi
	if $CONFIGURE_JDK ; then
		configure_jdk
	fi
	if $BUILD_IMAGES ; then
		time build_jdk_images
	else
		time build_hotspot
	fi
fi

test_jdk test/hotspot/jtreg/serviceability/dcmd/vm/SystemDumpMapTest.java
test_jdk test/hotspot/jtreg/serviceability/dcmd/vm/SystemMapTest.java
#test_jdk jdk/java/net/httpclient/ByteArrayPublishers.java

if $TEST_JDK ; then
	test_gtest test/hotspot/gtest/classfile/test_symbolTable.cpp
	test_jdk jdk/java/net/httpclient/ByteArrayPublishers.java
	test_tier1
fi

JDK_IMAGE_DIR="$JDK_DIR/build/$JDK_CONF/images/jdk"

if $MAKE_ZIPS ; then
	# create distribution zip
	pushd "$JDK_IMAGE_DIR/.."
	IMAGE_DIR=$JDK_BASE-${BUILD_TARGET_ARCH}${WITH_JAVAFX_STR}${WITH_SHENANDOAH_STR}
	mv "$JDK_IMAGE_DIR" $IMAGE_DIR
	zip -r "$BUILD_DIR/$IMAGE_DIR.zip" $IMAGE_DIR
	zip "$BUILD_DIR/$IMAGE_DIR-debug.zip" `find . | grep -v \*\.dSYM`
	mv $IMAGE_DIR "$JDK_IMAGE_DIR"
fi

