#!/bin/bash

# usage: . ./tools.sh tooldir [tool]...
OLDPATH="$PATH"
set -e

set_os() {
	IS_LINUX=false
	if [ "`uname`" = "Linux" ] ; then
		IS_LINUX=true
	fi
	IS_DARWIN=false
	if [ "`uname`" = "Darwin" ] ; then
		IS_DARWIN=true
	fi
	# one of x86_64 or arm64
	BUILD_TARGET_ARCH=`uname -m`
	if [ "$BUILD_TARGET_ARCH" = "x86_64" ] ; then
		IS_INTEL=true
		IS_ARM=false
	else
		IS_INTEL=false
		IS_ARM=true
	fi
}

# define toolchain
find_xcode() {
	XCODE_APP=`dirname \`dirname \\\`xcode-select -p \\\`\``
    XCODE_VERSION=`/usr/bin/xcodebuild -version | sed -En 's/Xcode[[:space:]]+([0-9\.]*)/\1/p' | sed s/[.][0-9]*//`
	XCODE_DEVELOPER_PREFIX=$XCODE_APP/Contents/Developer
	CCTOOLCHAIN_PREFIX=$XCODE_APP/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
	OLDPATH=$PATH
	export PATH=$CCTOOLCHAIN_PREFIX/usr/bin:$PATH
	export PATH=$TOOL_PREFIX/usr/bin:$PATH
	echo Using xcode version $XCODE_VERSION installed in $XCODE_APP
}

set_os
if $IS_DARWIN ; then
	find_xcode
fi

# define build environment
TOOL_DIR="$1"
if test ".$TOOL_DIR" = "." ; then 
	TOOL_DIR="`pwd`/tools_$BUILD_TARGET_ARCH"
fi
if test ".$DOWNLOAD_DIR" = "." ; then
	DOWNLOAD_DIR="$TOOL_DIR/downloads"
fi
if test ".$TOOL_INSTALL_ROOT" = "." ; then
	TOOL_INSTALL_ROOT="$TOOL_DIR/local"
fi
if test ".$TMP" = "." ; then
	TMP=/tmp
fi
if test ".$TMP_DIR" = "." ; then
	TMP_DIR="$TMP/$$.work"
fi

download_and_open_pkg() {
	URL="$1"
	FILE="$TMP_DIR/current.pkg"
	DEST="$2"
	if ! test -f "$FILE" ; then 
		echo "downloading $1 to `basename $FILE`"
		pushd "$DOWNLOAD_DIR"
		curl --fail --output "$FILE" -L --insecure "$URL"
		popd
	fi
	if test -d "$DEST" ; then
		return
	fi
	rm -fr "$TMP_DIR/expanded-package"	
	mkdir -p "$TMP_DIR/expanded-package"	
	pushd "$TMP_DIR/expanded-package" >/dev/null
	tar -xvf "$FILE"
	popd >/dev/null
	PAYLOAD_FILE=`find "$TMP_DIR/expanded-package" -type f -name Payload`
	mkdir "$TMP_DIR/payload"
	pushd "$TMP_DIR/payload" >/dev/null
	tar -xvf "$PAYLOAD_FILE"
	mkdir -p "$DEST"
	mv `find . -type d -name Contents` "$DEST/Contents"
	popd >/dev/null
	#rm -fr "$TMP_DIR/dno" "$FILE"
}

download_and_open() {
	URL="$1"
	FILE="$DOWNLOAD_DIR/download.${RANDOM}"
	DEST="$2"
	if ! test -f "$FILE" ; then 
		echo "downloading $1 to `basename $FILE`"
		pushd "$DOWNLOAD_DIR"
		curl --fail --output "$FILE" -L --insecure "$URL"
		popd
	fi
	if test -d "$DEST" ; then
		return
	fi
	rm -fr "$TMP_DIR/dno"	
	mkdir -p "$TMP_DIR/dno"	
	pushd "$TMP_DIR/dno"	
	tar -xvf "$FILE"
	mv * "$DEST"
	popd
	rm -fr "$TMP_DIR/dno"	
}

clone_or_update() {
	URL="$1"
	DEST="$2"
	if ! test -d "$DEST" ; then 
		echo "cloning $1"
		git clone "$URL" "$DEST"
	else
		pushd "$DEST"
		git pull 
		popd
	fi	
}

build_bootstrap_jdkX() {
# usage build_bootstrap_jdkX 21 arm64 aarch64
# usage build_bootstrap_jdkX 21 x86_64 x64
	VER=$1
	ARCH=$2
	ARCH_SHORT=$3
	PLATFORM=mac
	GAorEA=ga
	if test -d "$TOOL_DIR/jdk${VER}_${ARCH}" ; then
			return
	fi
	#download_and_open_pkg https://api.adoptium.net/v3/installer/latest/${VER}/${GAorEA}/${PLATFORM}/${ARCH_SHORT}/jdk/hotspot/normal/eclipse?project=jdk "$TOOL_DIR/jdk${VER}_${ARCH}"
	download_and_open https://api.adoptium.net/v3/binary/latest/${VER}/${GAorEA}/${PLATFORM}/${ARCH_SHORT}/jdk/hotspot/normal/eclipse?project=jdk "$TOOL_DIR/jdk${VER}_${ARCH}"
}

build_bootstrap_jdk8() {
	if $IS_ARM ; then
        #build_bootstrap_jdkX 8 arm64 aarch64
		JDK_URL="https://objects.githubusercontent.com/github-production-release-asset-2e65be/372924428/1fba6827-a775-49e5-8b81-a7b069f3b4ef?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20240502%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20240502T145117Z&X-Amz-Expires=300&X-Amz-Signature=ffff3c837c1be1a49010aacf15830fafae0b0d51b05af47436bead93ead82255&X-Amz-SignedHeaders=host&actor_id=28760513&key_id=0&repo_id=372924428&response-content-disposition=attachment%3B%20filename%3DOpenJDK8U-jdk_x64_mac_hotspot_8u412b08.tar.gz&response-content-type=application%2Foctet-stream"
		#download_and_open "$JDK_URL" "$TOOL_DIR/jdk8_arm64"
	else
        build_bootstrap_jdkX 8 x86_64 x86_64
	fi
}

build_bootstrap_jdk10() {
        build_bootstrap_jdkX 10 x86_64 x86
}

build_bootstrap_jdk11_x86_64() {
        build_bootstrap_jdkX 11 x86_64 x86
}

build_bootstrap_jdk11_arm64() {
        build_bootstrap_jdkX 11 arm64 aarch64
}

build_bootstrap_jdk12() {
        build_bootstrap_jdkX 12 x86_64 x86
}

build_bootstrap_jdk13() {
        build_bootstrap_jdkX 13 x86_64 x86
}

build_bootstrap_jdk15() {
        build_bootstrap_jdkX 15 x86_64 x86
}

build_bootstrap_jdk16_x86_64() {
	build_bootstrap_jdkX 16 x86_64 x86
}

build_bootstrap_jdk16_arm64() {
	echo "there is no OpenJDK 16 aarch64 release - using x86_64 (no good for JavaFX)"
	build_bootstrap_jdkX 16 arm64 aarch64
}

build_bootstrap_jdk17_x86_64() {
	build_bootstrap_jdkX 17 x86_64 x86
}

build_bootstrap_jdk17_arm64() {
	build_bootstrap_jdkX 17 arm64 aarch64
}

build_bootstrap_jdk20_x86_64() {
	build_bootstrap_jdkX 20 x86_64 x86
}

build_bootstrap_jdk20_arm64() {
	build_bootstrap_jdkX 20 arm64 aarch64
}

build_bootstrap_jdk21_x86_64() {
    build_bootstrap_jdkX 21 x86_64 x86
}       
        
build_bootstrap_jdk21_arm64() {
    build_bootstrap_jdkX 21 arm64 aarch64
}

build_bootstrap_jdk22_x86_64() {
    build_bootstrap_jdkX 22 x86_64 x86
}       
        
build_bootstrap_jdk22_arm64() {
    build_bootstrap_jdkX 22 arm64 aarch64
}

build_bootstrap_jdk23_x86_64() {
    build_bootstrap_jdkX 23 x86_64 x86
}       
        
build_bootstrap_jdk23_arm64() {
    build_bootstrap_jdkX 23 arm64 aarch64
}

build_bootstrap_jdk11() {
	if [ "`uname -m`" = "arm64" ] ; then
		build_bootstrap_jdk11_arm64
	else
		build_bootstrap_jdk11_x86_64
	fi
}

build_bootstrap_jdk16() {
	if [ "`uname -m`" = "arm64" ] ; then
		build_bootstrap_jdk16_arm64
	else
		build_bootstrap_jdk16_x86_64
	fi
}

build_bootstrap_jdk17() {
	if [ "`uname -m`" = "arm64" ] ; then
		build_bootstrap_jdk17_arm64
	else
		build_bootstrap_jdk17_x86_64
	fi
}

build_bootstrap_jdk20() {
	if [ "`uname -m`" = "arm64" ] ; then
			build_bootstrap_jdk20_arm64
	else
			build_bootstrap_jdk20_x86_64
	fi
}

build_bootstrap_jdk21() {
	if [ "`uname -m`" = "arm64" ] ; then
			build_bootstrap_jdk21_arm64
	else
			build_bootstrap_jdk21_x86_64
	fi
}

build_bootstrap_jdk22() {
	if [ "`uname -m`" = "arm64" ] ; then
			build_bootstrap_jdk22_arm64
	else
			build_bootstrap_jdk22_x86_64
	fi
}

build_bootstrap_jdk23() {
	if [ "`uname -m`" = "arm64" ] ; then
			build_bootstrap_jdk23_arm64
	else
			build_bootstrap_jdk23_x86_64
	fi
}

build_bootstrap_jdk_latest() {
	if test -d "$TOOL_DIR/jdk-latest" ; then
			return
	fi
	download_and_open ???? "$TOOL_DIR/jdk-latest"
}

buildtools() {
	mkdir -p "$DOWNLOAD_DIR"
	mkdir -p "$TOOL_DIR"

	for tool in $* ; do 
		echo "building $tool"
		build_$tool
		if $IS_DARWIN ; then
			if test $tool == "bootstrap_jdk8" ; then
			    export JAVA_HOME=$TOOL_DIR/jdk8u/Contents/Home
			fi
			if test $tool = "bootstrap_jdk9" ; then
			    export JAVA_HOME=$TOOL_DIR/jdk9u/Contents/Home
			fi
			if test $tool = "bootstrap_jdk10" ; then
			    export JAVA_HOME=$TOOL_DIR/jdk10u/Contents/Home
			fi
			if test $tool = "bootstrap_jdk11" ; then
				if [ "`uname -m`" = "arm64" ] ; then
					export JAVA_HOME=$TOOL_DIR/jdk11_arm64/Contents/Home
				else
					export JAVA_HOME=$TOOL_DIR/jdk11_x86_64/Contents/Home
				fi
			fi
			if test $tool = "bootstrap_jdk12" ; then
			    export JAVA_HOME=$TOOL_DIR/jdk12u/Contents/Home
			fi
  	  		if test $tool = "bootstrap_jdk13" ; then
       	 		export JAVA_HOME=$TOOL_DIR/jdk13u/Contents/Home
			fi
			if test $tool = "bootstrap_jdk15" ; then
				export JAVA_HOME=$TOOL_DIR/jdk15/Contents/Home
			fi
			if test $tool = "bootstrap_jdk16" ; then
				export JAVA_HOME=$TOOL_DIR/jdk16_x86_64/Contents/Home
			fi
			if test $tool = "bootstrap_jdk16_x86_64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk16_x86_64/Contents/Home
			fi

			if test $tool = "bootstrap_jdk17" ; then
				if [ "`uname -m`" = "arm64" ] ; then
					export JAVA_HOME=$TOOL_DIR/jdk17_arm64/Contents/Home
				else
					export JAVA_HOME=$TOOL_DIR/jdk17_x86_64/Contents/Home
				fi
			fi
			if test $tool = "bootstrap_jdk17_arm64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk17_arm64/Contents/Home
			fi
			if test $tool = "bootstrap_jdk17_x86_64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk17_x86_64/Contents/Home
			fi

			if test $tool = "bootstrap_jdk20" ; then
				if [ "`uname -m`" = "arm64" ] ; then
					export JAVA_HOME=$TOOL_DIR/jdk20_arm64/Contents/Home
				else
					export JAVA_HOME=$TOOL_DIR/jdk20_x86_64/Contents/Home
				fi
			fi
			if test $tool = "bootstrap_jdk20_arm64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk20_arm64/Contents/Home
			fi
			if test $tool = "bootstrap_jdk20_x86_64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk20_x86_64/Contents/Home
			fi

			if test $tool = "bootstrap_jdk21" ; then
				if [ "`uname -m`" = "arm64" ] ; then
					export JAVA_HOME=$TOOL_DIR/jdk21_arm64/Contents/Home
				else
					export JAVA_HOME=$TOOL_DIR/jdk21_x86_64/Contents/Home
				fi
			fi
			if test $tool = "bootstrap_jdk21_arm64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk21_arm64/Contents/Home
			fi
			if test $tool = "bootstrap_jdk21_x86_64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk21_x86_64/Contents/Home
			fi

			if test $tool = "bootstrap_jdk22" ; then
				if [ "`uname -m`" = "arm64" ] ; then
					export JAVA_HOME=$TOOL_DIR/jdk22_arm64/Contents/Home
				else
					export JAVA_HOME=$TOOL_DIR/jdk22_x86_64/Contents/Home
				fi
			fi
			if test $tool = "bootstrap_jdk22_arm64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk22_arm64/Contents/Home
			fi
			if test $tool = "bootstrap_jdk22_x86_64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk22_x86_64/Contents/Home
			fi

			if test $tool = "bootstrap_jdk23" ; then
				if [ "`uname -m`" = "arm64" ] ; then
					export JAVA_HOME=$TOOL_DIR/jdk23_arm64/Contents/Home
				else
					export JAVA_HOME=$TOOL_DIR/jdk23_x86_64/Contents/Home
				fi
			fi
			if test $tool = "bootstrap_jdk23_arm64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk23_arm64/Contents/Home
			fi
			if test $tool = "bootstrap_jdk23_x86_64" ; then
				export JAVA_HOME=$TOOL_DIR/jdk23_x86_64/Contents/Home
			fi

			if test $tool = "bootstrap_jdk_latest" ; then
				export JAVA_HOME=$TOOL_DIR/jdk-latest/Contents/Home
			fi
		fi
	done
}

build_tool_path() {
	export PATH=$OLDPATH
	export PATH=$JAVA_HOME/bin:$PATH
}

mkdir -p "$TMP_DIR"
shift
buildtools $*
build_tool_path
rm -fr "$TMP_DIR"

