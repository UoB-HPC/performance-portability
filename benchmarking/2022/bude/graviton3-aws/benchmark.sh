#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "graviton3"

export USE_MAKE=false
export USE_SLURM=true

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
gcc-12.1)
  spack load gcc@12.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  # Nuke the entire flag because the default `-march=native` is broken and -mcpu=neoverse-v1 is broken too
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-march=armv8.4-a+rcpc+sve+profile;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
arm-22.0.1)
  spack load gcc@12.1.0
  spack load arm@22.0.1
  append_opts "-DCMAKE_C_COMPILER=armclang"
  append_opts "-DCMAKE_CXX_COMPILER=armclang++"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mcpu=neoverse-v1;-Ofast"
  append_opts "-DUSE_TBB=ON -DTBB_ENABLE_IPO=OFF" # IPO is broken in armclang

  export CXXFLAGS="--gcc-toolchain=$(dirname "$(which gcc)")/.."
  export LDFLAGS="--gcc-toolchain=$(dirname "$(which gcc)")/.."
  ;;
hipsycl-gcc)
  spack load gcc@12.1.0
  ;;
nvhpc-22.7)
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  # For -Mx, see https://forums.developer.nvidia.com/t/nvc-nvc-miscompiles-if-cosf-sinf-is-called/223954/2
  append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=neoverse-v1;-fast;-Mx,15,0x8" 
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  append_opts "-DKokkos_ARCH_NATIVE=ON"
  BENCHMARK_EXE="kokkos-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  ;;
omp-target)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  case "$COMPILER" in
  nvhpc-*)
    # cc isn't important here, so just pick the latest one
    append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=gpu;-gpu=cc80,fastmath"
    ;;
  *)
    append_opts "-DOFFLOAD=ON "
    ;;
  esac
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  BENCHMARK_EXE="sycl-bude"

  append_opts "-DCXX_EXTRA_FLAGS=-march=armv8.4-a+rcpc+sve+profile;-Ofast;-I$HOME/boost_1_80_0/install/include"
  case "$COMPILER" in
  hipsycl-gcc)
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    # append_opts "-DCXX_EXTRA_LIBRARIES=stdc++fs"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=$HOME/hipSYCL/install"
    ;;
  esac
  ;;

*) unknown_model ;;
esac

handle_exec
