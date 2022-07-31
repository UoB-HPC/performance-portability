#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "irispro580"

export USE_MAKE=false

case "$COMPILER" in
oneapi-2022.2)
  module load gcc/8.3.0
  load_oneapi /nfs/software/x86_64/intel/oneapi/2022.2/setvars.sh
  # we use the MPI library from oneAPI here
  ;;
*) unknown_compiler ;;
esac

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$MODEL" in
sycl)
  fetch_src "sycl"
  append_opts "-DSYCL_RUNTIME=DPCPP"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-Ofast"
  ;;
omp)
  fetch_src "omp-target"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DOMP_OFFLOAD_FLAGS=-qnextgen;-fiopenmp;-fopenmp-targets=spir64-Ofast"
  ;;
std-indices)
  fetch_src "stdpar"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-Ofast -DUSE_ONEDPL=dpcpp_only"
  ;;
*) unknown_model ;;
esac

export BENCHMARK_EXE="clover_leaf"

handle_exec
