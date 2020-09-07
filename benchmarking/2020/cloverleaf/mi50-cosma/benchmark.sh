#!/bin/bash

DEFAULT_COMPILER=gcc-9.3
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid models:"
  echo "  omp-target"
  echo "    gcc-10.2"
  echo
  echo "  kokkos"
  echo "    gcc-7.3"
  echo
  echo "  ocl"
  echo "    gcc-7.3"
  echo
  echo "  acc"
  echo "    gcc-10.2"
  echo
  echo "  sycl"
  echo "    hipsycl"
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
  module load openmpi/4.0.5/gcc-10.2
  module load openmpi/4.0.5/gcc-10.2
  export OMPI_CC=gcc OMPI_CXX=g++ OMPI_FC=gfortran
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
  module load gnu_comp/9.3.0
  module load openmpi/4.0.3
  module load cmake
  export CPATH=$CPATH:/cosma/home/do006/dc-deak1/bin/llvm/10.0.1/lib/clang/10.0.1
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

case "$MODEL" in
omp-target)
  if [ "$COMPILER" != "gcc-10.2" ]; then
    echo "Must use gcc-10.2 because AOMP cannot build OpenMPI"
    exit 1
  fi
  export SRC_DIR="$PWD/CloverLeaf-OpenMP4"
  MAKE_OPTS='-j16 COMPILER=GNU MPI_F90=mpif90 MPI_C=mpicc'
  MAKE_OPTS+=' OPTIONS="-foffload=amdgcn-amdhsa -foffload=-march=gfx906 -foffload=-lm -fno-fast-math -fno-associative-math" C_OPTIONS="-foffload=amdgcn-amdhsa -foffload=-march=gfx906 -foffload=-lm -fno-fast-math -fno-associative-math"  '
  BINARY="clover_leaf"
  ;;
kokkos)
  if [ "$COMPILER" != "gcc-7.3" ]; then
    echo "Must use gcc-7.3"
    exit 1
  fi


  MAKE_OPTS='COMPILER=HIPCC'

  echo "Using develop branch of Kokkos to work with HIP 3.5"
  KOKKOS_PATH=$(pwd)/kokkos
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  export CXX=hipcc
  # XXX
  # TARGET=AMD isn't a thing in CloverLeaf but TARGET=CPU is misleading and TARGET=GPU uses nvcc
  # for CXX which is not what we want so we use a non-existent target
  # CXX needs to be specified again as we can't export inside CloverLeaf's makefile

  MPI_LIB="/cosma/local/openmpi/gnu_7.3.0/3.0.1"
  export LIBRARY_PATH=$MPI_LIB/lib:$LIBRARY_PATH
  export LD_LIBRARY_PATH=$MPI_LIB/lib:$LD_LIBRARY_PATH
  export CPATH=$MPI_LIB/include:$CPATH

  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} TARGET=AMD ARCH=Vega906 DEVICE=HIP CXX=hipcc"
  MAKE_OPTS+=' OPTIONS="-L$MPI_LIB -lmpi -O3 "'
  export SRC_DIR=$PWD/cloverleaf_kokkos
  BINARY="clover_leaf"
  ;;
acc)
  if [ "$COMPILER" != "gcc-10.2" ]; then
    echo
    echo " Must use gcc-10.2"
    echo
    exit 1
  fi

  export SRC_DIR=$PWD/CloverLeaf-OpenACC
  MAKE_OPTS='-j16 COMPILER=GNU MPI_F90=mpif90 MPI_C=mpicc'
  MAKE_OPTS+=' C_OPTIONS=" -foffload=amdgcn-amdhsa=\""-march=gfx906"\"  " '
  MAKE_OPTS+=' OPTIONS=" -fopenmp -cpp" '
  BINARY="clover_leaf"
  ;;

ocl)
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
  if [ "$COMPILER" != "hipsycl" ]; then
    echo "Must use hipsycl"
    exit 1
  fi

  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"

  MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc"
  MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=native -DHIPSYCL_PLATFORM=rocm -DHIPSYCL_GPU_ARCH=gfx906"

  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_sycl
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
