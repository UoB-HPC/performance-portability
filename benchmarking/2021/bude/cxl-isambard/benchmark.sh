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
      module load julia/julia-1.6.2
    ;;
    aocc-2.3)
      module load aocc/2.3
      MAKE_OPTS='COMPILER=CLANG ARCH=skylake-avx512 WGSIZE=128'
      ;;
    cce-10.0)
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      module swap craype-{broadwell,x86-skylake}
      MAKE_OPTS='COMPILER=CLANG CC=cc ARCH=skylake-avx512 WGSIZE=128'
      ;;
    gcc-9.3)
      module load gcc/9.3.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512 WGSIZE=128'
      ;;
    gcc-10.2)
      module load gcc/10.2.0
      MAKE_OPTS='COMPILER=GNU ARCH=skylake-avx512 WGSIZE=128'
      ;;
    intel-2019)
      module load intel-parallel-studio-xe/compilers/64/2019u4/19.0.4
      MAKE_OPTS='COMPILER=INTEL ARCH=skylake-avx512 WGSIZE=128'
      ;;
    intel-2020)
      module load intel-parallel-studio-xe/compilers/64/2020u4/20.0.4
      MAKE_OPTS='COMPILER=INTEL ARCH=skylake-avx512 WGSIZE=128'
      ;;
    llvm-11.0)
      module load llvm/11.0
      MAKE_OPTS='COMPILER=CLANG ARCH=skylake-avx512 WGSIZE=128'
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
    hipsycl-fe8465c) # 0.9.1
      module load gcc/10.2.0 boost/1.73.0/gcc-10.2.0 hipsycl/fe8465c/gcc-10.2.0
      export HIPSYCL_OMP_LINK_LINE="-fopenmp $BOOST_ROOT/lib/libboost_fiber.so $BOOST_ROOT/lib/libboost_context.so"
      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=16"
      MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$(findhipSYCL)"
      MAKE_OPTS+=" -DHIPSYCL_PLATFORM=cpu"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ "
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
    julia-ka)
      JULIA_ENTRY="src/KernelAbstractions.jl"
      JULIA_BACKEND="KernelAbstractions"
      ;;
    julia-threaded)
      JULIA_ENTRY="src/Threaded.jl"
      JULIA_BACKEND="Threaded"
      ;;
  esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="aocc-2.3 cce-10.0 gcc-9.3 gcc-10.2 intel-2019 intel-2020 llvm-11.0 oneapi-2021.1 hipsycl-cf71460 hipsycl-fe8465c computecpp-2.1.1 julia-1.6.2"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl kokkos ocl julia-threaded julia-ka"
export DEFAULT_MODEL="omp"
export PLATFORM="cxl-isambard"

export KOKKOS_BACKEND="OPENMP"
export KOKKOS_ARCH="SKX"
export KOKKOS_WGSIZE="128"
export KOKKOS_EXTRA_FLAGS="-Ofast;-march=skylake-avx512;-mprefer-vector-width=512"

bash "$PLATFORM_DIR/../common.sh" "$@"
