#!/bin/bash

UTARGET=$(uname)
BINSUFFIX=""

if [ "$1" = "--configure" ]; then
  export NOBUILD=1
elif [ "$1" = "--build" ]; then
  export PRECONFIGURED=1
fi

# Determine platform
if [ "$UTARGET" = "Darwin" ]; then
  export UPLATFORM="mac"
elif [ "$UTARGET" = "Linux" ]; then
  export UPLATFORM="linux_$(uname -m)"
elif [ "${UTARGET/MINGW32/}" != "$UTARGET" ]; then
  export UPLATFORM="win32"
  export BINSUFFIX=".exe"
else
  # Fallback to something...
  export UPLATFORM="$UTARGET"
fi

# Obtain Qt
if [ "$HAS_QT" != "" ]; then
   echo "Using externally supplied Qt"
elif [ "$UPLATFORM" = "mac" ]; then
  if [ ! -d /opt/qt56sm ]; then
    curl -L -o /tmp/qt-5.6.3-static-universal-macos-sdk12.3.zip https://github.com/LongSoft/qt-5.6.3-static-universal-macos-sdk12.3/blob/main/qt-5.6.3-static-universal-macos-sdk12.3.zip?raw=true || exit 1
    qtsum=$(shasum -a 256 /tmp/qt-5.6.3-static-universal-macos-sdk12.3.zip | cut -f1 -d' ')
    qtexpsum="3668341b9d768a3cff30732e3f34c39bd85ed7b2f24c4f4438fd31d513d4cf44"
    if [ "$qtsum" != "$qtexpsum" ]; then
      echo "Qt hash $qtsum does not match $qtexpsum"
      exit 1
    fi
    sudo mkdir -p /opt || exit 1
    cd /opt || exit 1
    sudo unzip -q /tmp/qt-5.6.3-static-universal-macos-sdk12.3.zip || exit 1
    cd - || exit 1
  fi

  export PATH="/opt/qt56sm/bin:$PATH"
elif [ "$UPLATFORM" = "win32" ]; then
  # Install missing dependencies
  pacman -S --noconfirm --needed zip unzip curl perl mingw-w64-i686-toolchain mingw-w64-i686-cmake || exit 1

  # Fix PATH to support running shasum.
  export PATH="/usr/bin/core_perl:$PATH"

  if [ ! -d "/c/Qt/5.6/mingw49_32_release_static/" ]; then
    curl -L -o /tmp/qt-5.6.3-static-win32.zip https://github.com/distdb/qtbuilds/blob/master/qt-5.6.3-static-win32.zip?raw=true || exit 1
    qtsum=$(shasum -a 256 /tmp/qt-5.6.3-static-win32.zip | cut -f1 -d' ')
    qtexpsum="bcd85145d6fed00da37498c08c49d763c6fa883337f754880b5c786899e6bb1d"
    if [ "$qtsum" != "$qtexpsum" ]; then
      echo "Qt hash $qtsum does not match $qtexpsum"
      exit 1
    fi
    mkdir -p /c/Qt/5.6 || exit 1
    cd /c/Qt/5.6 || exit 1
    unzip -q /tmp/qt-5.6.3-static-win32.zip || exit 1
    cd - || exit 1
  fi

  export PATH="/c/Qt/5.6/mingw49_32_release_static/bin:$PATH"
fi

# Build
echo "Attempting to build UEFITool NE for ${UPLATFORM}..."

UEFITOOL_VER=$(cat version.h | grep PROGRAM_VERSION | cut -d'"' -f2 | sed 's/NE alpha /A/')

build_tool() {
  echo "Building $1 $2"
  # Check version
  if [ "$(echo "$2" | grep '^[0-9]*\.[0-9]*\.[0-9]*$')" != "$2" ] && [ "$(echo "$2" | grep '^A[0-9]*$')" != "$2" ]; then
    echo "Invalid $1 version!"
    exit 1
  fi
  
  # Create build directory
  mkdir -p "build/$1" || exit 1
  cd "build/$1" || exit 1

  # Build
  if [ "$PRECONFIGURED" != "1" ]; then
    if [ "$3" != "" ]; then
      if [ "$UPLATFORM" = "mac" ]; then
        qmake "../../$1/$3" QMAKE_CXXFLAGS+=-flto QMAKE_LFLAGS+=-flto CONFIG+=optimize_size || exit 1
      elif [ "$UPLATFORM" = "win32" ]; then
        qmake "../../$1/$3" QMAKE_CXXFLAGS="-static -flto -Os -std=c++11" QMAKE_LFLAGS="-static -flto -Os -std=c++11" CONFIG+=optimize_size CONFIG+=staticlib CONFIG+=static || exit 1
      else
        qmake "../../$1/$3" CONFIG+=optimize_size || exit 1
      fi
    else
      if [ "$UPLATFORM" = "mac" ]; then
        cmake -G "Unix Makefiles" -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_CXX_FLAGS="-stdlib=libc++ -flto -Os -mmacosx-version-min=10.7" -DCMAKE_C_FLAGS="-flto -Os -mmacosx-version-min=10.7"  "../../$1/" || exit 1
      elif [ "$UPLATFORM" = "win32" ]; then
        cmake -G "Unix Makefiles" -DCMAKE_CXX_FLAGS="-static -Os -std=c++11" -DCMAKE_C_FLAGS="-static -Os"  "../../$1/" || exit 1
      else
        cmake -G "Unix Makefiles" -DCMAKE_CXX_FLAGS="-Os" -DCMAKE_C_FLAGS="-Os"  "../../$1/" || exit 1
      fi
    fi
  fi

  if [ "$NOBUILD" != "1" ]; then
    make || exit 1

    # Move the binary out of the dir
    if [ "$UPLATFORM" = "win32" ] && [ -f "release/${1}${BINSUFFIX}" ]; then
      mv "release/${1}${BINSUFFIX}" "${1}${BINSUFFIX}" || exit 1
    fi

    # Archive
    if [ "$1" = "UEFITool" ] && [ "$UPLATFORM" = "mac" ]; then
      strip -x UEFITool.app/Contents/MacOS/UEFITool || exit 1
      zip -qry ../../dist/"${1}_NE_${2}_${UPLATFORM}.zip" UEFITool.app ${4} || exit 1
    else
      strip -x "${1}${BINSUFFIX}" || exit 1
      zip -qry ../../dist/"${1}_NE_${2}_${UPLATFORM}.zip" "${1}${BINSUFFIX}" ${4} || exit 1
    fi
  fi

  # Return to parent
  cd ../.. || exit 1
}

rm -rf dist
mkdir -p dist || exit 1

build_tool UEFITool    "$UEFITOOL_VER"  uefitool.pro
build_tool UEFIExtract "$UEFITOOL_VER"  ""
build_tool UEFIFind    "$UEFITOOL_VER"  ""

exit 0
