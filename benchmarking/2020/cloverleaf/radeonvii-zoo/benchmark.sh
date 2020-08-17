#!/bin/bash

DEFAULT_MODEL=ocl
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL]"
  echo
  echo "Valid models:"
  echo "  opencl"
  echo "  omp"
  echo "  acc"
  echo "  sycl"
  echo
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

module purge
#module load gcc/10.1.0
module load rocm/node30-paths
module load cmake/3.14.5

export MODEL=$MODEL
case "$MODEL" in
opencl)
  COMPILER=gcc-8.3

  module load gcc/8.3.0 openmpi/4.0.1/gcc-8.3
  export SRC_DIR=$PWD/CloverLeaf
  MAKE_OPTS='COMPILER=GNU USE_OPENCL=1 \
        EXTRA_INC="-I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/CL/" \
        EXTRA_PATH="-I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/CL/"'

  BINARY="clover_leaf"
  ;;
kokkos)
  COMPILER="hipcc"

  module load gcc/8.3.0 openmpi/4.0.1/gcc-8.3

  MAKE_OPTS='COMPILER=HIPCC'

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  export CXX=hipcc
  # XXX
  # TARGET=AMD isn't a thing in CloverLeaf but TARGET=CPU is misleading and TARGET=GPU uses nvcc
  # for CXX which is not what we want so we use a non-existent target
  # CXX needs to be specified again as we can't export inside CloverLeaf's makefile

  MPI_LIB="/nfs/software/x86_64/openmpi/4.0.1/gcc-8.3.0/lib"
  export LIBRARY_PATH=$MPI_LIB:$LIBRARY_PATH
  export LD_LIBRARY_PATH=$MPI_LIB:$LD_LIBRARY_PATH

  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} TARGET=AMD ARCH=Vega906 DEVICE=HIP CXX=hipcc"
  MAKE_OPTS+=' OPTIONS="-L$MPI_LIB -lmpi -O3 "'
  export SRC_DIR=$PWD/cloverleaf_kokkos
  BINARY="clover_leaf"
  ;;
omp-target)
  COMPILER="gcc-10.1"
  module load  openmpi/4.0.1/gcc-8.3 gcc/10.1.0
  #  module load gcc 10.1.0
  #  MAKE_OPTS+=' TARGET=AMD'
  #  MAKE_OPTS+=' EXTRA_FLAGS="-foffload=amdgcn-amdhsa="-march=gfx906""'
  #

  export SRC_DIR="$PWD/CloverLeaf-OpenMP4"
  MAKE_OPTS='-j16 COMPILER=GNU MPI_F90=mpif90 MPI_C=mpicc'
#  MAKE_OPTS+=' C_OPTIONS=" -foffload=amdgcn-amdhsa=\""-march=gfx906"\"  " '
  MAKE_OPTS+=' OPTIONS=" -fopenmp -lm " '
  BINARY="clover_leaf"

  ;;
acc)
  COMPILER="gcc-10.1"

  COMPILER="gcc-10.1"
  module load  openmpi/4.0.1/gcc-8.3 gcc/10.1.0
  #  module load gcc 10.1.0
  #  MAKE_OPTS+=' TARGET=AMD'
  #  MAKE_OPTS+=' EXTRA_FLAGS="-foffload=amdgcn-amdhsa="-march=gfx906""'
  #

  export SRC_DIR=$PWD/CloverLeaf-OpenACC
  MAKE_OPTS='-j16 COMPILER=GNU MPI_F90=mpif90 MPI_C=mpicc'
  MAKE_OPTS+=' C_OPTIONS=" -foffload=amdgcn-amdhsa=\""-march=gfx906"\"  " '
  MAKE_OPTS+=' OPTIONS=" -fopenmp " '
  BINARY="clover_leaf"


  ;;
sycl)
  #  module load gcc/8.3.0
  #  export HIPSYCL_CUDA_PATH=$(realpath $(dirname $(which nvcc))/..)
  #  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)

  COMPILER="gcc-8.3"
  module load hipsycl/master-mar-18
  module load gcc/8.3.0 openmpi/4.0.1/gcc-8.3

  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"

  MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc"
  MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=native -DHIPSYCL_PLATFORM=rocm -DHIPSYCL_GPU_ARCH=gfx906"

  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_sycl
  ;;
*)
  echo
  echo "Invalid model '$MODEL'."
  usage
  exit 1
  ;;
esac

export CONFIG="radeonvii"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

if [ "$ACTION" == "build" ]; then

  fetch_src $MODEL

  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  cd $RUN_DIR || exit
  bash "$SCRIPT_DIR/run.sh" CloverLeaf-$CONFIG.out
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
