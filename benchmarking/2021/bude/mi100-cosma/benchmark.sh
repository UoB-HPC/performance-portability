#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

module load cmake/3.18.1

setup_env() {
USE_QUEUE=false
case "$COMPILER" in
  julia-1.6.2)
    export PATH=/cosma/home/do009/dc-lin2/julia-1.6.2/bin:$PATH
    ;;
  aomp-11.12)
    module load aomp/11.12
    MAKE_OPTS='CC=aomp'
    ;;
  gcc-10.2)
    module use /cosma/home/do006/dc-deak1/bin/modulefiles
    module load gcc/10.2.0
    MAKE_OPTS="CC=gcc"
    export LIBRARY_PATH=$LIBRARY_PATH:/opt/rocm/opencl/lib
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/opencl/lib
    export CPATH=$CPATH:/opt/rocm/opencl/include
    # export LD_LIBRARY_PATH="/opt/rocm/lib/:$LD_LIBRARY_PATH"
    ;;  
  hipcc)
    module use /cosma/home/do006/dc-deak1/bin/modulefiles
    module load gcc/10.2.0
    MAKE_OPTS="COMPILER=HIPCC"

    export KOKKOS_CXX_EXTRA_FLAGS="--gcc-toolchain=$(findGCC)"
    export KOKKOS_EXTRA_FLAGS="-Ofast;-march=native;--gcc-toolchain=$(findGCC)"
  ;;
  hipsycl-cff515c)

    module load gcc/10.1.0 boost/1.73.0/gcc-10.1.0 hipsycl/cff515c/gcc-10.1.0

    export HIPSYCL_ROCM_PATH="/opt/rocm-3.10.0"
    local ROCM_TOOLKIT_LIB="$HIPSYCL_ROCM_PATH/lib"
    local ROCM_LLVM="$HIPSYCL_ROCM_PATH/llvm"
    HIPSYCL_ROCM_LINK_LINE=" -Wl,-rpath=$ROCM_TOOLKIT_LIB -L$ROCM_TOOLKIT_LIB -lamdhip64 -lhsa-runtime64"
    HIPSYCL_ROCM_LINK_LINE+=" $BOOST_ROOT/lib/libboost_context.so"
    HIPSYCL_ROCM_LINK_LINE+=" $BOOST_ROOT/lib/libboost_fiber.so"
    export HIPSYCL_ROCM_LINK_LINE
    export LD_LIBRARY_PATH=$ROCM_LLVM/lib/:$LD_LIBRARY_PATH # for libomp

    MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL-NEXT"
    MAKE_OPTS+=" -DNUM_TD_PER_THREAD=8"
    MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$(findhipSYCL)"
    MAKE_OPTS+=" -DHIPSYCL_PLATFORM=rocm -DHIPSYCL_GPU_ARCH=gfx906"
    MAKE_OPTS+=" -DCMAKE_C_COMPILER=$ROCM_LLVM/bin/clang -DCMAKE_CXX_COMPILER=$ROCM_LLVM/bin/clang++"
    MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=--gcc-toolchain=$(findGCC)" # need this for libstdc++
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
  julia-amdgpu)
    JULIA_ENTRY="src/AMDGPU.jl"
    JULIA_BACKEND="AMDGPU"
    ;;
  hip)
    MAKE_OPTS='USE_HIP=1'
    ;;
  omp-target)
    MAKE_OPTS+=" TARGET=AMD"
    case "$COMPILER" in
      aomp-*)
        MAKE_OPTS+=" TD_PER_THREAD=1"
        ;;
      gcc-*)
        MAKE_OPTS+=" TD_PER_THREAD=4"
        ;;
    esac
    ;;
esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="aomp-11.12 gcc-10.2 hipcc hipsycl-cff515c julia-1.6.2"
export DEFAULT_COMPILER="gcc-10.2"
export MODELS="ocl kokkos omp-target sycl hip julia-ka julia-amdgpu"
export DEFAULT_MODEL="kokkos"
export PLATFORM="mi100-cosma"

export OCL_WGSIZE=128

export KOKKOS_BACKEND="HIP"
export KOKKOS_ARCH="VEGA908"
export KOKKOS_WGSIZE="4"
export KOKKOS_EXTRA_FLAGS="-Ofast;-march=native"


bash "$PLATFORM_DIR/../common.sh" "$@"
