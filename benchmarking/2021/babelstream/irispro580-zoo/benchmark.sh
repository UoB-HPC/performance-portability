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

function loadOneAPI() {
  if [ -z "${1:-}" ]; then
    echo "${FUNCNAME[0]}: Usage: ${FUNCNAME[0]} /path/to/oneapi/source.sh"
    echo "No OneAPI path provided. Stop."
    exit 5
  fi

  local oneapi_env="${1}"

  set +u # setvars can't handle unbound vars
  CURRENT_SCRIPT_DIR="$SCRIPT_DIR" # save current script dir as the setvars overwrites it

  # their script also terminates the shell for some reason so we short-circuit it first
  source "$oneapi_env"  --force || true

  set -u
  SCRIPT_DIR="$CURRENT_SCRIPT_DIR" #recover script dir
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
module load intel/neo/20.49.18626
#set -x
case "$COMPILER" in
julia-1.6.2)
  module load julia/1.6.2
  ;;
dpcpp-2021.1)
  module load gcc/8.3.0 # make sure the base compile isn't too old
  loadOneAPI /nfs/software/x86_64/intel/oneapi/2021.1/setvars.sh
  ;;  
oneapi)
  # XXX oneapi changes SCRIPT_DIR, restore it after sourcing
  CURRENT_SCRIPT_DIR=$SCRIPT_DIR
  source /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh --force
  SCRIPT_DIR=$CURRENT_SCRIPT_DIR
  ;;
gcc-8.3)
  module load gcc/8.3.0
  MAKE_OPTS='COMPILER=GNU'
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
  julia-oneapi)
    export JULIA_BACKEND="oneAPI"
    JULIA_ENTRY="src/oneAPIStream.jl"
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
  julia-*)
    # nothing to do
    ;;
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
