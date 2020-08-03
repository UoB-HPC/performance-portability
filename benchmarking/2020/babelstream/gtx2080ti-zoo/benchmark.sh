#!/bin/bash

DEFAULT_COMPILER=clang
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  clang"
  echo "  gcc-4.8"
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  cuda"
  echo "  ocl"
  echo "  sycl"
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
export CONFIG="gtx2080ti"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
module purge
module load cuda/10.1
case "$COMPILER" in
clang)
  module load llvm/trunk
  MAKE_OPTS='\
      COMPILER=CLANG \
      TARGET=NVIDIA \
      EXTRA_FLAGS="-Xopenmp-target -march=sm_75 --cuda-path=/nfs/software/x86_64/cuda/10.1"'
  ;;
gcc-4.8)
  MAKE_OPTS="COMPILER=GNU"
  ;;
pgi-19.4)
  MAKE_OPTS='\
      COMPILER=PGI'
  ;;
hipsycl)
  module load hipsycl/master-jun-16
  MAKE_OPTS='COMPILER=HIPSYCL TARGET=NVIDIA ARCH=sm_75'
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

case "$MODEL" in
omp)
  MAKE_FILE="OpenMP.make"
  BINARY="omp-stream"
  ;;
cuda)
  MAKE_FILE="CUDA.make"
  BINARY="cuda-stream"
  MAKE_OPTS='\
      EXTRA_FLAGS="-arch=sm_75"'
  ;;
kokkos)

  if [ "$COMPILER" != "gcc-4.8" ]; then
    echo
    echo " Must use NVCC with Kokkos module"
    echo
    exit 1
  fi
# TODO NVCC fails to compile kokkos
  NVCC=$(which nvcc)
  CUDA_PATH=$(dirname $NVCC)/..

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  MAKE_FILE="Kokkos.make"
  BINARY="kokkos-stream"
  MAKE_OPTS+=" TARGET=GPU KOKKOS_PATH=${KOKKOS_PATH} ARCH=Volta72 DEVICE=Cuda NVCC_WRAPPER=${NVCC}"
  export OMP_PROC_BIND=spread

  ;;
ocl)
  MAKE_FILE="OpenCL.make"
  BINARY="ocl-stream"
  MAKE_OPTS="$MAKE_OPTS TARGET=GPU"
  ;;
acc)
  MAKE_FILE="OpenACC.make"
  BINARY="acc-stream"
  MAKE_OPTS="$MAKE_OPTS TARGET=VOLTA"
  ;;
sycl)
  export HIPSYCL_CUDA_PATH=$(realpath $(dirname $(which nvcc))/..)

  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
  MAKE_OPTS+=" SYCL_SDK_DIR=${HIPSYCL_PATH}"
  MAKE_FILE="SYCL.make"
  BINARY="sycl-stream"
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  # Perform build
  if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
    echo
    echo "Build failed."
    echo
    exit 1
  fi

  mkdir -p $RUN_DIR
  # Rename binary
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
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
