#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  USE_QUEUE=true
  if ! grep -q bristol/modules/ <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules/modulefiles
  fi

  module load cmake/3.18.3

  case "$COMPILER" in
    julia-1.6.2)
      # module load cuda11.1/toolkit/11.1.1
      module load julia/julia-1.6.2
    ;;
    cce-9.1-classic)
      module load PrgEnv-cray
      module swap cce cce/9.1.1-classic
      module load craype-accel-nvidia70
      MAKE_OPTS='COMPILER=CRAY'
      ;;
    cce-10.0)
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
      ;;
    gcc-8.1)
      module load gcc/8.1.0
      # module load craype-accel-nvidia70
      module load cuda11.1/toolkit/11.1.1
      # module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
      ;;
    gcc-9.3)
      module load gcc/9.3.0
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
      ;;
    llvm-10.0)
      module load cuda10.1/toolkit/10.1.243
      module load llvm/10.0
      module load gcc/9.3.0
      MAKE_OPTS='CC=clang'
      ;;
    pgi-19.10)
      module load cuda10.2/toolkit/10.2.89
      module load pgi/compiler/19.10
      MAKE_OPTS='COMPILER=PGI'
      ;;
    oneapi-2021.1)
      # FIXME does not work; apparently oneAPI 2021.1 shipped without CUDA support(!?)
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89
      module load 10.2.0
      loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/2021.1/setvars.sh
      export CPATH="" # https://github.com/intel/llvm/issues/2617
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=32"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=--gcc-toolchain=$(findGCC)"
      ;;
    hipsycl-cf71460)
      # module load cuda10.1/toolkit/10.1.243 # loading this has no effect, hipSYCL needs direct path
      module load gcc/10.2.0 boost/1.73.0/gcc-10.2.0 hipsycl/cf71460/gcc-10.2.0
      module load llvm/10.0 # hipSYCL adds -lomp so we need this on path
      local CUDA_TOOLKIT_LIB="/cm/shared/apps/cuda10.1/toolkit/10.1.243/lib64"
      HIPSYCL_CUDA_LINK_LINE="-Wl,-rpath=$CUDA_TOOLKIT_LIB -L$CUDA_TOOLKIT_LIB -lcudart"
      HIPSYCL_CUDA_LINK_LINE+=" $BOOST_ROOT/lib/libboost_context.so"
      HIPSYCL_CUDA_LINK_LINE+=" $BOOST_ROOT/lib/libboost_fiber.so"
      export HIPSYCL_CUDA_LINK_LINE
      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL-NEXT"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=16"
      MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$(findhipSYCL)"
      MAKE_OPTS+=" -DHIPSYCL_PLATFORM=cuda -DHIPSYCL_GPU_ARCH=sm_70"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=--gcc-toolchain=$(findGCC)"
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
      omp-target)
        MAKE_OPTS+=" TARGET=NVIDIA"
        ;;
  esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="cce-9.1-classic cce-10.0 gcc-8.1 gcc-9.3 llvm-10.0 pgi-19.10 hipsycl-cf71460 oneapi-2021.1 julia-1.6.2"
export DEFAULT_COMPILER="gcc-9.3"
export MODELS="ocl cuda omp-target acc kokkos sycl julia-cuda julia-ka"
export DEFAULT_MODEL="ocl"
export PLATFORM="v100-isambard"

export KOKKOS_BACKEND="CUDA"
export KOKKOS_ARCH="VOLTA70"
export KOKKOS_WGSIZE="2"
# defaults to O3, don't add Ofast here as nvcc chokes
export KOKKOS_EXTRA_FLAGS="-march=native"

bash "$PLATFORM_DIR/../common.sh" "$@"


