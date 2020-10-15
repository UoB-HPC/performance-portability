#!/bin/bash

DEFAULT_COMPILER=xl-16.1
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  xl-16.1"
  echo "  gcc-8.1"
  echo "  pgi-19.10"
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
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
export CONFIG="power9"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
case "$COMPILER" in
xl-16.1)
  MAKE_OPTS="COMPILER=XL TARGET=CPU"
  ;;
gcc-8.1)
  module purge
  module load gcc/8.1.0
  MAKE_OPTS="COMPILER=GNU_PPC TARGET=CPU"
  ;;
pgi-19.10)
  module load pgi/compiler/19.10
  MAKE_OPTS="COMPILER=PGI TARGET=CPU"
  ;;
hipsycl)
  module load hipsycl/jul-8-20
  MAKE_OPTS="COMPILER=HIPSYCL TARGET=CPU SYCL_SDK_DIR=/lustre/projects/bristol/modules-power/hipsycl/jul-8-20"
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
    if [ "$COMPILER" != "gcc-8.1" ]; then
      echo
      echo "Must use gcc-8.1 with Kokkos"
      echo
      stop
    fi
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS="COMPILER=GNU TARGET=CPU"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=POWER9 DEVICE=OpenMP"
    export OMP_PROC_BIND=spread
    ;;
  acc)
    MAKE_FILE="OpenACC.make"
    BINARY="acc-stream"
    MAKE_OPTS+=" TARGET=PWR9"
    if [ "$COMPILER" != "pgi-19.10" ]; then
      echo
      echo "Must use pgi-19.10 with OpenACC"
      echo
      stop
    fi
    ;;
  sycl)
    MAKE_FILE="SYCL.make"
    BINARY="sycl-stream"
    ;;
  esac

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
