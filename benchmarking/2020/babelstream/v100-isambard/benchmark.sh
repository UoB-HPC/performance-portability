#!/bin/bash

DEFAULT_COMPILER=gcc-7.3
DEFAULT_MODEL=cuda
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-7.3" # CUDA 10 only supports GCC <= 7!
  echo "  llvm-trunk"
  echo "  pgi-19.10"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos" # TODO track Kokkos 3
  echo "  cuda"
  echo "  acc"
  echo
  echo "The default configuration is '$DEFAULT_COMPILER'."
  echo "The default programming model is '$DEFAULT_MODEL'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ACTION=$1
COMPILER=${2:-$DEFAULT_COMPILER}
MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="v100"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
module load cuda/10.0
case "$COMPILER" in
llvm-trunk)
  module load llvm/trunk
  MAKE_OPTS='COMPILER=CLANG TARGET=NVIDIA EXTRA_FLAGS="-Xopenmp-target -march=sm_70"'
  ;;
gcc-7.3)
  source /opt/rh/devtoolset-7/enable
  MAKE_OPTS="COMPILER=GNU TARGET=NVIDIA"
  export OMP_PROC_BIND=spread
  ;;
pgi-19.10)
  module load pgi/compiler/19.10
  MAKE_OPTS='COMPILER=PGI TARGET=VOLTA'
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then

   # Fetch source code
  fetch_src

  # Perform build
  rm -f $BENCHMARK_EXE

  # Select Makefile to use
  case "$MODEL" in
  omp)
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    ;;
  kokkos)
    module load kokkos/volta
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" CXX=$KOKKOS_PATH/bin/nvcc_wrapper"
    ;;
  cuda)
    MAKE_FILE="CUDA.make"
    BINARY="cuda-stream"
    MAKE_OPTS+=' EXTRA_FLAGS="-arch=sm_70"'
    #NVCC=`which nvcc`
    #CUDA_PATH=`dirname $NVCC`/..
    #export LD_LIBRARY_PATH=$CUDA_PATH/lib64
    ;;
  acc)
    MAKE_FILE="OpenACC.make"
    BINARY="acc-stream"
    ;;
  esac

  if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS; then
    echo
    echo "Build failed."
    echo
    exit 1
  fi

  # Rename binary
  mkdir -p $RUN_DIR
  mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  cd $RUN_DIR || exit
    bash "$SCRIPT_DIR/run.sh" BabelStream-$CONFIG.out
elif [ "$ACTION" == "run-large" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  cd $RUN_DIR || exit
    bash "$SCRIPT_DIR/run-large.sh" BabelStream-large-$CONFIG.out
else
  echo
  echo "Invalid action"
  usage
  exit 1
fi
