#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "pvc" "${INPUT_BM:-}_${STAGE:-}"

export USE_MAKE=false
export USE_SLURM=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_MPI=ON -DENABLE_PROFILING=ON"

case "$COMPILER" in
oneapi-2023.2)
  set +eu
  source "/opt/intel/oneapi/compiler/2023.2.0/env/vars.sh"
  source "/opt/intel/oneapi/tbb/2021.10.0/env/vars.sh"
  source "/opt/intel/oneapi/mpi/2021.10.0/env/vars.sh"
  set -eu
  append_opts "-DCMAKE_C_COMPILER=icx"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_SYCL=ON"
  append_opts "-DKokkos_ARCH_INTEL_PVC=ON"
  BENCHMARK_EXE="kokkos-tealeaf"
  ;;
omp)
  append_opts "-DMODEL=omp-target"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-fiopenmp;-fopenmp-targets=spir64"
  BENCHMARK_EXE="omp-target-tealeaf"
  ;;
std-indices)
  hip_sycl_flags="-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908"
  append_opts "-DMODEL=std-indices"
  append_opts "-DUSE_ONEDPL=DPCPP"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl -DCXX_EXTRA_LINK_FLAGS=-fsycl"
  BENCHMARK_EXE="std-indices-tealeaf"
  ;;
sycl-acc)
  append_opts "-DMODEL=sycl-acc"
  append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
  append_opts "-DUSE_HOSTTASK=ON"
  BENCHMARK_EXE="sycl-acc-tealeaf"
  ;;
sycl-usm)
  append_opts "-DMODEL=sycl-usm"
  append_opts "-DSYCL_COMPILER=ONEAPI-ICPX"
  append_opts "-DUSE_HOSTTASK=ON"
  BENCHMARK_EXE="sycl-usm-tealeaf"
  ;;
*) unknown_model ;;
esac

handle_exec
