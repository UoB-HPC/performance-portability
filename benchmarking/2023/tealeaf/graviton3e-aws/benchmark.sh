#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "graviton3e"

export USE_MAKE=false
export USE_SLURM=true

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
gcc-13.1)
  spack load gcc@13.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-march=armv8.4-a+rcpc+sve+profile;-mtune=neoverse-v1;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
acfl-23.04.1)
  spack load gcc@13.1.0
  spack load acfl@23.04.1
  append_opts "-DCMAKE_C_COMPILER=armclang"
  append_opts "-DCMAKE_CXX_COMPILER=armclang++"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mcpu=neoverse-v1;-mtune=neoverse-v1;-Ofast"
  append_opts "-DUSE_TBB=ON -DTBB_ENABLE_IPO=OFF" # IPO is broken in armclang

  export CXXFLAGS="--gcc-toolchain=$(dirname "$(which gcc)")/.."
  export LDFLAGS="--gcc-toolchain=$(dirname "$(which gcc)")/.."
  ;;
nvhpc-23.5)
  spack load nvhpc@23.5
  append_opts "-DCMAKE_C_COMPILER=nvc"
  append_opts "-DCMAKE_CXX_COMPILER=nvc++"
  # See https://docs.nvidia.com/hpc-sdk/archive/23.5/hpc-sdk-release-notes/index.html for SVE additions
  case "$MODEL" in
  omp)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-tp=neoverse-v1;-fast"
    ;;
  std-*)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-stdpar;-tp=neoverse-v1;-fast"
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
  # append_opts "-DKokkos_ARCH_NATIVE=ON"
  BENCHMARK_EXE="kokkos-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-stream"
  ;;
tbb)
  append_opts "-DMODEL=tbb -DPARTITIONER=STATIC"
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
std-ranges-dplomp)
  append_opts "-DMODEL=std-ranges -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-ranges-stream"
  ;;

*) unknown_model ;;
esac

handle_exec
