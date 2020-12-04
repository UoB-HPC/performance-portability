#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  if ! grep -q bristol/modules/ <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules/modulefiles
  fi

  module load cmake/3.18.3

  case "$COMPILER" in
    cce-10.0)
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      module swap craype-{broadwell,x86-skylake}
      MAKE_OPTS='COMPILER=CLANG CC=cc ARCH=skylake-avx512'
      ;;
    gcc-9.3)
      module load gcc/9.3.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      ;;
    gcc-10.2)
      module load gcc/10.2.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      ;;
    intel-2019)
      module load intel-parallel-studio-xe/compilers/64/2019u4/19.0.4
      MAKE_OPTS='COMPILER=INTEL ARCH=skylake-avx512'
      ;;
    oneapi-2021.1-beta10)
      module load gcc/8.2.0
      loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/setvars.sh
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=--gcc-toolchain=/cm/local/apps/gcc/8.2.0"
      ;;
    hipsycl-b13c71f)
      module load cmake/3.18.3  
      module load gcc/10.2.0 boost/1.73.0/gcc-10.2.0 hipsycl/b13c71f/gcc-10.2.0
      HIPSYCL_PATH="$(realpath "$(dirname "$(which syclcc)")"/..)"
      echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL-NEXT"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=16"
      MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$HIPSYCL_PATH"
      MAKE_OPTS+=" -DHIPSYCL_PLATFORM=cpu"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    computecpp-2.1.1)
      module load gcc/8.2.0
      loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/setvars.sh # for the Intel OpenCL libs
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

export COMPILERS="cce-10.0 gcc-9.3 gcc-10.2 intel-2019 oneapi-2021.1-beta10 hipsycl-b13c71f computecpp-2.1.1"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl kokkos"
export DEFAULT_MODEL="omp"
export PLATFORM="cxl-isambard"

export KOKKOS_ARCH="SKX"
export KOKKOS_WGSIZE="128"
export KOKKOS_EXTRA_FLAGS="-march=skylake-avx512"

bash "$PLATFORM_DIR/../common.sh" "$@"
