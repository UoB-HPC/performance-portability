#!/bin/bash

set -eu
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  cuda"
  echo "  ocl"
  echo "  acc"
  echo "  sycl"
  echo
  echo "The default programming model is '$DEFAULT_MODEL'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ACTION=$1
MODEL=${2:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export SRC_DIR=$PWD/CloverLeaf

module purge
module load cuda/10.1
module load cmake/3.14.5

export MODEL=$MODEL
case "$MODEL" in
omp)
  MAKE_FILE="OpenMP.make"
  BINARY="omp-stream"
  ;;
cuda)
  COMPILER=gcc-8.3
  module load gcc/8.3.0
  module load openmpi/4.0.1/gcc-8.3
  export MAKEFLAGS='-j16'
  export SRC_DIR=$PWD/CloverLeaf
  MAKE_OPTS='COMPILER=GNU USE_CUDA=1'
  BINARY="clover_leaf"
  ;;
ocl)
  COMPILER=gcc-8.3
  module load gcc/8.3.0
  module load openmpi/4.0.1/gcc-8.3
  export MAKEFLAGS='-j16'
  export SRC_DIR=$PWD/CloverLeaf_OpenCL
  MAKE_OPTS='COMPILER=GNU USE_OPENCL=1 OCL_VENDOR=NVIDIA \
        COPTIONS="-std=c++98 -DCL_TARGET_OPENCL_VERSION=110 -DOCL_IGNORE_PLATFOR" \
        OPTIONS="-lstdc++ -cpp -lOpenCL" \
        EXTRA_INC="-I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/CL/" \
        EXTRA_PATH="-I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/CL/ "'
  BINARY="clover_leaf"
  ;;
kokkos)
  COMPILER=gcc-8.3
  module load gcc/8.3.0
  module load openmpi/4.0.1/gcc-8.3

  NVCC=$(which nvcc)
  echo "Using NVCC=${NVCC}"

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"

  MPI_LIB="/nfs/software/x86_64/openmpi/4.0.1/gcc-8.3.0/lib"

  export LIBRARY_PATH=$MPI_LIB:$LIBRARY_PATH
  export LD_LIBRARY_PATH=$MPI_LIB:$LD_LIBRARY_PATH

  MAKE_OPTS="CXX=${KOKKOS_PATH}/bin/nvcc_wrapper"
  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=Turing75 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper"
  MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
  MAKE_OPTS+=' OPTIONS=" -lmpi -O3 "'
  export SRC_DIR=$PWD/cloverleaf_kokkos
  BINARY="clover_leaf"
  ;;
acc)
  COMPILER=pgi-19.10
  module load pgi/19.10
  export PATH=$PATH:/nfs/software/x86_64/pgi/19.10/linux86-64-llvm/19.10/mpi/openmpi-3.1.3/bin

  export SRC_DIR=$PWD/CloverLeaf-OpenACC

  export OMPI_CC=pgcc
  export OMPI_FC=pgfortran
  MAKE_OPTS='COMPILER=PGI C_MPI_COMPILER=mpicc MPI_F90=mpif90 \
        FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=tesla:cc75" CFLAGS_PGI="-O3 -ta=tesla:cc75" OMP_PGI="" '
        #OPTIONS="-ta=tesla:cc70 -L/opt/local-modules/pgi/linux86-64/18.10/lib/ -Wl,-rpath,/opt/local-modules/pgi/linux86-64/18.10/lib/ -lpgm" \
        #C_OPTIONS="-ta=tesla:cc70 -L/opt/local-modules/pgi/linux86-64/18.10/lib/ -Wl,-rpath,/opt/local-modules/pgi/linux86-64/18.10/lib/ -lpgm"'
  BINARY="clover_leaf"
  ;;
sycl)
  COMPILER=hipsycl
#  module load hipsycl/master-jun-16
  module load hipsycl/master-mar-18
  module load gcc/8.3.0
  module load openmpi/4.0.1/gcc-8.3

  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"

  MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc"
  MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=native -DHIPSYCL_PLATFORM=cuda -DHIPSYCL_GPU_ARCH=sm_75"

  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_sycl
  ;;
*)
  echo
  echo "Invalid model '$MODEL'."
  usage
  exit 1
  ;;
esac

export CONFIG="gtx2080ti"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

# Handle actions
if [ "$ACTION" == "build" ]; then

  case "$MODEL" in
  cuda) # cl uses the universal port
    fetch_src "ocl"
    ;;
  *)
    fetch_src $MODEL
    ;;
  esac

  fetch_src $MODEL

  #if [ "$MODEL" == "ocl" ]; then
  #  sed -i 's/ cl::Platform default_platform = all_platforms\[.\];/ cl::Platform default_platform = all_platforms[0];/g' CloverLeaf/src/openclinit.cpp
  #fi

  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  cd $RUN_DIR || exit
  bash "$SCRIPT_DIR/run.sh" CloverLeaf-$CONFIG.out
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
