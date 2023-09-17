#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "minibude" "mi100" "bm_${INPUT_BM:-}_xnack_${HSA_XNACK:-}_utpx_${UTPX:-}"

export USE_MAKE=false

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
rocm-5.4.1)
  module load gcc/13.1.0
  export PATH="/opt/rocm-5.4.1/bin:${PATH:-}"
  export ROCM_PATH="/opt/rocm-5.4.1"
  ;;
hipsycl-fd5d1c0)
  module load gcc/12.1.0
  export HIPSYCL_DIR="$HOME/software/x86_64/hipsycl/fd5d1c0"
  ;;
roc-stdpar-*ecb855a5)
  module load gcc/13.1.0
  append_opts "-DCMAKE_C_COMPILER=$HOME/software/x86_64/llvm/ecb855a5a8c5dd9d46ca85041d7fe987fa73ba7c-roc-stdpar/bin/clang"
  append_opts "-DCMAKE_CXX_COMPILER=$HOME/software/x86_64/llvm/ecb855a5a8c5dd9d46ca85041d7fe987fa73ba7c-roc-stdpar/bin/clang++"
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
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  BENCHMARK_EXE="kokkos-bude"
  ;;
hip)
  append_opts "-DMODEL=hip"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx908;-march=znver3;-Ofast"
  BENCHMARK_EXE="hip-bude"
  ;;
ocl)
  append_opts "-DMODEL=ocl"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  append_opts "-DOpenCL_LIBRARY=$ROCM_PATH/lib/libOpenCL.so"
  BENCHMARK_EXE="ocl-bude"
  ;;
thrust)
  append_opts "-DMODEL=thrust"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DTHRUST_IMPL=ROCM -DCMAKE_PREFIX_PATH=$ROCM_PATH/lib/cmake/"
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx906;-march=znver3;-Ofast"
  BENCHMARK_EXE="thrust-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-fopenmp;--offload-arch=gfx908"
  append_opts "-DCMAKE_C_COMPILER=$(which clang)"
  append_opts "-DCMAKE_CXX_COMPILER=$(which clang++)"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast;-fopenmp-target-fast"
  BENCHMARK_EXE="omp-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  case "$COMPILER" in
  hipsycl-*)
    export HIPSYCL_TARGETS="hip:gfx908"
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=$HIPSYCL_DIR/bin/syclcc"
    export CXXFLAGS="--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast;--opensycl-stdpar;--opensycl-stdpar-unconditional-offload;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    ;;
  oneapi-*)
    append_opts "-DUSE_ONEDPL=DPCPP"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=znver3;-Ofast"
    ;;
  roc-stdpar-interpose-*)
    append_opts "-DCXX_EXTRA_FLAGS=--hipstdpar;--hipstdpar-path=$HOME/roc-stdpar/include;--hipstdpar-interpose-alloc;--offload-arch=gfx908;-march=znver3;-Ofast;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    ;;
  roc-stdpar-*)
    append_opts "-DCXX_EXTRA_FLAGS=--hipstdpar;--hipstdpar-path=$HOME/roc-stdpar/include;--offload-arch=gfx908;-march=znver3;-Ofast;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
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
    append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast;--gcc-toolchain=$(dirname "$(dirname "$(which gcc)")")"
    ;;
  oneapi-*)
    append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908;-march=znver3;-Ofast"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="sycl-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
