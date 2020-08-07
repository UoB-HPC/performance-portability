#!/bin/bash

DEFAULT_COMPILER=cce-10.0
DEFAULT_MODEL=cuda
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  cce-10.0"
  echo "  gcc-6.1"
  echo "  llvm-10.0"
  echo "  pgi-19.10"
  echo "  hipsycl-trunk"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  cuda"
  echo "  acc"
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
export CONFIG="p100"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
#module swap craype-{mic-knl,broadwell}
#module load craype-accel-nvidia60

case "$COMPILER" in
cce-10.0)
  module purge
  module load gcc/7.4.0 # newer versions of libstdc++
  module load shared pbspro
  module load craype-broadwell
  module load PrgEnv-cray
  module swap cce cce/10.0.0
  module load craype-accel-nvidia60
  MAKE_OPTS='COMPILER=CRAY TARGET=NVIDIA EXTRA_FLAGS="-fopenmp -fopenmp-targets=nvptx64 -Xopenmp-target -march=sm_60"'
  ;;
llvm-10.0)
  module purge
  module load gcc/7.4.0 # newer versions of libstdc++
  module load llvm/10.0
  module load shared pbspro
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89

  #FIXME nvidia does not link with -Xopenmp-target -march=sm_60, llvm doesn't have libomptarget-nvptx-sm_60.bc
  MAKE_OPTS='COMPILER=CLANG TARGET=NVIDIA EXTRA_FLAGS=" -Xopenmp-target -march=sm_60"'
  ;;
gcc-6.1)
  module purge
  module load shared pbspro
  module load gcc/6.1.0
  MAKE_OPTS="COMPILER=GNU TARGET=GPU"
  ;;
pgi-19.10)
  module purge
  module load shared pbspro
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89
  module load pgi/compiler/19.10
  MAKE_OPTS='COMPILER=PGI TARGET=PASCAL'
  ;;
hipsycl-trunk)
  module purge
  module load shared pbspro
  module load gcc/8.2.0
  module load hipsycl/trunk
  MAKE_OPTS='COMPILER=HIPSYCL TARGET=NVIDIA ARCH=sm_60'
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

# Select Makefile to use
case "$MODEL" in
omp)
  MAKE_FILE="OpenMP.make"
  BINARY="omp-stream"
  ;;
kokkos)
  #  set -x
  if [ "$COMPILER" != "gcc-6.1" ]; then
    echo
    echo " Must use gcc-6.1 with Kokkos"
    echo
    stop
  fi
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89

  # TODO NVCC fails to compile kokkos
  NVCC=$(which nvcc)
  echo "Using NVCC=${NVCC}"
  CUDA_PATH=$(dirname $NVCC)/..

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  MAKE_FILE="Kokkos.make"
  BINARY="kokkos-stream"
  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=Pascal60 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper"
  MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
  MAKE_OPTS+=' EXTRA_INC="-I$CUDA_PATH/include/ -L$CUDA_PATH/lib64"'
  export OMP_PROC_BIND=spread
  ;;
cuda)
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89
  MAKE_FILE="CUDA.make"
  BINARY="cuda-stream"
  MAKE_OPTS+=' EXTRA_FLAGS="-arch=sm_60"'
  ;;
acc)
  MAKE_FILE="OpenACC.make"
  BINARY="acc-stream"
  ;;
ocl)
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89
  NVCC=$(which nvcc)
  CUDA_PATH=$(dirname $NVCC)/..
  MAKE_FILE="OpenCL.make"
  BINARY="ocl-stream"
  MAKE_OPTS+=' EXTRA_FLAGS="-I$CUDA_PATH/include/ -L$CUDA_PATH/lib64"'
  ;;
sycl)
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89
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

  if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
    echo
    echo "Build failed."
    echo
    exit 1
  fi

  # Rename binary
  mkdir -p $RUN_DIR
  mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE

elif [ "$ACTION" == "run" ]; then
  module load gcc/7.4.0 # newer versions of libstdc++
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  module load gcc/7.4.0 # newer versions of libstdc++
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-large-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run-large.job
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
