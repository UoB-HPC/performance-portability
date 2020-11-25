#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  # if ! grep -q bristol/modules/ <<<"$MODULEPATH"; then
  #   module use /lustre/projects/bristol/modules/modulefiles
  # fi

  # Load TomD's stuff which contains cmake
  module use /lus/scratch/p02639/modulefiles
  
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
    intel-2019)
      module load intel-parallel-studio-xe/compilers/64/2019u4/19.0.4
      MAKE_OPTS='COMPILER=INTEL ARCH=skylake-avx512'
      ;;
    oneapi-2021.1-beta10)
      loadOneAPI /lus/scratch/wlin/intel/oneapi/setvars.sh 
      module load cmake/3.18.2
      module load gcc/9.3.0
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=skylake-avx512"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=4"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;  
    hipsycl-46bc9bd)
      # FIXME 46bc9bd is the head of the stable branch and it still can't handle local_ptr overloads
      # dev branch compiles but it's fairly volatile there
      module load hipsycl/46bc9bd
      HIPSYCL_PATH="$(realpath "$(dirname "$(which syclcc)")"/..)"
      module load cmake/3.18.3 gcc/8.2.0
      echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=16"
      MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$HIPSYCL_PATH"
      MAKE_OPTS+=" -DHIPSYCL_PLATFORM=cpu"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    computecpp-2.1.1)
      loadOneAPI /lus/scratch/wlin/intel/oneapi/setvars.sh 
      module load cmake/3.18.2
      module load gcc/9.3.0
      COMPUTECPP_PATH="/lus/scratch/wlin/ComputeCpp-CE-2.2.1-x86_64-linux-gnu"
      INTEL_OCL_LIB_PATH="/lus/scratch/p02639/bin/oclcpuexp_2020.10.7.0.15/x64/libintelocl.so"
      echo "Using COMPUTECPP_PATH=${COMPUTECPP_PATH}"
      echo "Using INTEL_OCL_LIB_PATH=${INTEL_OCL_LIB_PATH}"
      MAKE_OPTS=" -DSYCL_RUNTIME=COMPUTECPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=4"
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

export COMPILERS="cce-10.0 gcc-9.3 intel-2019 oneapi-2021.1-beta10 hipsycl-46bc9bd computecpp-2.1.1"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl"
export DEFAULT_MODEL="omp"
export PLATFORM="skl-swan"

bash "$PLATFORM_DIR/../common.sh" "$@"
