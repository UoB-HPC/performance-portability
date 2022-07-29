#!/bin/bash

set -eu

# build_tbb() {
#   SUFFIX="dist_$(uname -m)"
#   DIST_DIR="$PWD/oneTBB/$SUFFIX"
#   if [ ! -d "$DIST_DIR" ]; then
#     if [ ! -d "$PWD/oneTBB" ]; then
#       git clone https://github.com/oneapi-src/oneTBB.git
#     fi
#     cd oneTBB
#     rm -rf build
#     cmake -Bbuild -H. -DTBB_TEST=OFF -DCMAKE_INSTALL_PREFIX="$SUFFIX"
#     cmake --build build -- -j $(nproc)
#     cmake --install build
#   fi
#   export TBB_PATH="$DIST_DIR"
# }


fetch_src() {
  if [ ! -e BabelStream/src/main.cpp ]; then
    if ! git clone -b option_for_vec https://github.com/uob-hpc/BabelStream; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  fi
  export SRC_DIR="$PWD/BabelStream"
}
