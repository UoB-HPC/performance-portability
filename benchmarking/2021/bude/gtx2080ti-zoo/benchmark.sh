#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  USE_QUEUE=true
  case "$COMPILER" in
    julia-1.6.2)
      module load julia/1.6.2
    ;;
    gcc-8.3)
      module load cmake/3.19.1
      module load gcc/8.3.0
      module load cuda/10.1
      MAKE_OPTS=''
      ;;
    dpcpp-2021.1-beta10)
      module load  cmake/3.14.5 
      loadOneAPI /nfs/projects/software/intel/oneapi/setvars.sh
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      # MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
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

export COMPILERS="gcc-10.1 gcc-8.3 icpx-2021.1-beta10 dpcpp-2021.1-beta10 computecpp-2.1.1 julia-1.6.2"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="kokkos omp-target sycl ocl julia-ka julia-cuda"
export DEFAULT_MODEL="kokkos"
export PLATFORM="gtx2080ti-zoo"

export KOKKOS_BACKEND="CUDA"
export KOKKOS_ARCH="TURING75"
export KOKKOS_WGSIZE="8"
# defaults to O3, don't add Ofast here as nvcc chokes
export KOKKOS_EXTRA_FLAGS="-march=native --use_fast_math"


bash "$PLATFORM_DIR/../common.sh" "$@"
