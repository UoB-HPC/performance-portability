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
    llvm-trunk)
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89
      module load llvm/trunk
      MAKE_OPTS='COMPILER=CLANG TARGET=NVIDIA EXTRA_FLAGS="-Xopenmp-target -march=sm_70"'
      ;;
    gcc-8.1)
      module load gcc/8.1.0
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS="COMPILER=GNU"
      case "$MODEL" in
        cuda)
          MAKE_OPTS+=" -j20"
          MAKE_OPTS+=' NV_ARCH=VOLTA CODE_GEN_VOLTA="-gencode arch=compute_70,code=sm_70"'
          ;;
        *)
          MAKE_OPTS+=" TARGET=NVIDIA"
          ;;
      esac
      ;;
    gcc-10.2)
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89
      module load openmpi/4.0.4/gcc-9.3
      module swap gcc/9.3.0 gcc/10.2.0
      MAKE_OPTS='COMPILER=GNU MPI_COMPILER=mpif90 C_MPI_COMPILER=mpicc'
      MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
      MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
      ;;  
    cce-10.0)
      module load gcc/8.2.0 # for libstdc++ only
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89

      # ARRAY
      # export OFFLOAD_FLAGS="-fopenmp-targets=nvptx64 -Xopenmp-target -march=sm_70"
      MAKE_OPTS=(
        "-DCMAKE_C_COMPILER=cc" 
        "-DCMAKE_CXX_COMPILER=CC" 
        "-DOMP_OFFLOAD_FLAGS='-fopenmp-targets=nvptx64 -Xopenmp-target -march=sm_70'"
        "-DOMP_ALLOW_HOST=OFF"
       )
      ;;  
    pgi-19.10)
      module load pgi/compiler/19.10
      MAKE_OPTS='COMPILER=PGI TARGET=VOLTA'
      ;;
    hipsycl)
      module load hipsycl/jul-8-20
      MAKE_OPTS="COMPILER=HIPSYCL TARGET=NVIDIA ARCH=sm_70 SYCL_SDK_DIR=/lustre/projects/bristol/modules-power/hipsycl/jul-8-20"
      ;;
    *)
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
      ;;
  esac
 
  case "$MODEL" in
      omp-target)
         # MAKE_OPTS is an array here, don't touch it
        ;;
      ocl)
        MAKE_OPTS+=" USE_OPENCL=1"
        MAKE_OPTS+=' COPTIONS="-std=c++98 -DCL_TARGET_OPENCL_VERSION=110 -DOCL_IGNORE_PLATFORM"'
        MAKE_OPTS+=' OPTIONS="-lstdc++ -cpp -lOpenCL"'
        MAKE_OPTS+=" OCL_VENDOR=NVIDIA" 
        MAKE_OPTS+=" OCL_LIB_NVIDIA_INC=$(fetchCLHeader)"
        # MAKE_OPTS+=" OCL_NVIDIA_LIB=-L$(findOneAPIlibOpenCL)"
      ;;
  esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="cce-10.0 gcc-8.1 gcc-10.2 gcc-9.3 llvm-10.0 pgi-19.10 hipsycl-cf71460 oneapi-2021.1"
export DEFAULT_COMPILER="gcc-9.3"
export MODELS="ocl cuda omp-target acc kokkos sycl"
export DEFAULT_MODEL="ocl"
export PLATFORM="v100-isambard"

export KOKKOS_BACKEND="CUDA"
export KOKKOS_ARCH="VOLTA70"
# defaults to O3, don't add Ofast here as nvcc chokes
export KOKKOS_EXTRA_FLAGS="-march=native"

bash "$PLATFORM_DIR/../common.sh" "$@"


