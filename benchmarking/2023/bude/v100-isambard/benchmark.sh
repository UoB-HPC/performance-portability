#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "v100"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

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
  append_opts "-DKokkos_ARCH_VOLTA70=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  append_opts "-DCXX_EXTRA_FLAGS=-O3;--use_fast_math"
  BENCHMARK_EXE="kokkos-bude"
  ;;
cuda)
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=$NVHPC_PATH/compilers/bin/nvcc"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  # fastmath enabled by default
  append_opts "-DCUDA_ARCH=sm_70"
  BENCHMARK_EXE="cuda-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=gpu;-gpu=cc70,fastmath"
  BENCHMARK_EXE="omp-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  append_opts "-DNVHPC_OFFLOAD=cc70"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  append_opts "-DNVHPC_OFFLOAD=cc70"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
