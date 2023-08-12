#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "graviton3e" "${INPUT_BM:-}"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_MPI=ON -DENABLE_PROFILING=ON -DMPI_HOME=/opt/amazon/openmpi/"

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
hipsycl-7b2e459)
  export FI_EFA_FORK_SAFE=1
  spack load gcc@13.1.0
  export LD_LIBRARY_PATH="$(spack location -i gcc@13.1.0)/lib64:${LD_LIBRARY_PATH:-}"
  export HIPSYCL_DIR="$HOME/software/aarch64/hipsycl/7b2e459"
  ;;
nvhpc-23.5)
  spack load nvhpc@23.5
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=nvc"
  append_opts "-DCMAKE_CXX_COMPILER=nvc++"
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
  BENCHMARK_EXE="kokkos-tealeaf"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-tealeaf"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-tealeaf"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="omp.accelerated"
    export HIPSYCL_DEBUG_LEVEL=1 # quieter during runtime
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=$HIPSYCL_DIR/bin/syclcc"
    export CXXFLAGS="--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    append_opts "-DCXX_EXTRA_FLAGS=-mcpu=neoverse-v1;-mtune=neoverse-v1;-Ofast;--opensycl-stdpar;--opensycl-stdpar-unconditional-offload;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    ;;
  esac
  ;;
std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-tealeaf"
  ;;
sycl-acc)
  append_opts "-DMODEL=sycl-acc"
  BENCHMARK_EXE="sycl-acc-tealeaf"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="omp.accelerated"
    export HIPSYCL_DEBUG_LEVEL=1 # quieter during runtime
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=$HIPSYCL_DIR"
    append_opts "-DCXX_EXTRA_FLAGS=-mcpu=neoverse-v1;-mtune=neoverse-v1;-Ofast;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    append_opts "-DUSE_HOSTTASK=OFF"
    ;;
  *) unknown_model ;;
  esac
  ;;
sycl-usm)
  append_opts "-DMODEL=sycl-usm"
  BENCHMARK_EXE="sycl-usm-tealeaf"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="omp.accelerated"
    export HIPSYCL_DEBUG_LEVEL=1 # quieter during runtime
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=$HIPSYCL_DIR"
    append_opts "-DCXX_EXTRA_FLAGS=-mcpu=neoverse-v1;-mtune=neoverse-v1;-Ofast;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    append_opts "-DUSE_HOSTTASK=OFF"
    ;;
  *) unknown_model ;;
  esac
  ;;
*) unknown_model ;;
esac

handle_exec
