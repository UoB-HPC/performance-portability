#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1
spack load numactl%gcc@12.1.0

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "graviton2"

export USE_MAKE=false
export USE_SLURM=true

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
gcc-12.1)
  spack load gcc@12.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DRELEASE_FLAGS='' -DCXX_EXTRA_FLAGS=-mcpu=neoverse-n1;-Ofast"
  append_opts "-DUSE_TBB=ON"
  ;;
nvhpc-22.7)
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"
  case "$MODEL" in
  omp | kokkos)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-mp;-tp=neoverse-n1;-fast"
    ;;
  std-*)
    append_opts "-DCXX_EXTRA_FLAGS=-target=multicore;-stdpar;-tp=neoverse-n1;-fast"
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
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  case "$COMPILER" in
  nvhpc-*)
    append_opts "-DCMAKE_CXX_FLAGS=-tp=neoverse-n1" # apparently this appears before CXX_EXTRA_FLAGS
    ;;
  esac
  BENCHMARK_EXE="kokkos-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  ;;
tbb)
  append_opts "-DMODEL=tbb"
  BENCHMARK_EXE="tbb-bude"
  ;;

std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  BENCHMARK_EXE="std-ranges-bude"
  ;;

std-indices-dplomp)
  append_opts "-DMODEL=std-indices -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges-dplomp)
  append_opts "-DMODEL=std-ranges -DUSE_ONEDPL=OPENMP"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
