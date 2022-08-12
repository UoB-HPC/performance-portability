#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "milan"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
cce)
  module load cce
  module load craype-x86-milan
  append_opts "-DCMAKE_C_COMPILER=cc"
  append_opts "-DCMAKE_CXX_COMPILER=CC"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  ;;
oneapi-2022.2)
  module load gcc/12.1.0
  load_oneapi "$HOME/intel/oneapi/setvars.sh"
  ;;
aocc-3.2.0)

  export PATH="/lustre/home/br-wlin/aocc-compiler-3.2.0/bin:$PATH"
  export LD_LIBRARY_PATH="/lustre/home/br-wlin/aocc-compiler-3.2.0/lib:$LD_LIBRARY_PATH"

  append_opts "-DCMAKE_C_COMPILER=clang"
  append_opts "-DCMAKE_CXX_COMPILER=clang++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  ;;
llvm-14)

  export PATH="/lustre/home/br-jcownie/software/clang-14.x/x86_64/bin:$PATH"
  export LD_LIBRARY_PATH="/lustre/home/br-jcownie/software/clang-14.x/x86_64/lib:$LD_LIBRARY_PATH"

  module load gcc/12.1.0

  append_opts "-DCMAKE_C_COMPILER=clang"
  append_opts "-DCMAKE_CXX_COMPILER=clang++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  ;;
hipsycl-gcc)
  module load gcc/12.1.0
  ;;
hipsycl-llvm)
  module load gcc/12.1.0
  export PATH="/lustre/home/br-jcownie/software/clang-14.x/x86_64/bin:$PATH"
  export LD_LIBRARY_PATH="/lustre/home/br-jcownie/software/clang-14.x/x86_64/lib:$LD_LIBRARY_PATH"
  ;;
gcc-12.1)
  module load gcc/12.1.0
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  append_opts "-DKokkos_ARCH_ZEN3=ON"
  BENCHMARK_EXE="kokkos-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  ;;
omp-target)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast -DOFFLOAD=ON"
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  BENCHMARK_EXE="sycl-bude"

  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  case "$COMPILER" in
  oneapi-*)
    append_opts "-DSYCL_COMPILER=ONEAPI-DPCPP"
    ;;
  hipsycl-gcc)
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    append_opts "-DCXX_EXTRA_LIBRARIES=stdc++fs"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=/home/br-tdeakin/codes/babelstream/src/hipSYCL/build-milan-gcc/install"
    ;;
  hipsycl-llvm)
    append_opts "-DCMAKE_C_COMPILER=clang"
    append_opts "-DCMAKE_CXX_COMPILER=clang++"
    append_opts "-DCXX_EXTRA_LIBRARIES=stdc++fs"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=/home/br-tdeakin/codes/babelstream/src/hipSYCL/build-milan-llvm/install"
    ;;
  esac
  ;;
*) unknown_model ;;
esac

handle_exec
