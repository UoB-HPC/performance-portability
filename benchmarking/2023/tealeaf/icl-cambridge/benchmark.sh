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

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "icl"

export USE_MAKE=false
export USE_SLURM=true

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
gcc-13.1)
  spack load gcc@13.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
oneapi-2023.1)
  module load gcc/11
  load_oneapi "$RDS_ROOT/intel/oneapi/setvars.sh"
  append_opts "-DCMAKE_C_COMPILER=icx"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
nvhpc-23.5)
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  case "$MODEL" in
  omp)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-march=skylake-avx512;-fast"
    ;;
  std-*)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-stdpar;-march=skylake-avx512;-fast"
    ;;
  esac
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
    spack load gcc@13.1.0
    export CXXFLAGS="-march=skylake-avx512 -fast --gcc-toolchain=$(spack location -i gcc@13.1.0)" # XXX nvc++ also has --gcc-toolchain
    ;;
  *)
    # append_opts "-DKokkos_ARCH_ICX=ON"            # Kokkos needs a patch from master for ICX/ICL
    export CXXFLAGS="-march=icelake-server -Ofast"
    ;;
  esac
  BENCHMARK_EXE="kokkos-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-stream"
  ;;
tbb)
  append_opts "-DMODEL=tbb -DPARTITIONER=AUTO" # auto doesn't work well for icl; use auto for comparison with std-*
  BENCHMARK_EXE="tbb-stream"
  ;;
std-data)
  append_opts "-DMODEL=std-data"
  BENCHMARK_EXE="std-data-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-stream"
  ;;
std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-stream"
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
  BENCHMARK_EXE="sycl-stream"
  ;;
sycl2020)
  append_opts "-DMODEL=sycl2020"
  append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
  BENCHMARK_EXE="sycl2020-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
