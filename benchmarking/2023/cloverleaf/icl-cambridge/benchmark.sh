#!/bin/bash

set -eu

module purge
module load rhel8/slurm
# module unload rhel8/default-icl
### XXX This must be ran from an IceLake node, the head node's GCC seems to default to a bad arch???
export RDS_ROOT="/rds/user/hpclin2/hpc-work"
source "$RDS_ROOT/spack/share/spack/setup-env.sh"

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "icl" "${INPUT_BM:-}"

export USE_MAKE=false
export USE_SLURM=true

source "$RDS_ROOT/intel/oneapi/mpi/2021.10.0/env/vars.sh"
append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_MPI=ON -DENABLE_PROFILING=ON -DMPI_ROOT=$RDS_ROOT/intel/oneapi/mpi/2021.10.0/bin"

case "$COMPILER" in
gcc-13.1)
  spack load gcc@13.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
oneapi-2023.2)
  module load gcc/11
  # load_oneapi "$RDS_ROOT/intel/oneapi/setvars.sh"
  # source "$RDS_ROOT/intel/oneapi/mpi/2021.9.0/env/vars.sh"
  set +eu
  source "$RDS_ROOT/intel/oneapi/compiler/2023.2.0/env/vars.sh"
  source "$RDS_ROOT/intel/oneapi/tbb/2021.10.0/env/vars.sh"
  set -eu
  append_opts "-DCMAKE_C_COMPILER=icx"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
hipsycl-7b2e459)
  spack load gcc@13.1.0
  export LD_LIBRARY_PATH="$(spack location -i gcc@13.1.0)/lib64:${LD_LIBRARY_PATH:-}"
  export HIPSYCL_DIR="$RDS_ROOT/software/x86_64/hipsycl/7b2e459"
  append_opts "-DUSE_TBB=ON  -DCMAKE_CXX_STANDARD=17"
  ;;
nvhpc-23.5)
  spack load gcc@13.1.0
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  case "$MODEL" in
  omp)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=skylake-avx512;-fast;--gcc-toolchain=$(spack location -i gcc@13.1.0)"

    ;;
  std-*)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-stdpar;-march=skylake-avx512;-fast;--gcc-toolchain=$(spack location -i gcc@13.1.0)"
    ;;
  esac
  append_opts "-DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpicxx;mpi"
  append_opts "-DMPI_CXX_HEADER_DIR=$RDS_ROOT/intel/oneapi/mpi/2021.9.0/include -DMPI_C_HEADER_DIR=$RDS_ROOT/intel/oneapi/mpi/2021.10.0/include"
  append_opts "-DMPI_mpicxx_LIBRARY=$RDS_ROOT/intel/oneapi/mpi/2021.10.0/lib/libmpicxx.so -DMPI_mpi_LIBRARY=$RDS_ROOT/intel/oneapi/mpi/2021.10.0/lib/release/libmpi.so"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON"
  case "$COMPILER" in
  nvhpc-*)
    # append_opts "-DKokkos_ARCH_ICX=ON"           # Kokkos needs a patch from master for ICX/ICL
    export CXXFLAGS="-march=skylake-avx512 -fast --gcc-toolchain=$(spack location -i gcc@13.1.0)"
    export CFLAGS="-march=skylake-avx512 -fast --gcc-toolchain=$(spack location -i gcc@13.1.0)" # XXX nvc++ also has --gcc-toolchain
    # append_opts "-DMPI_CXX_WORKS=ON -DMPI_C_WORKS=ON -DMPIEXEC_EXECUTABLE"

    ;;
  *)
    # append_opts "-DKokkos_ARCH_ICX=ON"            # Kokkos needs a patch from master for ICX/ICL
    export CXXFLAGS="-march=icelake-server -Ofast"
    ;;
  esac
  BENCHMARK_EXE="kokkos-cloverleaf"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-cloverleaf"
  ;;
tbb)
  append_opts "-DMODEL=tbb -DPARTITIONER=AUTO" # auto doesn't work well for icl; use auto for comparison with std-*
  BENCHMARK_EXE="tbb-cloverleaf"
  ;;
std-data)
  append_opts "-DMODEL=std-data"
  BENCHMARK_EXE="std-data-cloverleaf"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-cloverleaf"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="omp.accelerated"
    export HIPSYCL_DEBUG_LEVEL=1 # quieter during runtime
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=$HIPSYCL_DIR/bin/syclcc"
    export CXXFLAGS="--gcc-toolchain=$(spack location -i gcc@13.1.0)"
    append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast;--opensycl-stdpar;--opensycl-stdpar-unconditional-offload;--gcc-toolchain=$(spack location -i gcc@13.1.0)"
    ;;
  esac
  ;;
std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-cloverleaf"
  ;;
sycl-acc)
  append_opts "-DMODEL=sycl-acc"
  BENCHMARK_EXE="sycl-acc-cloverleaf"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="omp.accelerated"
    export HIPSYCL_DEBUG_LEVEL=1 # quieter during runtime
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=$HIPSYCL_DIR"
    append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast;--gcc-toolchain=$(spack location -i gcc@13.1.0)"
    append_opts "-DUSE_HOSTTASK=OFF"
    ;;
  oneapi-*)
    append_opts "-DUSE_HOSTTASK=ON"
    append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
    ;;
  esac
  ;;
sycl-usm)
  append_opts "-DMODEL=sycl-usm"
  BENCHMARK_EXE="sycl-usm-cloverleaf"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="omp.accelerated"
    export HIPSYCL_DEBUG_LEVEL=1 # quieter during runtime
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=$HIPSYCL_DIR"
    append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast;--gcc-toolchain=$(spack location -i gcc@13.1.0)"
    append_opts "-DUSE_HOSTTASK=OFF"
    ;;
  oneapi-*)
    append_opts "-DUSE_HOSTTASK=ON"
    append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
    ;;
  esac
  ;;
*) unknown_model ;;
esac

handle_exec