# Compiling jdk11u using XCode 9-12

How to compile JDK 11 with the latest Xcode on macOS High Sierra, to Bug Sur
(Currently tested with Xcode 9.4/macOS 10.13.6 and Xcode 10.3/macOS 10.14.6)

This is actually pretty easy so this repo exists for convenience more than anything else at this point.
The currently checked in script builds a full jdk11u with Shenandoah and JavaFX.  
Edit the script to disable either Shenandoah or JavaFX.

### Quick start:

The easiest way to get a working JDK11u is:

```
  git clone https://github.com/stooke/jdk11u-macos.git
  ./jdk11u-macos/build11.sh
```

The easiest way to get a working JDK17 (preview) is:

```
  git clone https://github.com/stooke/jdk11u-macos.git
  ./jdk11u-macos/buildjdk.sh
```

## Install Prerequisites

The build script will download and install these (except for Xcode; that one's on you) in a local location, so no action is required if you use these scripts.

You must download Xcode, install it in /Applications, (run it once to accept the license) and run
```
  sudo xcode-select -s /Applications/Xcode.app
```


