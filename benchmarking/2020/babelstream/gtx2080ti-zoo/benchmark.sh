#!/bin/bash


# XXX must run `scl enable devtoolset-7 bash` for computecpp-2.x.x, not a requirement for 1.x.x

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
  echo "  hipsycl-trunk"
  echo "  computecpp-2.0 (host only)"  
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
pgi-19.10)
  module load pgi/19.10
  MAKE_OPTS="COMPILER=PGI"
  ;;
hipsycl-trunk)
  module load llvm/10.0
  module load hipsycl/master-jun-16
  ;;  
computecpp-2.0)
  # TODO does not run with PTX, it's here when ComputeCpp evntually supports it
  module load gcc/10.1.0
  module load computecpp/2.0.0
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



  if [[ $MODEL == "sycl" ]] && [[ "$COMPILER" == "hipsycl-trunk" ]]; then
    cd $SRC_DIR || exit
    syclcc -O3 -std=c++17 --hipsycl-gpu-arch=sm75  -DSYCL main.cpp SYCLStream.cpp -o sycl-stream
  else
    if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
      echo
      echo "Build failed."
      echo
      exit 1
    fi
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
