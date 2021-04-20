# Compiling OpenJDK 17 (preview) using Xcode 12 (including cross-compiling to aarch64 a.k.a. M1)

How to compile OpenJDK head with the latest Xcode on macOS Big Sur.
This will produce either an x86_64 JDK or an aarch64 JDK - you need ot change the BUILD_TARGET_ARCH line at the top of buildjdk.sh
This script works by restarting in x86_64 mode if on an M1, and then either doing an arrch64 cross-compile or a straight x86_64 compile.

### Quick start:

```
  git clone https://github.com/stooke/jdk11u-macos.git
  ./jdk11u-macos/buildjdk.sh
```
  
# Compiling OpenJDK 11u using XCode 12

How to compile JDK 11 with the latest Xcode on macOS High Sierra, to Big Sur
(Currently tested with Xcode 9.4/macOS 10.13.6 and Xcode 10.3/macOS 10.14.6)

This is actually pretty easy so this repo exists for convenience more than anything else at this point.
The currently checked in script builds a full jdk11u with Shenandoah and JavaFX.  
Edit the script to disable either Shenandoah or enable JavaFX.

### Quick start:

The easiest way to get a working JDK11u is:

```
  git clone https://github.com/stooke/jdk11u-macos.git
  ./jdk11u-macos/build11.sh
```

## Install Prerequisites

The build script will download and install these (except for Xcode; that one's on you) in a local location, so no action is required if you use these scripts.

You must download Xcode, install it in /Applications, (run it once to accept the license) and run
```
  sudo xcode-select -s /Applications/Xcode.app
```


