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
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export SRC_DIR=$PWD/CloverLeaf
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

# Set up the environment
module purge
module load cmake/3.14.5

case "$COMPILER" in
oneapi)
  # XXX oneapi changes SCRIPT_DIR, restore it after sourcing
  CURRENT_SCRIPT_DIR=$SCRIPT_DIR
  source /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh --force
  SCRIPT_DIR=$CURRENT_SCRIPT_DIR
  ;;
gcc-10.1)
  module load gcc/10.1.0
  MAKE_OPTS='COMPILER=GNU MPI_COMPILER=cc C_MPI_COMPILER=cc'
  MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -funroll-loops"'
  export OMP_PROC_BIND=spread
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
  MAKE_OPTS='MPI_COMPILER=mpiifort C_MPI_COMPILER=mpiicc OPTIONS="-qnextgen -fiopenmp -fopenmp-targets=spir64" C_OPTIONS="-qnextgen -fiopenmp -fopenmp-targets=spir64"'
  MAKE_FILE="OpenMP.make"
  BINARY="clover_leaf"
  # FIXME  mpicc crashes with
  #  parse.f90(86): catastrophic error: **Internal compiler error: internal abort** Please report this error along with the circumstances in which it occurred in a Software Problem Report.  Note: File and line given may not be explicit cause of this error.
  #  compilation aborted for parse.f90 (code 1)

  export DEVICE_ARGS=""
  ;;
opencl)
  module load intel/opencl/18.1
  module load khronos/opencl/headers khronos/opencl/icd-loader
  #  module load intel/opencl/experimental/2020.10.3.0.04
  MAKE_FILE="OpenCL.make"
  BINARY="ocl-stream"
  MAKE_OPTS='COMPILER=GNU USE_OPENCL=1 \
        EXTRA_INC="-I/usr/local/cuda-10.1/targets/x86_64-linux/include/CL/" \
        EXTRA_PATH="-I/usr/local/cuda-10.1/targets/x86_64-linux/include/CL/"'
  export DEVICE_ARGS=""
  ;;
sycl)
  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_sycl
  export DEVICE_ARGS="--device 1"
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src $MODEL

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE
  pwd
  if [ "$MODEL" == "sycl" ]; then
    cd $SRC_DIR || exit
    #    rm -rf build
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release -DSYCL_RUNTIME=DPCPP
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv build/$BINARY $BINARY
    cd $SRC_DIR/.. || exit
  else
    # Perform build
    if ! eval make -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
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
  echo $SCRIPT_DIR

  bash "$SCRIPT_DIR/run.sh" BabelStream-$CONFIG.out
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
