#!/bin/bash

DEFAULT_COMPILER=gcc-9.3
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid compilers:"
  echo "  gcc-9.3"
  echo "  gcc-10.2"
  echo "  aocc-2.2"
  echo "  aomp-11.7"
  echo "  hipcc"
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  cuda"
  echo "  opencl"
  echo "    gcc-9.3"
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
export MODEL=${2:-$DEFAULT_MODEL}
COMPILER=${3:-$DEFAULT_COMPILER}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="mi50"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=clover_leaf
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"

# Set up the environment
case "$COMPILER" in
gcc-7.3)
  module load gnu_comp/7.3.0
  module load openmpi/3.0.1
  MAKE_OPTS="COMPILER=GNU"
  ;;
gcc-9.3)
  module load gnu_comp/9.3.0
  module load openmpi/4.0.3
  MAKE_OPTS="COMPILER=GNU"
  ;;
gcc-10.2)
  module use /cosma/home/do006/dc-deak1/bin/modulefiles
  module load gcc/10.2.0
  MAKE_OPTS="COMPILER=GNU"
  ;;
aocc-2.2)
  module load aocc/2.2.0
  MAKE_OPTS="COMPILER=CLANG"
  ;;
aomp-11.7)
  export PATH=/opt/rocm/aomp/bin:$PATH
  MAKE_OPTS="COMPILER=AOMP"
  ;;
hipcc)
  MAKE_OPTS="COMPILER=HIPCC"
  ;;
hipsycl)
  module use /cosma/home/do006/dc-deak1/bin/modulefiles
  module load hipsycl/master
  MAKE_OPTS='COMPILER=HIPSYCL SYCL_SDK_DIR=/cosma/home/do006/dc-deak1/bin/hipsycl/master EXTRA_FLAGS="--gcc-toolchain=/cosma/local/gcc/9.3.0"'
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
  if [ "$COMPILER" == "gcc-10.2" ]; then
    MAKE_OPTS+=" EXTRA_FLAGS='-foffload=-march=gfx906' TARGET=AMD"
  else
    MAKE_OPTS+=" TARGET=GPU"
  fi
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
acc)
  if [ "$COMPILER" != "gcc-10.2" ]; then
    echo
    echo " Must use gcc-10.2"
    echo
    exit 1
  fi

  MAKE_FILE="OpenACC.make"
  BINARY="acc-stream"
  MAKE_OPTS+=" EXTRA_FLAGS='-foffload=-march=gfx906' TARGET=AMD"
  ;;

opencl)
  if [ "$COMPILER" != "gcc-7.3" ]; then
    echo "Must use gcc-7.3"
    exit 1
  fi
  export LIBRARY_PATH=$LIBRARY_PATH:/opt/rocm/opencl/lib
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/opencl/lib
  export CPATH=$CPATH:/opt/rocm/opencl/include
  export SRC_DIR="$PWD/CloverLeaf_OpenCL"
  BINARY="clover_leaf"
  MAKE_OPTS="$MAKE_OPTS  OCL_VENDOR='AMD' COPTIONS='-DCL_TARGET_OPENCL_VERSION=110 -DOCL_IGNORE_PLATFORM -std=c++98'  OPTIONS='-lstdc++'"
  ;;

sycl)
  MAKE_FILE="SYCL.make"
  BINARY="sycl-stream" "$MODEL"
  MAKE_OPTS+=' TARGET=AMD ARCH=gfx906'
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src "$MODEL"

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  # Perform build
  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"


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
