#!/usr/bin/env bash
# Configure Mixxx for iOS (Simulator by default, or device with IOS_VCPKG_TRIPLET=arm64-ios).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VCPKG_ROOT="${MIXXX_VCPKG_ROOT:-$(cd "$ROOT/../mixxx-vcpkg" && pwd)}"
TRIPLET="${VCPKG_TARGET_TRIPLET:-${IOS_VCPKG_TRIPLET:-arm64-ios-simulator}}"

if [[ "$TRIPLET" == "arm64-ios" ]]; then
  SYSROOT="${CMAKE_OSX_SYSROOT:-iphoneos}"
  BUILD_DIR="${BUILD_DIR:-$ROOT/build-ios-device}"
else
  SYSROOT="${CMAKE_OSX_SYSROOT:-iphonesimulator}"
  BUILD_DIR="${BUILD_DIR:-$ROOT/build-ios-simulator}"
fi

# Free Personal Team signing requires a unique bundle id you control.
BUNDLE_ID="${IOS_BUNDLE_IDENTIFIER:-com.gtrevg.mixxx}"
# From Xcode → Settings → Accounts (Personal Team).
DEVELOPMENT_TEAM="${IOS_DEVELOPMENT_TEAM:-A297B44B3J}"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  echo "ERROR: vcpkg not found at $VCPKG_ROOT"
  exit 1
fi

if [[ ! -d "$VCPKG_ROOT/installed/$TRIPLET" && ! -d "$VCPKG_ROOT/vcpkg_installed/$TRIPLET" ]]; then
  echo "ERROR: triplet $TRIPLET not installed yet under $VCPKG_ROOT"
  echo "Run: export IOS_VCPKG_TRIPLET=$TRIPLET && source tools/ios_buildenv.sh setup"
  echo "     then install deps for that triplet (hours)."
  exit 1
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

export VCPKG_DEFAULT_TRIPLET="$TRIPLET"
export VCPKG_DEFAULT_HOST_TRIPLET="${VCPKG_DEFAULT_HOST_TRIPLET:-arm64-osx-min1100}"

cmake -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DVCPKG_TARGET_TRIPLET="$TRIPLET" \
  -DMIXXX_VCPKG_ROOT="$VCPKG_ROOT" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$SYSROOT" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DQML=OFF \
  -DHID=OFF \
  -DBULK=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_BENCH=OFF \
  -DBROADCAST=OFF \
  -DBATTERY=OFF \
  -DPORTMIDI=OFF \
  -DLILV=OFF \
  -DKEYFINDER=ON \
  -DFFMPEG=ON \
  -DIOS_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  -DIOS_DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  "$ROOT"

echo ""
echo "Configured in $BUILD_DIR (triplet=$TRIPLET sysroot=$SYSROOT)"
echo "Build with:"
echo "  cmake --build \"$BUILD_DIR\" --config RelWithDebInfo --target mixxx"
if [[ "$TRIPLET" == "arm64-ios" ]]; then
  echo "Then open the Xcode project, select your iPad, and Product → Run."
fi
