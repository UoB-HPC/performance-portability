#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "babelstream" "milan"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
gcc-13.1)
  module load gcc/13.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
oneapi-2023.1)
  module load gcc/13.1.0
  load_oneapi "$HOME/intel/oneapi/setvars.sh"
  append_opts "-DCMAKE_C_COMPILER=icx"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
nvhpc-23.5)
  module load gcc/13.1.0 # for libatomic
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  case "$MODEL" in
  omp)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=zen3;-fast"
    ;;
  std-*)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-stdpar;-march=zen3;-fast"
    ;;
  esac
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON"
  append_opts "-DKokkos_ARCH_ZEN3=ON"
  BENCHMARK_EXE="kokkos-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-stream"
  ;;
tbb)
  append_opts "-DMODEL=tbb -DPARTITIONER=AUTO" # static doesn't work well for milan; use auto for comparison with std-*
  BENCHMARK_EXE="tbb-stream"
  ;;

std-data)
  append_opts "-DMODEL=std-data"
  BENCHMARK_EXE="std-data-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-stream"
  ;;
std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-stream"
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
  BENCHMARK_EXE="sycl-stream"
  ;;
sycl2020)
  append_opts "-DMODEL=sycl2020"
  append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
  BENCHMARK_EXE="sycl2020-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
