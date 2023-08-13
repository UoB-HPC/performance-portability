#!/bin/bash

set -eu

module purge
module load rhel8/slurm
module use /usr/local/software/spack/spack-modules/a100-20210927/linux-centos8-zen2
module load openmpi/4.1.1/gcc-9.4.0-epagguv
module unload rhel8/default-icl
unset CUDA_HOME
### XXX This must be ran from an IceLake node, the head node's GCC seems to default to a bad arch???
export RDS_ROOT="/rds/user/hpclin2/hpc-work"
source "$RDS_ROOT/spack/share/spack/setup-env.sh"


SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

spack load cmake@3.23.1

handle_cmd "${1}" "${2}" "${3}" "tealeaf" "a100_80g"

export USE_MAKE=false
export USE_SLURM=true

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_MPI=ON -DENABLE_PROFILING=ON"

case "$COMPILER" in
nvhpc-23.5)
  # module load gcc/11 # just get something that has libatomic, 13.1 is too new for nvcc
  load_nvhpc

  # module use /rds/user/hpclin2/hpc-work/spack/opt/spack/linux-scientific7-broadwell/gcc-5.4.0/nvhpc-23.5-4xmiigwb7v5m6yxdijjsefbp5pswlkxb/modulefiles/nvhpc-hpcx
  # module load 23.5


  append_opts "-DCMAKE_C_COMPILER=$NVHPC_PATH/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_PATH/compilers/bin/nvc++"

  # g++ -v
  # nvc++ -v
  which mpirun

  

  # see https://docs.hpc.cam.ac.uk/hpc/user-guide/a100.html, native tp will almost certainly be wrong as it might generate AVX512
  # source "$RDS_ROOT/intel/oneapi/mpi/2021.9.0/env/vars.sh"
  # append_opts "-DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpicxx;mpi"
  # append_opts "-DMPI_CXX_HEADER_DIR=$RDS_ROOT/intel/oneapi/mpi/2021.9.0/include -DMPI_C_HEADER_DIR=$RDS_ROOT/intel/oneapi/mpi/2021.9.0/include"
  # append_opts "-DMPI_mpicxx_LIBRARY=$RDS_ROOT/intel/oneapi/mpi/2021.9.0/lib/libmpicxx.so -DMPI_mpi_LIBRARY=$RDS_ROOT/intel/oneapi/mpi/2021.9.0/lib/release/libmpi.so"
  ;;
oneapi-2023.1)
  load_nvhpc # we need this for CUDA
  module load gcc/11
  # load_oneapi "$RDS_ROOT/intel/oneapi/setvars.sh" --include-intel-llvm
  source "$RDS_ROOT/intel/oneapi/compiler/2023.1.0/env/vars.sh" --include-intel-llvm
  source "$RDS_ROOT/intel/oneapi/tbb/2021.9.0/env/vars.sh"
  append_opts "-DCMAKE_C_COMPILER=clang"
  append_opts "-DCMAKE_CXX_COMPILER=clang++"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
kokkos)
  prime_kokkos
  export CUDA_ROOT="$NVHPC_PATH/cuda"
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_CUDA=ON"
  append_opts "-DKokkos_ARCH_AMPERE80=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3" # CSD3  A100s are hosted on a EPYC 7763
  append_opts "-DC_EXTRA_FLAGS=-march=znver3" # CSD3  A100s are hosted on a EPYC 7763
  BENCHMARK_EXE="kokkos-tealeaf"
  ;;
cuda)
  # CUDA11's GCC 9 support means znver2 only :(
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=nvcc"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCUDA_ARCH=sm_80"
  append_opts "-DRELEASE_CXX_FLAGS='' -DCXX_EXTRA_FLAGS=-O3;-march=znver1"
  append_opts "-DRELEASE_C_FLAGS='' -DC_EXTRA_FLAGS=-O3;-march=znver1" # CSD3  A100s are hosted on a EPYC 7763
  BENCHMARK_EXE="cuda-tealeaf"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=ON -DOFFLOAD_FLAGS=-mp=gpu;-gpu=cc80"
  append_opts "-DRELEASE_CXX_FLAGS='' -DCXX_EXTRA_FLAGS=-mp=gpu;-gpu=cc80;-O3;-tp=zen3" # CSD3 A100s are hosted on a EPYC 7763
  append_opts "-DRELEASE_C_FLAGS=''   -DC_EXTRA_FLAGS=-mp=gpu;-gpu=cc80;-O3;-tp=zen3" # CSD3 A100s are hosted on a EPYC 7763
  BENCHMARK_EXE="omp-tealeaf"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  case "$COMPILER" in
  nvhpc-*)

  

    # spack load gcc
    spack load gcc@13.1.0
    append_opts "-DNVHPC_OFFLOAD=cc80"
    append_opts "-DRELEASE_CXX_FLAGS='' -DCXX_EXTRA_FLAGS=-stdpar;-gpu=cc80;-O3;-tp=zen3;--gcc-toolchain=$(spack location -i gcc@13.1.0)"
    append_opts "-DRELEASE_C_FLAGS=''   -DC_EXTRA_FLAGS=-acc;-gpu=managed;-O3;-tp=zen3;--gcc-toolchain=$(spack location -i gcc@13.1.0)" # CSD3 A100s are hosted on a EPYC 7763
   ;;
  oneapi-*)
    append_opts "-DUSE_ONEDPL=DPCPP"
    append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
    append_opts "-DC_EXTRA_FLAGS=-march=znver3"
    ;;
  *) unknown_compiler ;;
  esac
  BENCHMARK_EXE="std-indices-tealeaf"
  ;;
sycl-acc)
  append_opts "-DMODEL=sycl-acc"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
  append_opts "-DC_EXTRA_FLAGS=-march=znver3"
  BENCHMARK_EXE="sycl-acc-tealeaf"
  ;;
sycl-usm)
  append_opts "-DMODEL=sycl-usm"
  append_opts "-DSYCL_COMPILER=ONEAPI-Clang"
  append_opts "-DCXX_EXTRA_FLAGS=-fsycl;-fsycl-targets=nvptx64-nvidia-cuda;-Xsycl-target-backend;--cuda-gpu-arch=sm_80;--cuda-path=$NVHPC_PATH/cuda/;-march=znver3"
  append_opts "-DC_EXTRA_FLAGS=-march=znver3"
  BENCHMARK_EXE="sycl-usm-tealeaf"
  ;;
*) unknown_model ;;
esac

handle_exec
