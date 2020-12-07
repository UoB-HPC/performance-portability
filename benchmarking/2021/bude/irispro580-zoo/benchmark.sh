#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  USE_QUEUE=false
  case "$COMPILER" in
    gcc-10.1)
      module load gcc/10.1.0
      KOKKOS_ARCH="SKX"
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      ;;
    icpx-2021.1-beta10)
      # module load gcc/8.3.0
      loadOneAPI /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh
      # loadOneAPI /nfs/projects/software/intel/oneapi/setvars.sh
      MAKE_OPTS='CC=icx CFLAGS="-fiopenmp -fopenmp-targets=spir64 -Ofast -march=native"'
      ;;
    dpcpp-2021.1-beta10)
      module load  cmake/3.14.5
      loadOneAPI /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh
      # loadOneAPI /nfs/projects/software/intel/oneapi/setvars.sh
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      # MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    computecpp-2.1.1)
      module load gcc/10.1.0 cmake/3.14.5
      # loadOneAPI /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh # for the Intel OpenCL libs
      loadOneAPI /nfs/projects/software/intel/oneapi/setvars.sh
      module load computecpp/2.1.1
      COMPUTECPP_PATH="$(realpath "$(dirname "$(which compute++)")"/..)"
      INTEL_OCL_LIB_PATH="$(realpath "$(dirname "$(which icc)")"/../..)/lib/libOpenCL.so.1"
      echo "Using COMPUTECPP_PATH=${COMPUTECPP_PATH}"
      echo "Using INTEL_OCL_LIB_PATH=${INTEL_OCL_LIB_PATH}"
      MAKE_OPTS=" -DSYCL_RUNTIME=COMPUTECPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      MAKE_OPTS+=" -DComputeCpp_DIR=$COMPUTECPP_PATH"
      MAKE_OPTS+=" -DOpenCL_LIBRARY=${INTEL_OCL_LIB_PATH}"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    *)
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
      ;;
  esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="gcc-10.1 icpx-2021.1-beta10 dpcpp-2021.1-beta10 computecpp-2.1.1"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp omp-target sycl"
export DEFAULT_MODEL="omp-target"
export PLATFORM="irispro580-zoo"

bash "$PLATFORM_DIR/../common.sh" "$@"
