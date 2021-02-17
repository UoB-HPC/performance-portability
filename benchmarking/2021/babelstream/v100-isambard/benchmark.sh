#!/bin/bash

DEFAULT_COMPILER=gcc-7.3
DEFAULT_MODEL=cuda
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-7.3" # CUDA 10 only supports GCC <= 7!
  echo "  llvm-trunk"
  echo "  pgi-19.10"
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos" # TODO track Kokkos 3
  echo "  cuda"
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
export MODEL="$MODEL"
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="v100"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
# module load cuda/10.0



case "$COMPILER" in
llvm-trunk)
  module load craype-accel-nvidia70
  module load cuda10.2/toolkit/10.2.89
  module load llvm/trunk
  MAKE_OPTS='COMPILER=CLANG TARGET=NVIDIA EXTRA_FLAGS="-Xopenmp-target -march=sm_70"'
  ;;
gcc-8.1)
  module load gcc/8.1.0
  module load craype-accel-nvidia70
  module load cuda10.2/toolkit/10.2.89
  MAKE_OPTS="COMPILER=GNU TARGET=NVIDIA"
  export OMP_PROC_BIND=spread
  ;;
gcc-10.2)
  module load gcc/10.2.0
  module load craype-accel-nvidia70
  module load cuda10.2/toolkit/10.2.89
  MAKE_OPTS="COMPILER=GNU TARGET=NVIDIA"
  export OMP_PROC_BIND=spread
  ;;  
cce-10.0)
  module load gcc/8.2.0 # for libstdc++ only
  module load PrgEnv-cray
  module swap cce cce/10.0.0
  module load craype-accel-nvidia70
  module load cuda10.2/toolkit/10.2.89
  MAKE_OPTS='COMPILER=CRAY TARGET=NVIDIA OMP_CRAY_NVIDIA="-DOMP_TARGET_GPU -fopenmp -fopenmp-targets=nvptx64 -Xopenmp-target -march=sm_70"'
  ;;  
pgi-19.10)
  module load pgi/compiler/19.10
  MAKE_OPTS='COMPILER=PGI TARGET=VOLTA'
  ;;
hipsycl)
  module load hipsycl/jul-8-20
  MAKE_OPTS="COMPILER=HIPSYCL TARGET=NVIDIA ARCH=sm_70 SYCL_SDK_DIR=/lustre/projects/bristol/modules-power/hipsycl/jul-8-20"
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

    #module load gcc/8.1.0

    NVCC=$(which nvcc)
    echo "Using NVCC=${NVCC}"

    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" TARGET=GPU KOKKOS_PATH=${KOKKOS_PATH} ARCH=Volta70 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper "
    MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
    export OMP_PROC_BIND=spread
    ;;
  cuda)
    MAKE_FILE="CUDA.make"
    BINARY="cuda-stream"
    MAKE_OPTS+=' EXTRA_FLAGS="-arch=sm_70"'
    NVCC=`which nvcc`
    CUDA_PATH=`dirname $NVCC`/..
    export LD_LIBRARY_PATH=$CUDA_PATH/lib64
    ;;
  acc)
    MAKE_FILE="OpenACC.make"
    BINARY="acc-stream"
    ;;
  ocl)
    CL_HEADER_DIR="$PWD/OpenCL-Headers-2020.06.16"
    # XXX BabelStream should really just ship with CL headers
    if [ ! -d "$CL_HEADER_DIR" ]; then
      wget https://github.com/KhronosGroup/OpenCL-Headers/archive/v2020.06.16.tar.gz
      tar -xf v2020.06.16.tar.gz
    fi
    MAKE_OPTS+=" EXTRA_FLAGS='-I$CL_HEADER_DIR'"
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
    ;;
  omp-target)
    # icpx(icc) supports offloading too, see
    # https://software.intel.com/content/www/us/en/develop/documentation/get-started-with-cpp-fortran-compiler-openmp
    if ! [[ "$COMPILER" =~ (cce|gcc|llvm)-10 || "$COMPILER" =~ (aomp|icpx) ]]; then
      echo "Model '$MODEL' can only be used with compilers: cce-10.0 llvm-10.0."
      exit 3
    fi
    
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
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
