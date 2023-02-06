#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "uhdp630"

export USE_MAKE=false

case "$COMPILER" in
oneapi-2022.2)
  module load gcc/11.2.0
  module load compiler/latest mpi/latest
  # we use the MPI library from oneAPI here
  ;;
*) unknown_compiler ;;
esac

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$MODEL" in
kokkos)
  fetch_src "kokkos"
  prime_kokkos
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-march=skylake;-Ofast -DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_SYCL=ON -DKokkos_CXX_STANDARD=17"
  append_opts "-DKokkos_ARCH_INTEL_GEN=OFF" # XXX ENABLE_SYCL adds -fsycl which is sufficient, INTEL_GEN breaks it by adding -X backend flags
  ;;
sycl)
  fetch_src "sycl"
  append_opts "-DSYCL_RUNTIME=DPCPP"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-march=skylake;-Ofast"
  ;;
omp)
  fetch_src "omp-target"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DOMP_OFFLOAD_FLAGS=-march=skylake;-qnextgen;-fiopenmp;-fopenmp-targets=spir64;-Ofast"
  ;;
std-indices)
  fetch_src "stdpar"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-march=skylake;-Ofast -DUSE_ONEDPL=dpcpp_only"
  ;;
*) unknown_model ;;
esac

export BENCHMARK_EXE="clover_leaf"

handle_exec
