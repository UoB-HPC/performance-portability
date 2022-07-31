#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "babelstream" "irispro580"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

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
  append_opts "-DSYCL_COMPILER=ONEAPI-DPCPP"
  BENCHMARK_EXE="sycl-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DCMAKE_CXX_COMPILER=icpx -DOFFLOAD=INTEL"
  BENCHMARK_EXE="omp-stream"
  ;;
std-data)
  append_opts "-DMODEL=std-data"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DUSE_ONEDPL=dpcpp_only"
  BENCHMARK_EXE="std-data-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DUSE_ONEDPL=dpcpp_only"
  BENCHMARK_EXE="std-indices-stream"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  append_opts "-DCMAKE_CXX_COMPILER=dpcpp -DUSE_ONEDPL=dpcpp_only"
  BENCHMARK_EXE="std-ranges-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
