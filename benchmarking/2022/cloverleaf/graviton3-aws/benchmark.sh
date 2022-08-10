#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "graviton3"

export USE_MAKE=false
export USE_SLURM=true

# Set up the environment
case "$COMPILER" in
gcc-12.1)
  spack load gcc@12.1.0
  spack load openmpi
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DUSE_TBB=ON"
   # Nuke the entire flag because the default `-march=native` is broken and -mcpu=neoverse-v1 is broken too
  cxx_extra_flags="-march=armv8.4-a+rcpc+sve+profile;-O3;-ffast-math" # -Ofast fails with small timestep 
  ;;
nvhpc-22.7)
  spack load openmpi
  load_nvhpc
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  cxx_extra_flags="--restrict;-target=multicore;-march=neoverse-v1;-fast;-Mllvm-fast;-Ktrap=none;-Minfo=accel"
  ;;
*) unknown_compiler ;;
esac

case "$MODEL" in
kokkos)
  fetch_src "kokkos"
  prime_kokkos
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  append_opts "-DKokkos_ARCH_NATIVE=ON"
  ;;
omp)
  fetch_src "omp-plain"
  case "$COMPILER" in
  nvhpc-*) cxx_extra_flags="$cxx_extra_flags;-Minfo=mp" ;;
  *) ;;
  esac
  ;;
tbb)
  fetch_src "tbb"
  ;;
std-indices)
  fetch_src "stdpar"
  case "$COMPILER" in
  nvhpc-*) cxx_extra_flags="$cxx_extra_flags;-stdpar;-Minfo=stdpar" ;;
  *) ;;
  esac
  ;;

std-indices-dplomp)
  fetch_src "stdpar"
  case "$COMPILER" in
  nvhpc-*) echo "$COMPILER with dplomp is unsupported" && exit 1 ;;
  *) append_opts "-DUSE_ONEDPL=OPENMP" ;;
  esac
  ;;

*) unknown_model ;;
esac

append_opts "-DCXX_EXTRA_FLAGS=${cxx_extra_flags}"

export BENCHMARK_EXE="clover_leaf"

handle_exec
