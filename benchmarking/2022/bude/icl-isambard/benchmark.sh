#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "icl"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"

case "$COMPILER" in
cce)
  module load cce
  module swap craype-broadwell craype-x86-cascadelake
  module load cray-mvapich2_noslurm_nogpu
  module rm cray-libsci
  append_opts "-DCMAKE_C_COMPILER=cc"
  append_opts "-DCMAKE_CXX_COMPILER=CC"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  ;;
oneapi-2022.2)
  module load gcc/12.1.0
  load_oneapi "$HOME/intel/oneapi/setvars.sh"
  ;;
llvm-14)
  export PATH="/lustre/home/br-jcownie/software/clang-14.x/x86_64/bin:$PATH"
  export LD_LIBRARY_PATH="/lustre/home/br-jcownie/software/clang-14.x/x86_64/lib:$LD_LIBRARY_PATH"

  append_opts "-DCMAKE_C_COMPILER=clang"
  append_opts "-DCMAKE_CXX_COMPILER=clang++"
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  ;;
hipsycl-gcc)
  module unload gcc
  module load gcc/8.1.0
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
  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON -DKokkos_CXX_STANDARD=17"
  # append_opts "-DKokkos_ARCH_SKX=ON"           #  Kokkos needs a patch from master for ICX/ICL
  export CXXFLAGS="-march=icelake-server -Ofast" # and because Kokkos *append* arch flags, we just set it up ourselves
  BENCHMARK_EXE="kokkos-bude"
  case "$COMPILER" in
  oneapi-*) append_opts "-DCMAKE_CXX_COMPILER=icpx" ;;
  *) ;; # don't change anything otherwise
  esac
  ;;
omp)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  case "$COMPILER" in
  oneapi-*)
    append_opts "-DCMAKE_CXX_COMPILER=icpx"
    append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
    ;;
  *) ;; # don't change anything otherwise
  esac
  ;;
omp-target)
  append_opts "-DMODEL=omp"
  BENCHMARK_EXE="omp-bude"
  case "$COMPILER" in
  oneapi-*)
    append_opts "-DCMAKE_CXX_COMPILER=icpx"
    append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast -DOFFLOAD=INTEL"
    ;;
  *)
    append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast -DOFFLOAD=ON"
    ;;
  esac
  ;;
sycl)
  append_opts "-DMODEL=sycl"
  BENCHMARK_EXE="sycl-bude"

  append_opts "-DCXX_EXTRA_FLAGS=-march=icelake-server;-Ofast"
  case "$COMPILER" in
  oneapi-*)
    append_opts "-DSYCL_COMPILER=ONEAPI-DPCPP"
    ;;
  hipsycl-gcc)
    append_opts "-DCMAKE_C_COMPILER=gcc"
    append_opts "-DCMAKE_CXX_COMPILER=g++"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=/home/br-tdeakin/codes/babelstream/src/hipSYCL/build-ilake-gcc/install"
    ;;
  hipsycl-llvm)
    append_opts "-DCMAKE_C_COMPILER=clang"
    append_opts "-DCMAKE_CXX_COMPILER=clang++"
    append_opts "-DSYCL_COMPILER=HIPSYCL -DSYCL_COMPILER_DIR=/home/br-tdeakin/codes/babelstream/src/hipSYCL/build-ilake-llvm/install"
    ;;
  esac
  ;;
*) unknown_model ;;
esac

handle_exec
