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
  echo "  hipsycl"
  echo "  julia-1.6.2"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos" # TODO track Kokkos 3
  echo "  cuda"
  echo "  acc"
  echo "  sycl"
  echo "  julia-threaded"
  echo "  julia-ka"
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
export MODEL="$MODEL"
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="a100"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
# module load cuda/10.0



case "$COMPILER" in
julia-1.6.2)
    # XXX don't load anything related to CUDA here, Julia needs a specific
    # version of the toolkit which is fetched as part of `Pkg.instantiate()`
    export PATH="/home/hpclin2/julia-1.6.2/bin:$PATH"
    ;;
gcc-8.4.0)
  module load cuda/11.2
  module load gcc/8
  MAKE_OPTS="COMPILER=GNU TARGET=NVIDIA"
  export OMP_PROC_BIND=spread
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

# Handle actions
if [ "$ACTION" == "build" ]; then

  # Fetch source code
  fetch_src

  # Perform build
  rm -f $BENCHMARK_EXE

  # Select Makefile to use
  case "$MODEL" in
  julia-*)
    # nothing to do
    ;;
  omp)
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    ;;
  kokkos)

    #module load gcc/8.1.0

    NVCC=$(which nvcc)
    echo "Using NVCC=${NVCC}"

    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" TARGET=GPU KOKKOS_PATH=${KOKKOS_PATH} ARCH=AMPERE80 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper "
    MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
    export OMP_PROC_BIND=spread
    ;;
  cuda)
    MAKE_FILE="CUDA.make"
    BINARY="cuda-stream"
    MAKE_OPTS+=' NVARCH=sm_80'
    NVCC=`which nvcc`
    CUDA_PATH=`dirname $NVCC`/..
    export LD_LIBRARY_PATH=$CUDA_PATH/lib64
    ;;
  ocl)
    CL_HEADER_DIR="$PWD/OpenCL-Headers-2020.06.16"
    # XXX BabelStream should really just ship with CL headers
    if [ ! -d "$CL_HEADER_DIR" ]; then
      wget https://github.com/KhronosGroup/OpenCL-Headers/archive/v2020.06.16.tar.gz
      tar -xf v2020.06.16.tar.gz
    fi
    MAKE_OPTS+=" EXTRA_FLAGS='-I$CL_HEADER_DIR'"
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
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
  echo $PWD
  sbatch --output $PWD/BabelStream-$CONFIG.out -J babelstream $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  
  sbatch --output $PWD/BabelStream-large-$CONFIG.out -J babelstream $SCRIPT_DIR/run-large.job
else
  echo
  echo "Invalid action"
  usage
  exit 1
fi
