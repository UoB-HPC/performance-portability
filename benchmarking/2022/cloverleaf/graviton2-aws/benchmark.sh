#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "graviton2"

export USE_MAKE=false
export USE_SLURM=true

# Set up the environment
case "$COMPILER" in
gcc-12.1)
  spack load gcc@12.1.0
  module load openmpi
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DUSE_TBB=ON"
  cxx_extra_flags="-mcpu=neoverse-n1;-Ofast"
  ;;
nvhpc-22.7)
  module load openmpi
  load_nvhpc
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  cxx_extra_flags="--restrict;-target=multicore;-march=neoverse-n1;-fast;-Mllvm-fast;-Ktrap=none;-Minfo=accel"
  ;;
*) unknown_compiler ;;
esac

case "$MODEL" in
omp)
  fetch_src "omp-plain"
  case "$COMPILER" in
  nvhpc-*) cxx_extra_flags="$cxx_extra_flags;-Minfo=mp" ;;
  *) ;;
  esac
  ;;
tbb)
  fetch_src "tbb"
  ;;
std-indices)
  fetch_src "stdpar"
  case "$COMPILER" in
  nvhpc-*) cxx_extra_flags="$cxx_extra_flags;-stdpar;-Minfo=stdpar" ;;
  *) ;;
  esac
  ;;

std-indices-dplomp)
  fetch_src "stdpar"
  case "$COMPILER" in
  nvhpc-*) echo "$COMPILER with dplomp is unsupported" && exit 1 ;;
  *) append_opts "-DUSE_ONEDPL=OPENMP" ;;
  esac
  ;;

*) unknown_model ;;
esac

append_opts "-DCXX_EXTRA_FLAGS=${cxx_extra_flags}"

export BENCHMARK_EXE="clover_leaf"

handle_exec
