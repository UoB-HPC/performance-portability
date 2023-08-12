#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "babelstream" "mi100"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
aomp-16.0.3)
  export AOMP=$HOME/usr/lib/aomp_16.0-3
  export PATH="$AOMP/bin:${PATH:-}"
  export LD_LIBRARY_PATH="$AOMP/lib64:${LD_LIBRARY_PATH:-}"
  export LIBRARY_PATH="$AOMP/lib64:${LIBRARY_PATH:-}"
  export C_INCLUDE_PATH="$AOMP/include:${C_INCLUDE_PATH:-}"
  export CPLUS_INCLUDE_PATH="$AOMP/include:${CPLUS_INCLUDE_PATH:-}"
  ;;
rocm-5.4.1)
  module load gcc/13.1.0
  export PATH="/opt/rocm-5.4.1/bin:${PATH:-}"
  ;;
hipsycl-7b2e459)
  module load gcc/12.1.0
  export HIPSYCL_DIR="$HOME/software/x86_64/hipsycl/7b2e459"
  ;;
oneapi-2023.2)
  module load gcc/13.1.0 # libpi_hip needs a newer libstdc++
  load_oneapi "$HOME/intel/oneapi/setvars.sh" --include-intel-llvm
  append_opts "-DCMAKE_C_COMPILER=clang"
  append_opts "-DCMAKE_CXX_COMPILER=clang++"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_HIP=ON"
  append_opts "-DKokkos_ARCH_VEGA908=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc"
  BENCHMARK_EXE="kokkos-stream"
  ;;
hip)
  append_opts "-DMODEL=hip"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx908"
  BENCHMARK_EXE="hip-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-fopenmp;--offload-arch=gfx908"
  append_opts "-DCMAKE_C_COMPILER=$(which clang)"
  append_opts "-DCMAKE_CXX_COMPILER=$(which clang++)"
  BENCHMARK_EXE="omp-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="hip:gfx908"
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=$HIPSYCL_DIR/bin/syclcc"
    append_opts "-DCMAKE_CXX_COMPILER_WORKS=ON"
    append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;--opensycl-stdpar;--opensycl-stdpar-unconditional-offload;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    ;;
  oneapi-*)
    append_opts "-DUSE_ONEDPL=DPCPP"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=znver3"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="std-indices-stream"
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="hip:gfx908"
    append_opts "-DSYCL_COMPILER=HIPSYCL"
    append_opts "-DSYCL_COMPILER_DIR=$HIPSYCL_DIR"
    append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    ;;
  oneapi-*)
    append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=znver3"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="sycl-stream"
  ;;
sycl2020)
  append_opts "-DMODEL=sycl2020"
  case "$COMPILER" in
  hipsycl-*) unknown_compiler ;; # no 2020 reduction support
  oneapi-*)
    append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=znver3"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="sycl2020-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
