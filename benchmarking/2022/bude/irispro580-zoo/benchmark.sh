#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "irispro580"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
oneapi-2022.2)
  module load gcc/8.3.0
  load_oneapi /nfs/software/x86_64/intel/oneapi/2022.2/setvars.sh
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
sycl)
  append_opts "-DMODEL=sycl"
  append_opts "-DSYCL_COMPILER=ONEAPI-DPCPP -DCXX_EXTRA_FLAGS=-Ofast"
  BENCHMARK_EXE="sycl-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DCMAKE_CXX_COMPILER=icpx -DCXX_EXTRA_FLAGS=-Ofast -DOFFLOAD=INTEL"
  BENCHMARK_EXE="omp-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-Ofast -DUSE_ONEDPL=dpcpp_only"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DCXX_EXTRA_FLAGS=-Ofast -DUSE_ONEDPL=dpcpp_only"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
