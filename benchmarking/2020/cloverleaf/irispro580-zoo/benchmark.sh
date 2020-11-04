#!/bin/bash

DEFAULT_COMPILER=gcc
DEFAULT_MODEL=ocl
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run  [MODEL]"
  echo

  echo
  echo "Valid models:"
  echo "  omp-target oneapi"
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
COMPILER=${3:-$DEFAULT_COMPILER}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export SRC_DIR=$PWD/CloverLeaf

# Set up the environment
module purge
module load cmake/3.14.5

if [ "$COMPILER" == "oneapi" ]; then
CURRENT_SCRIPT_DIR=$SCRIPT_DIR
source /nfs/software/x86_64/inteloneapi-beta/2021.1.8/setvars.sh --force
SCRIPT_DIR=$CURRENT_SCRIPT_DIR
COMPILER=oneapi
fi

export MODEL=$MODEL
case "$MODEL" in
omp-target)
  export SRC_DIR=$PWD/cloverleaf_openmp_target
  export OMP_TARGET_OFFLOAD="MANDATORY"

  MAKE_OPTS=(
    "-DCMAKE_C_COMPILER=icc" 
    "-DCMAKE_CXX_COMPILER=icpc" 
    "-DOMP_ALLOW_HOST=OFF" 
    "-DOMP_OFFLOAD_FLAGS='-qnextgen -fiopenmp -fopenmp-targets=spir64'"
  )

  BINARY="clover_leaf"
  ;;
ocl)
  module load intel/opencl/18.1
  module load khronos/opencl/headers khronos/opencl/icd-loader
  module load openmpi/4.0.1/gcc-8.3 

  MAKE_OPTS='COMPILER=GCC USE_OPENCL=1 OCL_VENDOR=INTEL \
        COPTIONS="-std=c++98 -DCL_TARGET_OPENCL_VERSION=110 -DOCL_IGNORE_PLATFORM -I/nfs/software/x86_64/cuda/10.1/targets/x86_64-linux/include/" \
        OPTIONS="-lstdc++ -cpp -lOpenCL" '

  BINARY="clover_leaf"
  export SRC_DIR=$PWD/CloverLeaf_OpenCL
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
  fetch_src "$MODEL"

#  if [ "$MODEL" == "ocl" ]; then
#    sed -i 's/ cl::Platform default_platform = all_platforms\[.\];/ cl::Platform default_platform = all_platforms[1];/g' CloverLeaf/src/openclinit.cpp
#  fi
  if [ "$MODEL" == "omp-target" ]; then
    # Passing quoted string args to cmake requires an array hence the special case here
    cd $SRC_DIR || exit
    rm -rf build
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release "${MAKE_OPTS[@]}" 
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv build/$BINARY $BINARY
    cd $SRC_DIR/.. || exit
    mkdir -p $RUN_DIR
    mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE
  else 

    build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

  fi

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
