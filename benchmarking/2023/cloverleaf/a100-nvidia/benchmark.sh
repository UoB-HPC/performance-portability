#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "a100_80g" "${INPUT_BM:-}_${STAGE:-}"

export USE_MAKE=false
export USE_SLURM=false
export NVHPC_PATH="/opt/nvidia/hpc_sdk/Linux_x86_64/23.5"

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_MPI=ON -DENABLE_PROFILING=ON"

case "$COMPILER" in
nvhpc-23.5)
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  ;;
oneapi-2023.2)
  load_oneapi "/opt/intel/oneapi/setvars.sh" --include-intel-llvm
  append_opts "-DCMAKE_C_COMPILER=clang"
  append_opts "-DCMAKE_CXX_COMPILER=clang++"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  export CUDA_ROOT="$NVHPC_PATH/cuda"
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_CUDA=ON -DKokkos_ENABLE_CUDA_LAMBDA=ON"
  append_opts "-DKokkos_ARCH_AMPERE80=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3"
  BENCHMARK_EXE="kokkos-cloverleaf"
  ;;
cuda)
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=$NVHPC_PATH/compilers/bin/nvcc"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCUDA_ARCH=sm_80"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3"
  BENCHMARK_EXE="cuda-cloverleaf"
  ;;
omp)
  append_opts "-DMODEL=omp-target"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=gpu;-gpu=cc80"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mp=gpu;-gpu=cc80;-O3;-tp=zen3"
  BENCHMARK_EXE="omp-target-cloverleaf"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  case "$COMPILER" in
  nvhpc-*)
    append_opts "-DNVHPC_OFFLOAD=cc80"
    append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-stdpar;-gpu=cc80;-O3;-tp=zen3"
    ;;
  oneapi-*)
    append_opts "-DUSE_ONEDPL=DPCPP"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="std-indices-cloverleaf"
  ;;
sycl-usm)
  append_opts "-DMODEL=sycl-usm"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DUSE_HOSTTASK=ON"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
  BENCHMARK_EXE="sycl-usm-cloverleaf"
  ;;
sycl-acc)
  append_opts "-DMODEL=sycl-acc"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DUSE_HOSTTASK=ON"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
  BENCHMARK_EXE="sycl-acc-cloverleaf"
  ;;
*) unknown_model ;;
esac

handle_exec
