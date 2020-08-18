#!/bin/bash

DEFAULT_COMPILER=gcc-8.3
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-8.3"
  echo "  armclang-20.2"
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
export CONFIG="graviton2"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
module purge
module use /mnt/shared/software/modulesfiles
case "$COMPILER" in
armclang-20.2)
  module load arm/20.2
  MAKE_OPTS='COMPILER=ARMCLANG TARGET=CPU EXTRA_FLAGS="-mcpu=neoverse-n1 -O3"'
  ;;
gcc-8.3)
  MAKE_OPTS="COMPILER=GNU"
  ;;
hipsycl)
  module load hipsycl/master
  MAKE_OPTS='COMPILER=HIPSYCL SYCL_SDK_DIR=/mnt/shared/software/hipsycl/master'
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
kokkos)

  if [ "$COMPILER" != "gcc-8.3" ]; then
    echo
    echo " Must use gcc-8.3 with Kokkos module"
    echo
    exit 1
  fi

    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv81 DEVICE=OpenMP"
    ;;

ocl)
  module load pocl/1.5
  MAKE_FILE="OpenCL.make"
  BINARY="ocl-stream"
  MAKE_OPTS="$MAKE_OPTS TARGET=GPU"
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
  eval $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  eval $SCRIPT_DIR/run-large.job
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
