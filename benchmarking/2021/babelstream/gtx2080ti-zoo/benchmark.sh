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
  echo "  pgi-19.10"
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  cuda"
  echo "  ocl"
  echo "  acc"
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
julia-1.6.2)
  module load julia/1.6.2
  ;;
clang)
  module load llvm/omptarget/10.0.0
  MAKE_OPTS='\
      COMPILER=CLANG \
      TARGET=NVIDIA \
      EXTRA_FLAGS="-Xopenmp-target -march=sm_75"'
  ;;
gcc-8.3)
  module load gcc/8.3.0
  MAKE_OPTS="COMPILER=GNU"
  ;;
pgi-19.10)
  module load pgi/19.10
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
  julia-ka)
    export JULIA_BACKEND="KernelAbstractions"
    JULIA_ENTRY="src/KernelAbstractionsStream.jl"
    BENCHMARK_EXE=$JULIA_ENTRY
    ;;
  julia-cuda)
    export JULIA_BACKEND="CUDA"
    JULIA_ENTRY="src/CUDAStream.jl"
    BENCHMARK_EXE=$JULIA_ENTRY
    ;;
esac

export MODEL="$MODEL"
# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  case "$MODEL" in
  omp)
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    ;;
  cuda)
    MAKE_FILE="CUDA.make"
    BINARY="cuda-stream"
    MAKE_OPTS='NVARCH=sm_75'
    ;;
  kokkos)

    if [ "$COMPILER" != "gcc-8.3" ]; then
      echo
      echo " Must use NVCC with Kokkos module"
      echo
      exit 1
    fi

    # For libstd++6
    module load gcc/8.3.0

    NVCC=$(which nvcc)
    echo "Using NVCC=${NVCC}"

    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" TARGET=GPU KOKKOS_PATH=${KOKKOS_PATH} ARCH=Turing75 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper "
    MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
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

  mkdir -p $RUN_DIR

  if [ -z ${JULIA_ENTRY+x} ]; then
    if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
      echo
      echo "Build failed."
      echo
      exit 1
    fi
    # Rename binary
    mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE
  else 
    cp -R "$SRC_DIR/JuliaStream.jl/." $RUN_DIR/
  fi  

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-large-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run-large.job
else
  echo
  echo "Invalid action"
  usage
  exit 1
fi

