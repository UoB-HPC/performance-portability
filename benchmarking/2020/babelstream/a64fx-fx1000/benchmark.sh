#!/bin/bash

DEFAULT_COMPILER=fujitsu-1.2.26
DEFAULT_MODEL=omp
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
    echo
    echo "Valid compilers:"
    echo "  fujitsu-1.2.26"
    echo "  gcc-8.3"
    echo "  armclang-20.1"
    echo
    echo "Valid models:"
    echo "  omp"
    echo "  kokkos"
    echo "  sycl"
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

export CONFIG="a64fx"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG


# Set up the environment
module use $HOME/../work/modulefiles
case "$COMPILER" in
    fujitsu-1.2.26)
        module load fujitsu/1.2.26
        MAKE_OPTS='COMPILER=FUJITSU COMPILER_FUJITSU=FCC FLAGS_FUJITSU="-Kfast,zfill,openmp,cmodel=large,restp -std=c++11" OMP_FUJITSU_CPU="-fopenmp"'
        ;;
    gcc-8.3)
        MAKE_OPTS='COMPILER=GNU'
        ;;
    armclang-20.1)
        module load arm/20.1
        MAKE_OPTS='COMPILER=ARMCLANG EXTRA_FLAGS="-mcpu=a64fx -O3"'
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
    if [ "$COMPILER" == "fujitsu-1.2.26" ]; then
      WORK_DIR=$PWD
      cd $SRC_DIR
      patch < $SCRIPT_DIR/restrict-pointers.patch
      cd $WORK_DIR
    fi
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    MAKE_OPTS+=" TARGET=CPU"
    ;;
  kokkos)
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv81 DEVICE=OpenMP"
    ;;
  acc)
    MAKE_FILE="OpenACC.make"
    BINARY="acc-stream"
    MAKE_OPTS+=' TARGET=SKL'
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
