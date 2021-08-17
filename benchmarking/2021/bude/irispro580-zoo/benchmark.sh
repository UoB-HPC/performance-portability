#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

module load cmake/3.14.5
module load intel/neo/20.49.18626

setup_env() {
  USE_QUEUE=true
  case "$COMPILER" in
    julia-1.6.2)
      module load julia/1.6.2
      ;;
    gcc-10.1)
      module load gcc/10.1.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      ;;
    gcc-8.3)
      module load gcc/8.3.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      ;;  
    icpx-2021.1)
      loadOneAPI /nfs/software/x86_64/intel/oneapi/2021.1/setvars.sh
      MAKE_OPTS='TARGET=INTEL TD_PER_THREAD=4'
      ;;
    dpcpp-2021.1)
      loadOneAPI /nfs/software/x86_64/intel/oneapi/2021.1/setvars.sh

      CL_HEADER_DIR="$PWD/OpenCL-Headers-2020.06.16"
      if [ ! -d "$CL_HEADER_DIR" ]; then
        wget https://github.com/KhronosGroup/OpenCL-Headers/archive/v2020.06.16.tar.gz
        tar -xf v2020.06.16.tar.gz
      fi
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP -DCXX_EXTRA_FLAGS=-I$CL_HEADER_DIR"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      ;;
    computecpp-2.3.0)
      module load gcc/10.1.0
      loadOneAPI /nfs/software/x86_64/intel/oneapi/2021.1/setvars.sh # for the Intel OpenCL libs
      module load computecpp/2.3.0
      MAKE_OPTS=" -DSYCL_RUNTIME=COMPUTECPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      MAKE_OPTS+=" -DComputeCpp_DIR=$(findComputeCpp)"
      MAKE_OPTS+=" -DOpenCL_LIBRARY=$(findOneAPIlibOpenCL)"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    *)
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
      ;;
  esac

  case "$MODEL" in
    julia-oneapi)
      JULIA_ENTRY="src/oneAPI.jl"
      JULIA_BACKEND="oneAPI"
      ;;
      ocl)
          module load khronos/opencl/headers
          module load khronos/opencl/icd-loader
          ;;
    esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="gcc-10.1 gcc-8.3 icpx-2021.1 dpcpp-2021.1 computecpp-2.3.0 julia-1.6.2"
export DEFAULT_COMPILER="gcc-10.1"
export MODELS="omp omp-target ocl sycl kokkos julia-oneapi"
export DEFAULT_MODEL="ocl"
export PLATFORM="irispro580-zoo"

export OCL_WGSIZE=128

export KOKKOS_BACKEND="OPENMPTARGET"
export KOKKOS_ARCH="INTEL_GEN"
export KOKKOS_WGSIZE="16"
export KOKKOS_EXTRA_FLAGS="-Ofast -fiopenmp -fopenmp-targets=spir64"

bash "$PLATFORM_DIR/../common.sh" "$@"
