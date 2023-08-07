#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.23.2

handle_cmd "${1}" "${2}" "${3}" "cloverleaf" "mi100" "${INPUT_BM:-}_${STAGE:-}"

export USE_MAKE=false
module load cray-mpich/8.1.25
module load craype-accel-amd-gfx908
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_OFI_NIC_POLICY=NUMA
if [ ! -d "$CRAY_MPICH_DIR" ]; then
  echo "CRAY_MPICH_DIR ($CRAY_MPICH_DIR) does not exist or is not a directory"
  exit 1
fi

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_MPI=ON -DENABLE_PROFILING=ON -DMPI_HOME=$CRAY_MPICH_DIR -DCXX_EXTRA_LIBRARIES=$CRAY_MPICH_ROOTDIR/gtl/lib/libmpi_gtl_hsa.so"

case "$COMPILER" in
aomp-16.0.3)
  module load gcc/13.1.0
  export AOMP=$HOME/usr/lib/aomp_16.0-3
  export PATH="$AOMP/bin:${PATH:-}"
  export LD_LIBRARY_PATH="$AOMP/lib64:${LD_LIBRARY_PATH:-}"
  export LIBRARY_PATH="$AOMP/lib64:${LIBRARY_PATH:-}"
  export C_INCLUDE_PATH="$AOMP/include:${C_INCLUDE_PATH:-}"
  export CPLUS_INCLUDE_PATH="$AOMP/include:${CPLUS_INCLUDE_PATH:-}"
  # XXX we need this if we load the HSA GTL: clang's target initialisation happens in the wrong order so we need to skip the check
  export OFFLOAD_ARCH_OVERRIDE=gfx908
  ;;
rocm-5.4.1)
  module load gcc/13.1.0
  export PATH="/opt/rocm-5.4.1/bin:${PATH:-}"
  ;;
oneapi-2023.2)
  module load gcc/13.1.0
  set +eu
  source "$HOME/intel/oneapi/compiler/2023.2.0/env/vars.sh" --include-intel-llvm
  source "$HOME/intel/oneapi/tbb/2021.10.0/env/vars.sh"
  set -eu
  append_opts "-DCMAKE_C_COMPILER=icx"
  append_opts "-DCMAKE_CXX_COMPILER=icpx"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
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
  BENCHMARK_EXE="kokkos-cloverleaf"
  ;;
hip)
  append_opts "-DMODEL=hip"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx908"
  BENCHMARK_EXE="hip-cloverleaf"
  ;;
omp)
  append_opts "-DMODEL=omp-target"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-fopenmp;--offload-arch=gfx908"
  append_opts "-DCMAKE_C_COMPILER=$(which clang)"
  append_opts "-DCMAKE_CXX_COMPILER=$(which clang++)"
  BENCHMARK_EXE="omp-target-cloverleaf"
  ;;
std-indices)
  hip_sycl_flags="-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908"
  append_opts "-DMODEL=std-indices"
  append_opts "-DUSE_ONEDPL=DPCPP"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;$hip_sycl_flags -DCXX_EXTRA_LINK_FLAGS=-fsycl;$hip_sycl_flags"
  BENCHMARK_EXE="std-indices-cloverleaf"
  ;;
sycl-acc)
  hip_sycl_flags="-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908"
  append_opts "-DMODEL=sycl-acc"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DUSE_HOSTTASK=ON"
  append_opts "-DCXX_EXTRA_FLAGS=$hip_sycl_flags -DCXX_EXTRA_LINK_FLAGS=$hip_sycl_flags"
  BENCHMARK_EXE="sycl-acc-cloverleaf"
  ;;
sycl-usm)
  hip_sycl_flags="-fsycl-targets=amdgcn-amd-amdhsa;-Xsycl-target-backend;--offload-arch=gfx908"
  append_opts "-DMODEL=sycl-usm"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DUSE_HOSTTASK=ON"
  append_opts "-DCXX_EXTRA_FLAGS=$hip_sycl_flags -DCXX_EXTRA_LINK_FLAGS=$hip_sycl_flags"
  BENCHMARK_EXE="sycl-usm-cloverleaf"
  ;;
*) unknown_model ;;
esac

handle_exec
