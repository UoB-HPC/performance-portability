#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "a64fx"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
gcc-12.1)
  module load gcc/12.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCMAKE_BUILD_TYPE=RELEASE"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mcpu=a64fx;-Ofast"
  ;;
cce)
  module load cce cce-sve # must be in this order, cce-sve sets env for cce
  append_opts "-DCMAKE_C_COMPILER=cc"
  append_opts "-DCMAKE_CXX_COMPILER=CC"
  append_opts "-DCMAKE_BUILD_TYPE=RELEASE"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-Ofast"
  # DO NOT ADD `-mcpu=a64fX`, cce clang says no...
  ;;
hipsycl-gcc)
  # module load gcc/12.1.0
  ;;
nvhpc-22.7)
  # module unload cce-sve craype-arm-nsp1 craype cpe-cray # cray-libsci

  # module swap cce-sve cce

  export NVHPC_PATH="/home/br-tdeakin/nvhpc/22.7/arm/Linux_aarch64/22.7"

  # load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  # For -Mx, see https://forums.developer.nvidia.com/t/nvc-nvc-miscompiles-if-cosf-sinf-is-called/223954/2
  append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=native;-fast;-Mx,15,0x8"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  # append_opts "-DKokkos_ARCH_NATIVE=ON" # This kills CCE
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
    append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=ompt"
    ;;
  *)
    append_opts "-DOFFLOAD=ON "
    append_opts "-DCMAKE_BUILD_TYPE=RELEASE -DCXX_EXTRA_FLAGS=-Ofast -DCXX_EXTRA_LINK_FLAGS=-fopenmp=libomp"
    ;;
  esac
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  BENCHMARK_EXE="sycl-bude"
  case "$COMPILER" in

  hipsycl-gcc)
  module load boost/1.73.0/gcc-9.3
module load gcc/12.1.0
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    # append_opts "-DCXX_EXTRA_LIBRARIES=stdc++fs"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=/home/br-wlin/a64fx_hipsycl/hipSYCL/install/"
    append_opts "-DCXX_EXTRA_FLAGS=-Ofast"
    ;;
  esac
  ;;

*) unknown_model ;;
esac

handle_exec
