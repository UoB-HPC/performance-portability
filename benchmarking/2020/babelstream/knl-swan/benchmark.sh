#!/bin/bash

DEFAULT_COMPILER=intel-2019
DEFAULT_MODEL=omp
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
    echo
    echo "Valid compilers:"
    echo "  cce-10.0"
    echo "  gcc-9.3"
    echo "  intel-2019"
    echo "  pgi-20.1"
    echo "  dpcpp-2021.1.8"
    echo
    echo "Valid models:"
    echo "  omp"
    echo "  kokkos"
    echo "  acc"
    echo "  ocl"
    echo
    echo "The default configuration is '$DEFAULT_COMPILER'."
    echo "The default programming model is '$DEFAULT_MODEL'."
    echo
}

# Process arguments
if [ $# -lt 1 ]
then
    usage
    exit 1
fi

ACTION=$1
COMPILER=${2:-$DEFAULT_COMPILER}
MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=`realpath $0`
SCRIPT_DIR=`realpath $(dirname $SCRIPT)`
source ${SCRIPT_DIR}/../common.sh

export CONFIG="knl"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG


# Set up the environment
module swap craype-{broadwell,mic-knl}
case "$COMPILER" in
    cce-10.0)
        module swap cce cce/10.0.1
        MAKE_OPTS='COMPILER=CRAY'
        ;;
    gcc-9.3)
        module swap PrgEnv-{cray,gnu}
        module swap gcc gcc/9.3.0
        MAKE_OPTS='COMPILER=GNU EXTRA_FLAGS="-march=knl"'
        ;;
    intel-2019)
        module swap PrgEnv-{cray,intel}
        module swap intel intel/19.0.4.243
        MAKE_OPTS='COMPILER=INTEL EXTRA_FLAGS=-xMIC-AVX512'
        ;;
    pgi-20.1)
        module swap PrgEnv-{cray,pgi}
        module swap pgi pgi/20.1.1
	MAKE_OPTS='COMPILER=PGI EXTRA_FLAGS="-ta=multicore -tp=knl"'
        ;;
    dpcpp-2021.1.8)
        source /home/users/p02639/bin/intel/oneapi/setvars.sh
	MAKE_OPTS='COMPILER=DPCPP'
        ;;
    *)
        echo
        echo "Invalid compiler '$COMPILER'."
        usage
        exit 1
        ;;
esac

# Select Makefile to use, and model specific information
case "$MODEL" in
  omp)
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    MAKE_OPTS+=" TARGET=CPU"
    ;;
  kokkos)
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=KNL DEVICE=OpenMP"
    ;;
  acc)
    MAKE_FILE="OpenACC.make"
    BINARY="acc-stream"
    MAKE_OPTS+=' TARGET=KNL'
    if [ "$COMPILER" != "pgi-20.1" ]
    then
      echo
      echo " Must use PGI with OpenACC"
      echo
      exit 1
    fi
  ;;
  ocl)
    module use /home/users/p02639/bin/modulefiles
    module load intel-opencl-experimental
    module load khronos/opencl-headers
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
    #export LD_PRELOAD=/lus/scratch/p02555/modules/intel-opencl/lib/libintelocl.so
    #export LD_PRELOAD=/lus/scratch/p02100/l_opencl_p_18.1.0.013/opt/intel/opencl_compilers_and_libraries_18.1.0.013/linux/compiler/lib/intel64_lin/libintelocl.so
  ;;
  sycl)
    module use /home/users/p02639/bin/modulefiles
    module load intel-opencl-experimental
    module load khronos/opencl-headers
    MAKE_FILE="SYCL.make"
    BINARY="sycl-stream"
    MAKE_OPTS+=' TARGET=CPU'
  ;;
esac


# Handle actions
if [ "$ACTION" == "build" ]
then
    # Fetch source code
    fetch_src


    # Perform build
    if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS
    then
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
  qsub -o BabelStream-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-large-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run-large.job
else
    echo
    echo "Invalid action (use 'build' or 'run')."
    echo
    exit 1
fi
