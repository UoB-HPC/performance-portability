#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

module load cmake/3.14.5
module load intel/neo/20.49.18626 

setup_env() {
  USE_QUEUE=false
  case "$COMPILER" in
    gcc-10.1)
      module load gcc/10.1.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      ;;
    icpx-2021.1)
      loadOneAPI /nfs/software/x86_64/intel/oneapi/2021.1/setvars.sh
      MAKE_OPTS='CC=icx CFLAGS="-fiopenmp -fopenmp-targets=spir64 -Ofast -march=native -DNUM_TD_PER_THREAD=4"'
      ;;
    dpcpp-2021.1)
      loadOneAPI /nfs/software/x86_64/intel/oneapi/2021.1/setvars.sh
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
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
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="gcc-10.1 icpx-2021.1 dpcpp-2021.1 computecpp-2.3.0"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp omp-target sycl kokkos"
export DEFAULT_MODEL="omp-target"
export PLATFORM="irispro580-zoo"

export KOKKOS_BACKEND="OPENMPTARGET"
export KOKKOS_ARCH="INTEL_GEN"
export KOKKOS_WGSIZE="16"
export KOKKOS_EXTRA_FLAGS="-Ofast"

bash "$PLATFORM_DIR/../common.sh" "$@"
