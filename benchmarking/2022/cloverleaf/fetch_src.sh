#!/bin/bash

set -eu

fetch_src() {

  case "$1" in
  cuda)
    REPO_DIR=CloverLeaf_CUDA
    REPO_FILE="$REPO_DIR/clover.f90"
    REPO_BRANCH="master"
    REPO_URL="https://github.com/UK-MAC/CloverLeaf_CUDA"
    ;;
  omp-plain)
    REPO_DIR=cloverleaf_openmp_plain
    REPO_FILE="$REPO_DIR/src/clover_leaf.cpp"
    REPO_BRANCH="omp-plain"
    REPO_URL="https://github.com/UoB-HPC/cloverleaf_openmp_target"
    ;;
  omp-target)
    REPO_DIR=cloverleaf_openmp_target
    REPO_FILE="$REPO_DIR/src/clover_leaf.cpp"
    REPO_BRANCH="omp-target"
    REPO_URL="https://github.com/UoB-HPC/cloverleaf_openmp_target"
    ;;
  tbb)
    REPO_DIR=cloverleaf_tbb
    REPO_FILE="$REPO_DIR/src/clover_leaf.cpp"
    REPO_BRANCH="main"
    REPO_URL="https://github.com/UoB-HPC/cloverleaf_tbb"
    ;;
  sycl)
    REPO_DIR=cloverleaf_sycl
    REPO_FILE="$REPO_DIR/src/clover_leaf.cpp"
    REPO_BRANCH="master"
    REPO_URL="https://github.com/UoB-HPC/cloverleaf_sycl"
    ;;
  stdpar)
    REPO_DIR=cloverleaf_stdpar
    REPO_FILE="$REPO_DIR/src/clover_leaf.cpp"
    REPO_BRANCH="main"
    REPO_URL="https://github.com/UoB-HPC/cloverleaf_stdpar"
    ;;
  *)
    echo
    echo "Unsupported model '$1', no source repo available."
    exit 1
    ;;
  esac

  if [ ! -e "$REPO_FILE" ]; then
    if ! git clone -b "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  else
    (
      cd "$REPO_DIR"
      git fetch && git pull
    )
  fi

  export SRC_DIR="$PWD/$REPO_DIR"
}
