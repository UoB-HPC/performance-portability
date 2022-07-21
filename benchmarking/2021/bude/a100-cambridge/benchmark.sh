#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  USE_QUEUE=true
  USE_SLURM=true

  module load cmake-3.19.7-gcc-5.4-5gbsejo
  case "$COMPILER" in
    julia-1.6.2)
      export PATH="/home/hpclin2/julia-1.6.2/bin:$PATH"
    ;;
    gcc-8.4.0)
      module load cuda/11.2
      module load gcc/8

      # export LD_LIBRARY_PATH="/usr/local/software/cuda/11.2/include:$LD_LIBRARY_PATH"
      MAKE_OPTS="COMPILER=GNU TARGET=NVIDIA NV_FLAGS='-O3 --ptxas-options=-v -use_fast_math -gencode arch=compute_80,code=sm_80 -restrict'"
      export OMP_PROC_BIND=spread
      ;;  
    *)
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
      ;;
  esac

  case "$MODEL" in
    julia-ka)
      JULIA_ENTRY="src/KernelAbstractions.jl"
      JULIA_BACKEND="KernelAbstractions"
      ;;
    julia-cuda)
      JULIA_ENTRY="src/CUDA.jl"
      JULIA_BACKEND="CUDA"
      ;;
  esac

}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="gcc-8.4.0 julia-1.6.2"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="kokkos ocl julia-ka julia-cuda"
export DEFAULT_MODEL="kokkos"
export PLATFORM="a100-cambridge"

export KOKKOS_BACKEND="CUDA"
export KOKKOS_ARCH="AMPERE80"
export KOKKOS_WGSIZE="4"
# defaults to O3, don't add Ofast here as nvcc chokes
export KOKKOS_EXTRA_FLAGS="-march=native --use_fast_math"
export BASE_CMAKE_FLAGS="-DCUSTOM_SYSTEM_INCLUDE_FLAG=-I"

bash "$PLATFORM_DIR/../common.sh" "$@"
