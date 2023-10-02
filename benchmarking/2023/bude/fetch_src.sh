#!/bin/bash

set -eu

fetch_src() {
  if [ ! -e miniBUDE/src/main.cpp ]; then
    if ! git clone -b openmp-stdpar https://github.com/uob-hpc/miniBUDE; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  else
    (
      cd miniBUDE
      # git fetch && git pull
    )
  fi
  export SRC_DIR="$PWD/miniBUDE"
}
