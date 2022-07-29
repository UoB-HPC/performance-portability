#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "a100"

case "$COMPILER" in
nvhpc-22.5)
  module load openmpi
  load_nvhpc
  ;;
*) unknown_compiler ;;
esac

case "$MODEL" in
cuda)
  export USE_MAKE=true
  module load gcc/9.3.0
  fetch_src "cuda"
  export PATH="$NVHPC_PATH/compilers/bin/:$PATH"
  export LD_LIBRARY_PATH="$NVHPC_PATH/cuda/lib64:$LD_LIBRARY_PATH"

  append_opts 'COMPILER=GNU NV_ARCH=VOLTA CODE_GEN_VOLTA="-gencode arch=compute_80,code=sm_80"'
  append_opts "CUDA_HOME=$NVHPC_PATH/cuda"
  ;;
omp)
  export USE_MAKE=false
  fetch_src "omp-target"
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  append_opts "-DOMP_OFFLOAD_FLAGS=-target=gpu;-gpu=cc80;--restrict;-fast;-Mllvm-fast;-Ktrap=none;-Minfo=accel;-Minfo=mp"
  ;;
std-indices)
  export USE_MAKE=false
  fetch_src "stdpar"
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  append_opts "-DNVHPC_OFFLOAD=cc80 -DCXX_EXTRA_FLAGS=-fast -DSERIAL_COPY_CTOR=ON"
  ;;
*) unknown_model ;;
esac

export BENCHMARK_EXE="clover_leaf"

handle_exec
