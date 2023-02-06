#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "v100"

case "$COMPILER" in
nvhpc-22.7)
  module load openmpi
  load_nvhpc
  ;;
*) unknown_compiler ;;
esac

case "$MODEL" in
kokkos)
  export USE_MAKE=false
  fetch_src "kokkos"
  prime_kokkos
  export CUDA_ROOT="$NVHPC_PATH/cuda"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_CUDA=ON -DKokkos_CXX_STANDARD=17 -DKokkos_ENABLE_CUDA_LAMBDA=ON"
  append_opts "-DKokkos_ARCH_VOLTA70=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  append_opts "-DCXX_EXTRA_FLAGS=-O3;--use_fast_math"
  ;;
cuda)
  export USE_MAKE=true
  module load gcc/9.3.0
  fetch_src "cuda"
  export PATH="$NVHPC_PATH/compilers/bin/:$PATH"
  export LD_LIBRARY_PATH="$NVHPC_PATH/cuda/lib64:$LD_LIBRARY_PATH"

  append_opts 'COMPILER=GNU NV_ARCH=VOLTA CODE_GEN_VOLTA="-gencode arch=compute_70,code=sm_70 -O3 --use_fast_math"'
  append_opts "CUDA_HOME=$NVHPC_PATH/cuda"
  ;;
omp)
  export USE_MAKE=false
  fetch_src "omp-target"
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  append_opts "-DOMP_OFFLOAD_FLAGS=-target=gpu;-gpu=cc70,fastmath;--restrict;-fast;-Mllvm-fast;-Ktrap=none;-Minfo=accel;-Minfo=mp"
  ;;
std-indices)
  export USE_MAKE=false
  fetch_src "stdpar"
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  append_opts "-DNVHPC_OFFLOAD=cc70,fastmath -DCXX_EXTRA_FLAGS=-fast -DSERIAL_COPY_CTOR=ON"
  ;;
*) unknown_model ;;
esac

export BENCHMARK_EXE="clover_leaf"

handle_exec
