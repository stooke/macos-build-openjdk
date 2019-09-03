# Compiling jdk11u using XCode 9 or 10 

How to compile JDK 11 with the latest Xcode on macOS Mojave, High Sierra or even Catalina beta
(stooke@redhat.com, September 2019)

This is actually pretty easy so this repo exists for convenience more than anything else at this point.

### Quick start:

The easiest way to get a working JDK11u is:

```
  git clone https://github.com/stooke/jdk11u-xcode10.git
  ./jdk11u-xcode10/build11.sh
```

## Install Prerequisites

Some of these are also required for building JDK 11, so your efforts won't be wasted here.  The build script will download and install these (except for Xcode; that one's on you) in a local location, so no action is required if you use these scripts

Install XCode 9 or 10, autoconf, freetype and mercurial.

If you're using the XCode 11 beta, you may need to disable precompiled headers: `--disable-precompiled-headers`.  There seems to be an issue with honouring include file paths.

