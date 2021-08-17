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
module load rocm/node30/3.10.0

case "$COMPILER" in
julia-1.6.2)
  module load julia/1.6.2
  ;;
gcc-10.1)
  MAKE_OPTS='COMPILER=GNU'
  ;;
hipcc-3.10)
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
  julia-ka)
    export JULIA_BACKEND="KernelAbstractions"
    JULIA_ENTRY="src/KernelAbstractionsStream.jl"
    BENCHMARK_EXE=$JULIA_ENTRY
    ;;
  julia-amdgpu)
    export JULIA_BACKEND="AMDGPU"
    JULIA_ENTRY="src/AMDGPUStream.jl"
    BENCHMARK_EXE=$JULIA_ENTRY
    ;;
esac

export MODEL="$MODEL"
# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src

  rm -f $BENCHMARK_EXE

  case "$MODEL" in
  julia-*)
    # nothing to do
    ;;
  ocl)
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
    ;;
  hip)
    MAKE_FILE="HIP.make"
    BINARY="hip-stream"
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

