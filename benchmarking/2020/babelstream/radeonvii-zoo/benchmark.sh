#!/bin/bash

DEFAULT_COMPILER=gcc-9.1
DEFAULT_MODEL=ocl
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-10.1"
  echo "  hipcc"
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  ocl"
  echo "  omp"
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
export CONFIG="radeonvii"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
module purge
module load gcc/10.1.0
module load rocm/node30-paths
case "$COMPILER" in
gcc-10.1)
  MAKE_OPTS='COMPILER=GNU'
  ;;
hipcc)
  MAKE_OPTS='COMPILER=HIPCC'
  ;;
hipsycl)
  module load hipsycl/master-mar-18
  MAKE_OPTS='COMPILER=HIPSYCL TARGET=AMD ARCH=gfx906'
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

case "$MODEL" in
ocl)
  MAKE_FILE="OpenCL.make"
  BINARY="ocl-stream"
  ;;
kokkos)

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  MAKE_FILE="Kokkos.make"
  BINARY="kokkos-stream"
  export CXX=hipcc
  # XXX
  # TARGET=AMD isn't a thing in BabelStream but TARGET=CPU is misleading and TARGET=GPU uses nvcc
  # for CXX which is not what we want so we use a non-existent target
  # CXX needs to be specified again as we can't export inside BabelStream's makefile
  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} TARGET=AMD ARCH=Vega906 DEVICE=HIP CXX=hipcc"
  export OMP_PROC_BIND=spread
  ;;
omp)
  MAKE_OPTS+=' TARGET=AMD'
  MAKE_OPTS+=' EXTRA_FLAGS="-foffload=amdgcn-amdhsa="-march=gfx906""'
  MAKE_FILE="OpenMP.make"
  BINARY="omp-stream"
  ;;
acc)
  MAKE_OPTS+=' EXTRA_FLAGS="-foffload=amdgcn-amdhsa="-march=gfx906""'
  MAKE_FILE="OpenACC.make"
  BINARY="acc-stream"
  ;;
sycl)
#  module load gcc/8.3.0
#  export HIPSYCL_CUDA_PATH=$(realpath $(dirname $(which nvcc))/..)

#  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  #HIPSYCL_PATH="/nfs/home/wl14928/hipSYCL/build/x"
  HIPSYCL_PATH="/nfs/software/x86_64/hipsycl/master"
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
  MAKE_OPTS+=" SYCL_SDK_DIR=${HIPSYCL_PATH}"
  MAKE_FILE="SYCL.make"
  BINARY="sycl-stream"
  ;;
*)
  echo
  echo "Invalid model '$MODEL'."
  usage
  exit 1
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src

  rm -f $BENCHMARK_EXE

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
