#!/bin/bash

DEFAULT_COMPILER=clang
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run  [MODEL]"
  echo

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
MODEL=${2:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export SRC_DIR=$PWD/CloverLeaf

# Set up the environment
module purge
module load cmake/3.14.5

CURRENT_SCRIPT_DIR=$SCRIPT_DIR
source /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh --force
SCRIPT_DIR=$CURRENT_SCRIPT_DIR
COMPILER=oneapi

export MODEL=$MODEL
case "$MODEL" in
omp)
  export SRC_DIR=$PWD/CloverLeaf_ref
  export OMP_TARGET_OFFLOAD="MANDATORY"
  MAKE_OPTS='COMPILER=INTEL OMP_INTEL="-qopenmp" MPI_COMPILER=mpiifort C_MPI_COMPILER=mpiicc'
  MAKE_OPTS+=' OPTIONS="-qnextgen -fiopenmp -fopenmp-targets=spir64"'
  MAKE_OPTS+=' C_OPTIONS="-qnextgen -fiopenmp -fopenmp-targets=spir64"'
  BINARY="clover_leaf"
  # FIXME  mpicc crashes with
  # parse.f90(86): catastrophic error: **Internal compiler error: internal abort** Please report this error along with the circumstances in which it occurred in a Software Problem Report.  Note: File and line given may not be explicit cause of this error.
  # compilation aborted for parse.f90 (code 1)
  ;;
opencl)
  module load intel/opencl/18.1
  module load khronos/opencl/headers khronos/opencl/icd-loader

  MAKE_OPTS='COMPILER=INTEL USE_OPENCL=1 \
        EXTRA_INC="-I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/CL/" \
        EXTRA_PATH="-I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/CL/"'

  BINARY="clover_leaf"
  ;;
sycl)
  BINARY="clover_leaf"
  MAKE_OPTS=" -DSYCL_RUNTIME=DPCPP"
  export SRC_DIR=$PWD/cloverleaf_sycl
  ;;
esac

export CONFIG="irispro580"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src $MODEL

  if [ "$MODEL" == "opencl" ]; then
    sed -i 's/ cl::Platform default_platform = all_platforms\[.\];/ cl::Platform default_platform = all_platforms[1];/g' CloverLeaf/src/openclinit.cpp
  fi

  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  cd $RUN_DIR || exit
  echo $SCRIPT_DIR

  bash "$SCRIPT_DIR/run.sh" CloverLeaf-$CONFIG.out
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
