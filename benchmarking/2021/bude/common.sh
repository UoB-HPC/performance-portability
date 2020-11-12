# shellcheck shell=bash

set -eu
set -o pipefail

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

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid model and compiler options for BUDE:"
  echo "  omp"
  echo "    arm-20.0"
  echo "    cce-10.0"
  echo "    cce-sve-10.0"
  echo "    gcc-8.1"
  echo "    gcc-9.3"
  echo "    gcc-10.2"
  echo "    gcc-11.0"
  echo
  echo "  omp-target"
  echo "    cce-10.0"
  echo "    llvm-10.0"
  echo
  echo "  ocl"
  echo "    gcc-9.3"
  echo
  echo "  cuda"
  echo "    gcc-8.1"
  echo
  echo "  kokkos"
  echo "    arm-20.0"
  echo "    cce-10.0"
  echo "    gcc-9.3"
  echo
  echo "  sycl"
  echo "    hipsycl-200527-gcc"
  echo "    oneapi-2021.1-beta10"
  echo
  echo "Selected platform: $PLATFORM"
  echo "  Compilers available: $COMPILERS"
  echo "  Models available: $MODELS"
  echo
  echo "The default configuration is '$DEFAULT_MODEL $DEFAULT_COMPILER'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
elif [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
  usage
  exit
fi


action="$1"
export MODEL="${2:-$DEFAULT_MODEL}"
export COMPILER="${3:-$DEFAULT_COMPILER}"
export CONFIG="${PLATFORM}_${COMPILER}_${MODEL}"

if [[ ! "$MODELS" =~ $MODEL ]] || [[ ! "$COMPILERS" =~ $COMPILER ]]; then
  echo "Configuration '$MODEL $COMPILER' not available on $PLATFORM."
  exit 2
fi

export SRC_DIR="$PWD/bude-portability-benchmark"
export RUN_DIR="$PWD/bude-$CONFIG"
export BENCHMARK_EXE="bude_$CONFIG"

# Set up the environment
setup_env

USE_CMAKE=false
# Setup model
case "$MODEL" in
  omp)
    SRC_DIR+="/openmp"
    RUN_DIR="$SRC_DIR"
    ;;

  omp-target)
    if ! [[ "$COMPILER" =~ (cce|llvm)-10.0 ]]; then
      echo "Model '$MODEL' can only be used with compilers: cce-10.0 llvm-10.0."
      exit 3
    fi

    SRC_DIR+="/openmp-target"
    RUN_DIR="$SRC_DIR"
    ;;

  ocl)
    SRC_DIR+="/opencl"
    RUN_DIR="$SRC_DIR"
    ;;

  cuda)
    if [ "$COMPILER" != gcc-8.1 ]; then
      echo "Model '$MODEL' can only be used with compiler 'gcc-8.1'."
      exit 3
    fi

    SRC_DIR+="/cuda"
    RUN_DIR="$SRC_DIR"
    MAKE_OPTS+=" COMPILER=GNU"
    ;;

  kokkos)
    echo "$MODEL is not implemented" && exit 99
    ;;

  sycl)
    SRC_DIR+="/sycl"
    RUN_DIR="$SRC_DIR"
    USE_CMAKE=true
    ;;

  *)
    echo
    echo "Invalid model '$MODEL'."
    usage
    exit 1
    ;;
esac

# Fetch source
if [ ! -e bude-portability-benchmark/openmp/bude.c ]; then
  if ! git clone https://github.com/UoB-HPC/bude-portability-benchmark.git; then
    echo
    echo "Failed to fetch source code."
    echo
    exit 1
  fi
fi

cd "$SRC_DIR"

# Handle actions
if [ "$action" == "build" ]; then

  rm -f "$BENCHMARK_EXE"
  if [ "$USE_CMAKE" = true ]; then

    echo "Using opts: ${MAKE_OPTS}"
    rm -rf build
    read -ra CMAKE_OPTS <<<"${MAKE_OPTS}" # explicit word splitting
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release "${CMAKE_OPTS[@]}"
    cmake --build build --target bude --config Release -j "$(nproc)"
    mv build/bude "$BENCHMARK_EXE"

  else
    make clean
    if ! eval make -B "$MAKE_OPTS" -j; then
      echo
      echo "Build failed."
      echo
      exit 1
    fi
    mv bude "$BENCHMARK_EXE"
  fi
elif [ "$action" == "run" ]; then
  # Check binary exists
  if [ ! -x "$BENCHMARK_EXE" ]; then
    echo "Executable '$BENCHMARK_EXE' not found."
    echo "Use the 'build' action first."
    exit 1
  fi

  qsub -o "bude-$CONFIG.out" -e "bude-$CONFIG.err" -N "bude-$CONFIG" -V "$SCRIPT_DIR/run.job"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
