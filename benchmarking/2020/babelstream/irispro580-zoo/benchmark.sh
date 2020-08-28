#!/bin/bash

DEFAULT_COMPILER=clang
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  oneapi"
  echo "  gcc-10.1"
  echo
  echo "Valid models:"
  echo "  omp"
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
export CONFIG="irispro580"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
module purge
#set -x
case "$COMPILER" in
oneapi)
  # XXX oneapi changes SCRIPT_DIR, restore it after sourcing
  CURRENT_SCRIPT_DIR=$SCRIPT_DIR
  source /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh --force
  SCRIPT_DIR=$CURRENT_SCRIPT_DIR
  ;;
gcc-10.1)
  module load gcc/10.1.0
  MAKE_OPTS="COMPILER=GNU"
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
  export OMP_TARGET_OFFLOAD="MANDATORY"
  MAKE_OPTS='COMPILER=INTEL TARGET=INTEL_GPU'
  MAKE_FILE="OpenMP.make"
  BINARY="omp-stream"
  export DEVICE_ARGS=""
  ;;
ocl)
  module load intel/opencl/18.1
  module load khronos/opencl/headers khronos/opencl/icd-loader
  #  module load intel/opencl/experimental/2020.10.3.0.04
  MAKE_FILE="OpenCL.make"
  BINARY="ocl-stream"
  MAKE_OPTS="$MAKE_OPTS TARGET=GPU"
  export DEVICE_ARGS=""
  ;;
sycl)
  MAKE_OPTS='COMPILER=DPCPP'
  MAKE_FILE="SYCL.make"
  BINARY="sycl-stream"
  export DEVICE_ARGS="--device 1"
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
  echo $SCRIPT_DIR

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
