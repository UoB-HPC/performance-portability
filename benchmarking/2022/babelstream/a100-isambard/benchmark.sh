#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "babelstream" "a100"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
nvhpc-22.7)
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  export CUDA_ROOT="$NVHPC_PATH/cuda"
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_CUDA=ON -DKokkos_CXX_STANDARD=17 -DKokkos_ENABLE_CUDA_LAMBDA=ON"
  append_opts "-DKokkos_ARCH_AMPERE80=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  BENCHMARK_EXE="kokkos-stream"
  ;;
cuda)
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=$NVHPC_PATH/compilers/bin/nvcc"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCUDA_ARCH=sm_80"
  BENCHMARK_EXE="cuda-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=gpu;-gpu=cc80"
  BENCHMARK_EXE="omp-stream"
  ;;
std-data)
  append_opts "-DMODEL=std-data"
  append_opts "-DNVHPC_OFFLOAD=cc80"
  BENCHMARK_EXE="std-data-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  append_opts "-DNVHPC_OFFLOAD=cc80"
  BENCHMARK_EXE="std-indices-stream"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  append_opts "-DNVHPC_OFFLOAD=cc80"
  BENCHMARK_EXE="std-ranges-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
