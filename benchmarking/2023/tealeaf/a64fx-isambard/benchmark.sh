#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "a64fx"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
gcc-13.1)
  module load gcc/13.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mcpu=a64fx;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
cce-14.0.1) # XXX does not work with std-indices
  # module load gcc/13.1.0
  module load cce/14.0.1
  append_opts "-DCMAKE_C_COMPILER=cc"
  append_opts "-DCMAKE_CXX_COMPILER=CC"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-Ofast"
  append_opts "-DUSE_TBB=ON"
  # DO NOT ADD `-mcpu=a64fX`, cce clang says no...
  ;;
acfl-23.04.1)
  module use /home/br-wlin/arm-compiler-for-linux_23.04.1_RHEL-8/modulefiles
  module load acfl/23.04.1
  append_opts "-DCMAKE_C_COMPILER=armclang"
  append_opts "-DCMAKE_CXX_COMPILER=armclang++"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mcpu=a64fx;-mtune=a64fx;-Ofast"
  append_opts "-DUSE_TBB=ON -DTBB_ENABLE_IPO=OFF" # IPO is broken in armclang
  ;;
hipsycl-gcc)
  # module load gcc/12.1.0
  ;;
nvhpc-23.5)
  # module unload cce-sve craype-arm-nsp1 craype cpe-cray # cray-libsci
  # module swap cce-sve cce
  # export NVHPC_PATH="/home/br-tdeakin/nvhpc/23.5/arm/Linux_aarch64/23.5"
  module load gcc/12.1.0 # just get something that has libatomic, 13.1 is too new for nvcc
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=native;-fast"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON"
  # append_opts "-DKokkos_ARCH_NATIVE=ON" # This kills CCE
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
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-stream"
  ;;
std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-stream"
  ;;
# omp-target)
#   append_opts "-DMODEL=omp"
#   BENCHMARK_EXE="omp-stream"
#   case "$COMPILER" in
#   nvhpc-*)
#     # cc isn't important here, so just pick the latest one
#     append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=ompt"
#     ;;
#   *)
#     append_opts "-DOFFLOAD=ON "
#     append_opts "-DCMAKE_BUILD_TYPE=RELEASE -DCXX_EXTRA_FLAGS=-Ofast -DCXX_EXTRA_LINK_FLAGS=-fopenmp=libomp"
#     ;;
#   esac
#   ;;
sycl)
  append_opts "-DMODEL=sycl"
  BENCHMARK_EXE="sycl-stream"
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
