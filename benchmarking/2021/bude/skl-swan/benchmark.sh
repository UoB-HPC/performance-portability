#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  USE_QUEUE=true
  module use /lus/scratch/p02639/modulefiles
  module use /lus/snx11029/p02508-modules/modulefiles
  module load cmake

  module swap craype-{broadwell,x86-skylake}

  case "$COMPILER" in
    aocc-2.3)
      module swap PrgEnv-{cray,gnu}
      module load aocc/2.3
      MAKE_OPTS='COMPILER=CLANG ARCH=skylake-avx512 WGSIZE=256'
      ;;
    cce-10.0)
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      MAKE_OPTS='COMPILER=CLANG CC=cc ARCH=skylake-avx512 WGSIZE=256'
      export KOKKOS_WGSIZE="128"
      ;;
    gcc-9.3)
      module swap PrgEnv-{cray,gnu}
      module swap gcc gcc/9.3.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512 WGSIZE=256'
      KOKKOS_EXTRA_FLAGS+=";-mprefer-vector-width=512"
      ;;
    gcc-10.1)
      module swap PrgEnv-{cray,gnu}
      module swap gcc gcc/10.1.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512'
      KOKKOS_EXTRA_FLAGS+=";-mprefer-vector-width=512 WGSIZE=256"
      export KOKKOS_WGSIZE="32"
      ;;
    intel-2019)
      module swap PrgEnv-{cray,intel}
      KOKKOS_EXTRA_FLAGS+=";-qopt-zmm-usage=high"
      MAKE_OPTS='COMPILER=INTEL ARCH=skylake-avx512 WGSIZE=256'
      ;;
    oneapi-2021.1-beta10)
      loadOneAPI /lus/scratch/wlin/intel/oneapi/setvars.sh
      module load cmake/3.18.2
      module load gcc/9.3.0
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=skylake-avx512"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    hipsycl-cc320b6)
      module swap PrgEnv-{cray,gnu}
      module swap gcc gcc/10.1.0
      module load cmake/3.18.2
      module load hipsycl/cc320b6-201124/gcc-10.1
      HIPSYCL_PATH="$(realpath "$(dirname "$(which syclcc)")"/..)"
      echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL-NEXT"
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

export COMPILERS="aocc-2.3 cce-10.0 gcc-9.3 gcc-10.1 intel-2019 oneapi-2021.1-beta10 computecpp-2.1.1 hipsycl-cc320b6"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl"
export DEFAULT_MODEL="omp"
export PLATFORM="skl-swan"

export KOKKOS_BACKEND="OPENMP"
export KOKKOS_ARCH="SKX"
export KOKKOS_WGSIZE="256"
export KOKKOS_EXTRA_FLAGS="-Ofast;-march=skylake-avx512"

bash "$PLATFORM_DIR/../common.sh" "$@"
