#!/bin/bash

DEFAULT_COMPILER=cce-9.1
DEFAULT_MODEL=omp
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
    echo
    echo "Valid compilers:"
    echo "  cce-9.1"
    echo "  gcc-9.2"
    echo
    echo "Valid models:"
    echo "  omp"
    echo "  kokkos"
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

export CONFIG="tx2"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=stream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG


# Set up the environment
case "$COMPILER" in
    cce-9.1)
        module purge
        module load alps PrgEnv-cray
        [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
        module swap cce cce/9.1.3
        MAKE_OPTS="COMPILER=CRAY TARGET=CPU"
        ;;
    gcc-9.2)
        module purge
        module load alps PrgEnv-gnu
        module swap gcc gcc/9.2.0
        MAKE_OPTS="COMPILER=GNU TARGET=CPU"
        export OMP_PROC_BIND=spread
        ;;
    *)
        echo
        echo "Invalid compiler '$COMPILER'."
        usage
        exit 1
        ;;
esac


# Handle actions
if [ "$ACTION" == "build" ]
then

    # Fetch source code
    if ! "$SCRIPT_DIR/../fetch.sh"
    then
        echo
        echo "Failed to fetch source code."
        echo
        exit 1
    fi

    # Perform build
    rm -f $RUN_DIR/$BENCHMARK_EXE

    # Select Makefile to use
    case "$MODEL" in
      omp)
        module load kokkos3/3.1.1/cce-9.1
        MAKE_FILE="OpenMP.make"
        BINARY="omp-stream"
        ;;
      kokkos)
        # module load kokkos/2.8.0/gcc-8.2
        module load kokkos3/3.1.1/gcc-9.2
        MAKE_FILE="Kokkos.make"
        BINARY="kokkos-stream"
    esac

    if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS
    then
        echo
        echo "Build failed."
        echo
        exit 1
    fi

    # Rename binary
    mkdir -p $RUN_DIR
    mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE

elif [ "$ACTION" == "run" ]
then
    if [ ! -x "$RUN_DIR/$BENCHMARK_EXE" ]
    then
        echo "Executable '$RUN_DIR/$BENCHMARK_EXE' not found."
        echo "Use the 'build' action first."
        exit 1
    fi

    qsub -o BabelStream-$CONFIG.out \
        -N babelstream \
        -V \
        $SCRIPT_DIR/run.job

else
    echo
    echo "Invalid action (use 'build' or 'run')."
    echo
    exit 1
fi
