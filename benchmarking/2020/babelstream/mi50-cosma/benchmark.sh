#!/bin/bash

DEFAULT_COMPILER=gcc-9.3
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-9.3"
  echo "  aocc-2.2"
  echo "  hipcc"
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
export CONFIG="mi50"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
case "$COMPILER" in
gcc-9.3)
  module load gnu_comp/9.3.0
  MAKE_OPTS="COMPILER=GNU"
  ;;
aocc-2.2)
  module load aocc/2.2.0
  MAKE_OPTS="COMPILER=CLANG"
  ;;
hipcc)
  MAKE_OPTS="COMPILER=HIPCC"
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
  MAKE_OPTS+=" TARGET=GPU"
  BINARY="omp-stream"
  ;;
kokkos)

  if [ "$COMPILER" != "hipcc" ]; then
    echo
    echo " Must use hipcc with Kokkos module"
    echo
    exit 1
  fi

    #KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using develop branch of Kokkos to work with HIP 3.5"
    KOKKOS_PATH=$(pwd)/kokkos
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} TARGET=GPU ARCH=VEGA906 DEVICE=HIP CXX=hipcc"
    ;;

ocl)
  export LIBRARY_PATH=$LIBRARY_PATH:/opt/rocm/opencl/lib
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/opencl/lib
  export CPATH=$CPATH:/opt/rocm/opencl/include
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
  if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc) ; then
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
