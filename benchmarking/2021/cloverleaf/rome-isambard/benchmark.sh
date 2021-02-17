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
    aocc-2.3)
      module load aocc/2.3
      echo "IMPL"
      ;;
    cce-10.0)
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      module swap craype-{broadwell,x86-rome}
      echo "IMPL"
      ;;
    gcc-10.2)
      module load openmpi/4.0.4/gcc-9.3
      module swap gcc/9.3.0 gcc/10.2.0
      MAKE_OPTS='COMPILER=GNU MPI_COMPILER=mpif90 C_MPI_COMPILER=mpicc'
      MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
      MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
      ;;
    llvm-11.0)
      module load llvm/11.0
      echo "IMPL"
      ;;
    oneapi-2021.1)
      module load gcc/10.2.0
      loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/2021.1/setvars.sh
      MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=2"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    hipsycl-cf71460)
      module load gcc/10.2.0 boost/1.73.0/gcc-10.2.0 hipsycl/cf71460/gcc-10.2.0
      export HIPSYCL_OMP_LINK_LINE="-fopenmp $BOOST_ROOT/lib/libboost_fiber.so $BOOST_ROOT/lib/libboost_context.so"
      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL-NEXT"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=16"
      MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$(findhipSYCL)"
      MAKE_OPTS+=" -DHIPSYCL_PLATFORM=cpu"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      ;;
    computecpp-2.1.1)
      module load gcc/8.2.0
      loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/2021.1/setvars.sh # for the Intel OpenCL libs
      module load computecpp/2.1.1
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
    ocl)
      loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/2021.1/setvars.sh
      MAKE_OPTS+=" USE_OPENCL=1"
      MAKE_OPTS+=' COPTIONS="-std=c++98 -DCL_TARGET_OPENCL_VERSION=110 -DOCL_IGNORE_PLATFORM"'
      MAKE_OPTS+=' OPTIONS="-lstdc++ -cpp -lOpenCL"'
      MAKE_OPTS+=" OCL_VENDOR=AMD" 
      MAKE_OPTS+=" OCL_LIB_AMD_INC=$(fetchCLHeader)"
      MAKE_OPTS+=" OCL_AMD_LIB=-L$(findOneAPIlibOpenCL)"
      ;;
    *)
      ;;
  esac

}

export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="aocc-2.3 cce-10.0 gcc-10.2 llvm-11.0 oneapi-2021.1 hipsycl-cf71460 computecpp-2.1.1"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl kokkos ocl"
export DEFAULT_MODEL="omp"
export PLATFORM="rome-isambard"

export KOKKOS_BACKEND="OPENMP"
export KOKKOS_ARCH="ZEN2"
export KOKKOS_EXTRA_FLAGS="-Ofast;-march=znver2"

bash "$PLATFORM_DIR/../common.sh" "$@"
