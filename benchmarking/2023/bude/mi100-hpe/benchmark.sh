#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

handle_cmd "${1}" "${2}" "${3}" "minibude" "radeonvii" "bm=${INPUT_BM:-}_xnack=${HSA_XNACK:-}_utpx=${UTPX:-}"

export USE_MAKE=false
export USE_SLURM=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
aomp-18.0.0)
  export AOMP=$HOME/usr/lib/aomp_18.0-0
  export PATH="$AOMP/bin:${PATH:-}"
  export LD_LIBRARY_PATH="$AOMP/lib64:${LD_LIBRARY_PATH:-}"
  export LIBRARY_PATH="$AOMP/lib64:${LIBRARY_PATH:-}"
  export C_INCLUDE_PATH="$AOMP/include:${C_INCLUDE_PATH:-}"
  export CPLUS_INCLUDE_PATH="$AOMP/include:${CPLUS_INCLUDE_PATH:-}"
  ;;
rocm-5.5.1)
  export PATH="/opt/rocm-5.5.1/bin:${PATH:-}"
  export ROCM_PATH="/opt/rocm-5.5.1"
  ;;
hipsycl-fd5d1c0)
  export HIPSYCL_DIR="/opt/hipsycl/fd5d1c0"
  ;;
roc-stdpar-ecb855a5)
  append_opts "-DCMAKE_C_COMPILER=/opt/llvm/ecb855a5a8c5dd9d46ca85041d7fe987fa73ba7c-roc-stdpar/bin/clang"
  append_opts "-DCMAKE_CXX_COMPILER=/opt/llvm/ecb855a5a8c5dd9d46ca85041d7fe987fa73ba7c-roc-stdpar/bin/clang++"
  ;;
oneapi-2023.2)
  set +eu
  source "/opt/intel/oneapi/compiler/2023.2.1/env/vars.sh" --include-intel-llvm
  source "/opt/intel/oneapi/tbb/2021.10.0/env/vars.sh"
  set -eu
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
  append_opts "-DCXX_EXTRA_FLAGS=-march=native;-Ofast"
  BENCHMARK_EXE="kokkos-bude"
  ;;
hip)
  append_opts "-DMODEL=hip"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx908;-march=native;-Ofast"
  BENCHMARK_EXE="hip-bude"
  ;;
ocl)
  append_opts "-DMODEL=ocl"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=-march=native;-Ofast"
  append_opts "-DOpenCL_LIBRARY=$ROCM_PATH/lib/libOpenCL.so"
  BENCHMARK_EXE="ocl-bude"
  ;;
thrust)
  append_opts "-DMODEL=thrust"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DTHRUST_IMPL=ROCM -DCMAKE_PREFIX_PATH=$ROCM_PATH/lib/cmake/"
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx908;-march=native;-Ofast"
  BENCHMARK_EXE="thrust-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-fopenmp;--offload-arch=gfx908"
  append_opts "-DCMAKE_C_COMPILER=$(which clang)"
  append_opts "-DCMAKE_CXX_COMPILER=$(which clang++)"
  append_opts "-DCXX_EXTRA_FLAGS=-march=native;-Ofast;-fopenmp-target-fast"
  BENCHMARK_EXE="omp-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="hip:gfx908"
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=$HIPSYCL_DIR/bin/syclcc"
    append_opts "-DCXX_EXTRA_FLAGS=-march=native;-Ofast;--opensycl-stdpar;--opensycl-stdpar-unconditional-offload"
    ;;
  oneapi-*)
    append_opts "-DUSE_ONEDPL=DPCPP"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=native;-Ofast"
    append_opts "-DCXX_EXTRA_LIBRARIES=tbb"
    ;;
  roc-stdpar-*)
    append_opts "-DCXX_EXTRA_FLAGS=--hipstdpar;--hipstdpar-path=$HOME/roc-stdpar/include;--offload-arch=gfx908;-march=native;-Ofast"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="std-indices-bude"
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="hip:gfx908"
    append_opts "-DSYCL_COMPILER=HIPSYCL"
    append_opts "-DSYCL_COMPILER_DIR=$HIPSYCL_DIR"
    append_opts "-DCXX_EXTRA_FLAGS=-march=native;-Ofast"
    ;;
  oneapi-*)
    append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=native;-Ofast"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="sycl-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
