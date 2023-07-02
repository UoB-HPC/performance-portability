#!/bin/bash

set -eu

module purge
module load rhel8/slurm
# module unload rhel8/default-icl
### XXX This must be ran from an IceLake node, the head node's GCC seems to default to a bad arch???
export RDS_ROOT="/rds/user/hpclin2/hpc-work"
source "$RDS_ROOT/spack/share/spack/setup-env.sh"

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "a100_80g"

export USE_MAKE=false
export USE_SLURM=true

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
nvhpc-23.5)
  module load gcc/11 # just get something that has libatomic, 13.1 is too new for nvcc
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  # see https://docs.hpc.cam.ac.uk/hpc/user-guide/a100.html, native tp will almost certainly be wrong as it might generate AVX512
  ;;
oneapi-2023.1)
  load_nvhpc # we need this for CUDA
  module load gcc/11
  load_oneapi "$RDS_ROOT/intel/oneapi/setvars.sh" --include-intel-llvm
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
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3" # CSD3  A100s are hosted on a EPYC 7763
  BENCHMARK_EXE="kokkos-stream"
  ;;
cuda)
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=$NVHPC_PATH/compilers/bin/nvcc"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCUDA_ARCH=sm_80"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3" # CSD3  A100s are hosted on a EPYC 7763
  BENCHMARK_EXE="cuda-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=gpu;-gpu=cc80"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mp=gpu;-gpu=cc80;-O3;-tp=zen3" # CSD3 A100s are hosted on a EPYC 7763
  BENCHMARK_EXE="omp-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  case "$COMPILER" in
  nvhpc-*)
    append_opts "-DNVHPC_OFFLOAD=cc80"
    append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-stdpar;-gpu=cc80;-O3;-tp=zen3" # CSD3 A100s are hosted on a EPYC 7763
    ;;
  oneapi-*)
    append_opts "-DUSE_ONEDPL=DPCPP"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="std-indices-stream"
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
  BENCHMARK_EXE="sycl-stream"
  ;;
sycl2020)
  append_opts "-DMODEL=sycl2020"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
  BENCHMARK_EXE="sycl2020-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
