#!/usr/bin/env bash
# Ignored in case of a source call, but needed for bash specific sourcing detection

set -o pipefail

# shellcheck disable=SC2091
if [ -z "${GITHUB_ENV}" ] && ! $(return 0 2>/dev/null); then
  echo "This script must be run by sourcing it:"
  echo "source $0 $*"
  exit 1
fi

realpath() {
    OLDPWD="${PWD}"
    cd "$1" || exit 1
    pwd
    cd "${OLDPWD}" || exit 1
}

# Get script file location, compatible with bash and zsh
if [ -n "$BASH_VERSION" ]; then
  THIS_SCRIPT_NAME="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_VERSION" ]; then
  # shellcheck disable=SC2296
  THIS_SCRIPT_NAME="${(%):-%N}"
else
  THIS_SCRIPT_NAME="$0"
fi

HOST_ARCH=$(uname -m)

if [ "$HOST_ARCH" != "arm64" ] && [ "$HOST_ARCH" != "x86_64" ]; then
    echo "ERROR: Unsupported architecture detected: $HOST_ARCH"
    exit 1
fi

# Default to the iOS Simulator so we can iterate without a physical device.
# Override with IOS_VCPKG_TRIPLET=arm64-ios for a device build.
if [ -n "${IOS_VCPKG_TRIPLET}" ]; then
    VCPKG_TARGET_TRIPLET="${IOS_VCPKG_TRIPLET}"
else
    VCPKG_TARGET_TRIPLET="arm64-ios-simulator"
fi

if [ "$HOST_ARCH" = "arm64" ]; then
    VCPKG_HOST_TRIPLET="arm64-osx-min1100"
else
    VCPKG_HOST_TRIPLET="x64-osx-min1100"
fi

MIXXX_ROOT="$(realpath "$(dirname "$THIS_SCRIPT_NAME")/..")"
DEFAULT_VCPKG_ROOT="$(realpath "${MIXXX_ROOT}/../mixxx-vcpkg")"

[ -z "$MIXXX_VCPKG_ROOT" ] && MIXXX_VCPKG_ROOT="${DEFAULT_VCPKG_ROOT}"
[ -z "$BUILDENV_BASEPATH" ] && BUILDENV_BASEPATH="${MIXXX_ROOT}/buildenv"

case "$1" in
    name)
        echo "mixxx-vcpkg-${VCPKG_TARGET_TRIPLET}"
        ;;

    setup)
        if [ ! -x "${MIXXX_VCPKG_ROOT}/vcpkg" ]; then
            echo "ERROR: vcpkg not found at ${MIXXX_VCPKG_ROOT}/vcpkg"
            echo "Clone and bootstrap Mixxx's vcpkg fork first:"
            echo "  git clone https://github.com/mixxxdj/vcpkg.git \"${DEFAULT_VCPKG_ROOT}\""
            echo "  \"${DEFAULT_VCPKG_ROOT}/bootstrap-vcpkg.sh\" -disableMetrics"
            return 1 2>/dev/null || exit 1
        fi

        export MIXXX_VCPKG_ROOT
        export VCPKG_TARGET_TRIPLET
        export VCPKG_DEFAULT_TRIPLET="${VCPKG_TARGET_TRIPLET}"
        export VCPKG_DEFAULT_HOST_TRIPLET="${VCPKG_HOST_TRIPLET}"
        export CMAKE_GENERATOR="${CMAKE_GENERATOR:-Xcode}"
        export BUILDENV_BASEPATH

        echo_exported_variables() {
            echo "MIXXX_VCPKG_ROOT=${MIXXX_VCPKG_ROOT}"
            echo "VCPKG_TARGET_TRIPLET=${VCPKG_TARGET_TRIPLET}"
            echo "VCPKG_DEFAULT_TRIPLET=${VCPKG_DEFAULT_TRIPLET}"
            echo "VCPKG_DEFAULT_HOST_TRIPLET=${VCPKG_DEFAULT_HOST_TRIPLET}"
            echo "CMAKE_GENERATOR=${CMAKE_GENERATOR}"
            echo "BUILDENV_BASEPATH=${BUILDENV_BASEPATH}"
        }

        if [ -n "${GITHUB_ENV}" ]; then
            echo_exported_variables >> "${GITHUB_ENV}"
        elif [ "$1" != "--profile" ]; then
            echo ""
            echo "Exported environment variables:"
            echo_exported_variables
            echo ""
            echo "Install/build iOS dependencies (long-running) with:"
            echo "  \"\${MIXXX_VCPKG_ROOT}/vcpkg\" install --triplet \"\${VCPKG_TARGET_TRIPLET}\""
            echo ""
            echo "Then configure Mixxx from an EMPTY build directory:"
            echo "  cmake -G \"\${CMAKE_GENERATOR}\" \\"
            echo "    -DCMAKE_TOOLCHAIN_FILE=\${MIXXX_VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake \\"
            echo "    -DVCPKG_TARGET_TRIPLET=\${VCPKG_TARGET_TRIPLET} \\"
            echo "    -DMIXXX_VCPKG_ROOT=\${MIXXX_VCPKG_ROOT} \\"
            echo "    -DQML=OFF \\"
            echo "    ${MIXXX_ROOT}"
        fi
        ;;

    install-deps)
        if [ ! -x "${MIXXX_VCPKG_ROOT}/vcpkg" ]; then
            echo "ERROR: vcpkg not found at ${MIXXX_VCPKG_ROOT}/vcpkg"
            return 1 2>/dev/null || exit 1
        fi
        export VCPKG_DEFAULT_TRIPLET="${VCPKG_TARGET_TRIPLET}"
        export VCPKG_DEFAULT_HOST_TRIPLET="${VCPKG_HOST_TRIPLET}"
        (
          cd "${MIXXX_VCPKG_ROOT}" || exit 1
          ./vcpkg install \
            --triplet "${VCPKG_TARGET_TRIPLET}" \
            --clean-after-build \
            --recurse \
            --feature-flags="-compilertracking,manifests,registries,versions" \
            --x-abi-tools-use-exact-versions
        )
        ;;

    *)
        echo "Usage: source ios_buildenv.sh [options]"
        echo ""
        echo "options:"
        echo "   help          Displays this help."
        echo "   name          Displays the name of the required build environment."
        echo "   setup         Export environment variables for an iOS build."
        echo "   install-deps  Build Mixxx's vcpkg dependencies for iOS (hours)."
        echo ""
        echo "environment:"
        echo "   IOS_VCPKG_TRIPLET   arm64-ios-simulator (default) or arm64-ios"
        echo "   MIXXX_VCPKG_ROOT    path to mixxxdj/vcpkg clone"
        ;;
esac
