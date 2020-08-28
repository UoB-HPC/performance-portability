#!/bin/bash

DEFAULT_COMPILER=gcc-9.1
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run|run-large [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-9.1"
  echo "  intel-2020"
  echo "  aocc-2.1"
  echo "  pgi-19.10" 
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  sycl"
  echo "  ocl"
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
export CONFIG="rome"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
case "$COMPILER" in
gcc-9.1)
  module purge
  module load lang/gcc/9.1.0
  MAKE_OPTS="COMPILER=GNU TARGET=CPU EXTRA_FLAGS='-march=znver2'"
  ;;
intel-2020)
  module purge
  module load lang/intel-parallel-studio-xe/2020 
  MAKE_OPTS="COMPILER=INTEL TARGET=CPU FLAGS_INTEL='-O3 -std=c++11'"
  ;;
aocc-2.1)
  module purge
  module use /home/td8469/software/modulefiles
  module load aocc/2.1.0
  MAKE_OPTS="COMPILER=CLANG TARGET=CPU EXTRA_FLAGS='-fnt-store=aggressive -march=znver2 -mcmodel=medium'"
  ;;
pgi-19.10)
  module purge
  module use /home/td8469/software/modulefiles
  module load pgi/19.10
  MAKE_OPTS="COMPILER=PGI TARGET=CPU EXTRA_FLAGS='-ta=multicore -tp=zen'"
  ;;
hipsycl)
  module use /home/td8469/software/modulefiles
  module load hipsycl/master-12-jun-2020
  MAKE_OPTS="COMPILER=HIPSYCL SYCL_SDK_DIR=/work/td8469/software/hipsycl"
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
  rm -f $RUN_DIR/$BENCHMARK_EXE

  # Select Makefile to use
  case "$MODEL" in
  omp)
    #    module load kokkos/3.1.1/cce-9.1
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    ;;
  kokkos)
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=EPYC DEVICE=OpenMP"
    ;;
  acc)
    MAKE_FILE="OpenACC.make"
    BINARY="acc-stream"
    MAKE_OPTS+=' TARGET=AMD'
    if [ "$COMPILER" != "pgi-19.10" ]
    then
      echo
      echo " Must use PGI with OpenACC"
      echo
      exit 1
    fi
  ;;
  sycl)
    MAKE_FILE="SYCL.make"
    BINARY="sycl-stream"
    MAKE_OPTS+=' TARGET=CPU'
  ;;
  ocl)
    module use $HOME/software/modulefiles
    module load pocl/1.5
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
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
