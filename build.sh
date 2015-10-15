#!/bin/bash

# Yay shell scripting! This script builds a static version of
# OpenSSL ${OPENSSL_VERSION} for iOS 7.0 that contains code for
# armv6, armv7, arm7s and i386.

set -x

# Setup paths to stuff we need

OPENSSL_VERSION="1.0.1m"

DEVELOPER="/Applications/Xcode.app/Contents/Developer"

SDK_VERSION="9.0"
WATCH_SDK_VERSION="2.0"
MIN_VERSION="2.0"

IPHONEOS_PLATFORM="${DEVELOPER}/Platforms/iPhoneOS.platform"
IPHONEOS_SDK="${IPHONEOS_PLATFORM}/Developer/SDKs/iPhoneOS${SDK_VERSION}.sdk"
IPHONEOS_GCC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

IPHONESIMULATOR_PLATFORM="${DEVELOPER}/Platforms/iPhoneSimulator.platform"
IPHONESIMULATOR_SDK="${IPHONESIMULATOR_PLATFORM}/Developer/SDKs/iPhoneSimulator${SDK_VERSION}.sdk"
IPHONESIMULATOR_GCC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

WATCHSIMULATOR_NAME="WatchSimulator"
WATCHSIMULATOR_PLATFORM="${DEVELOPER}/Platforms/${WATCHSIMULATOR_NAME}.platform"
WATCHSIMULATOR_SDK="${WATCHSIMULATOR_PLATFORM}/Developer/SDKs/${WATCHSIMULATOR_NAME}${WATCH_SDK_VERSION}.sdk"
WATCHSIMULATOR_GCC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

WATCHOS_NAME="WatchOS"
WATCHOS_PLATFORM="${DEVELOPER}/Platforms/${WATCHOS_NAME}.platform"
WATCHOS_SDK="${WATCHOS_PLATFORM}/Developer/SDKs/${WATCHOS_NAME}${WATCH_SDK_VERSION}.sdk"
WATCHOS_GCC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

# Make sure things actually exist

if [ ! -d "$IPHONEOS_PLATFORM" ]; then
  echo "Cannot find $IPHONEOS_PLATFORM"
  exit 1
fi

if [ ! -d "$IPHONEOS_SDK" ]; then
  echo "Cannot find $IPHONEOS_SDK"
  exit 1
fi

if [ ! -x "$IPHONEOS_GCC" ]; then
  echo "Cannot find $IPHONEOS_GCC"
  exit 1
fi

if [ ! -d "$IPHONESIMULATOR_PLATFORM" ]; then
  echo "Cannot find $IPHONESIMULATOR_PLATFORM"
  exit 1
fi

if [ ! -d "$IPHONESIMULATOR_SDK" ]; then
  echo "Cannot find $IPHONESIMULATOR_SDK"
  exit 1
fi

if [ ! -x "$IPHONESIMULATOR_GCC" ]; then
  echo "Cannot find $IPHONESIMULATOR_GCC"
  exit 1
fi

# Clean up whatever was left from our previous build

rm -rf include lib
rm -rf /tmp/openssl-${OPENSSL_VERSION}-*
rm -rf /tmp/openssl-${OPENSSL_VERSION}-*.*-log

build()
{
   TARGET=$1
   ARCH=$2
   GCC=$3
   SDK=$4
   EXTRA=$5
   INSTALL=$6
   NAME=$7
   rm -rf "openssl-${OPENSSL_VERSION}"
   tar xfz "openssl-${OPENSSL_VERSION}.tar.gz"
   pushd .
   cd "openssl-${OPENSSL_VERSION}"
   ./Configure ${TARGET} --openssldir="/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}" ${EXTRA} &> "/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}.log"
   perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
   perl -i -pe "s|^CC= gcc|CC= ${GCC} -arch ${ARCH} -mwatchos-version-min=${MIN_VERSION}|g" Makefile
   perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${SDK} \$1|g" Makefile
   make &> "/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}.build-log"
   if [ "$INSTALL" == "yes" ]; then
	   make -k install &> "/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}.install-log"
   else
       mkdir -p "/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}/lib/"
       cp libcrypto.a "/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}/lib/"
       cp libssl.a "/tmp/openssl-${OPENSSL_VERSION}-${NAME}-${ARCH}/lib/"
   fi
   popd
   rm -rf "openssl-${OPENSSL_VERSION}"
}

#### WE REMOVE armv7s architecture

# build "BSD-generic32" "armv7" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}" "" "no"
# build "BSD-generic64" "arm64" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}" "" "no"
# build "BSD-generic32" "i386" "${IPHONESIMULATOR_GCC}" "${IPHONESIMULATOR_SDK}" "" "yes"
# build "BSD-generic64" "x86_64" "${IPHONESIMULATOR_GCC}" "${IPHONESIMULATOR_SDK}" "-DOPENSSL_NO_ASM" "no"
build "BSD-generic32" "armv7k" "${WATCHOS_GCC}"        "${WATCHOS_SDK}"        "-fembed-bitcode" "no" "${WATCHOS_NAME}"
build "BSD-generic32" "i386"   "${WATCHSIMULATOR_GCC}" "${WATCHSIMULATOR_SDK}" "" "no" "${WATCHSIMULATOR_NAME}"

#

mkdir include
cp -r /tmp/openssl-${OPENSSL_VERSION}-i386/include/openssl include/

mkdir lib
lipo \
  "/tmp/openssl-${OPENSSL_VERSION}-WatchOS-armv7k/lib/libcrypto.a" \
  "/tmp/openssl-${OPENSSL_VERSION}-WatchSimulator-i386/lib/libcrypto.a" \
	-create -output lib/libcrypto.a
lipo \
  "/tmp/openssl-${OPENSSL_VERSION}-WatchOS-armv7k/lib/libssl.a" \
  "/tmp/openssl-${OPENSSL_VERSION}-WatchSimulator-i386/lib/libssl.a" \
	-create -output lib/libssl.a

rm -rf "/tmp/openssl-${OPENSSL_VERSION}-*"
rm -rf "/tmp/openssl-${OPENSSL_VERSION}-*.*-log"

