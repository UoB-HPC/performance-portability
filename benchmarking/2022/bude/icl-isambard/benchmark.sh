#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "icl"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
gcc-12.1)
  module load gcc/12.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
oneapi-2022.2)
  module load gcc/12.1.0
  load_oneapi "$HOME/intel/oneapi/setvars.sh"
  append_opts "-DCMAKE_C_COMPILER=icx"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
nvhpc-22.7)
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  case "$MODEL" in
  omp)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=skylake-avx512;-fast"
    ;;
  std-*)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-stdpar;-march=skylake-avx512;-fast"
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
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  case "$COMPILER" in
  nvhpc-*)
    #append_opts "-DKokkos_ARCH_ICX=ON"           # Kokkos needs a patch from master for ICX/ICL
    export CXXFLAGS="-march=skylake-avx512 -fast"
    ;;
  *)
    #append_opts "-DKokkos_ARCH_ICX=ON"            # Kokkos needs a patch from master for ICX/ICL
    export CXXFLAGS="-march=icelake-server -Ofast"
    ;;
  esac
  BENCHMARK_EXE="kokkos-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  ;;
tbb)
  append_opts "-DMODEL=tbb"
  BENCHMARK_EXE="tbb-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges-dplomp)
  append_opts "-DMODEL=std-ranges -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
