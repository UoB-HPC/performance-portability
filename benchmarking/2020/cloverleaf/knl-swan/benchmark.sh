#!/bin/bash

DEFAULT_COMPILER=intel-2019
DEFAULT_MODEL=mpi
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
    echo
    echo "Valid models:"
    echo "  mpi"
    echo "  omp"
    echo "  kokkos"
    echo
    echo "The default configuration is '$DEFAULT_COMPILER $DEFAULT_MODEL'."
    echo
}

# Process arguments
if [ $# -lt 1 ]
then
    usage
    exit 1
fi

ACTION="$1"
COMPILER="${2:-$DEFAULT_COMPILER}"
export MODEL="${3:-$DEFAULT_MODEL}"
SCRIPT="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$SCRIPT")")"
source "$SCRIPT_DIR/../common.sh"

export BENCHMARK_EXE=clover_leaf
export CONFIG="knl_${COMPILER}_${MODEL}"
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"


# Set up the environment
module swap craype-{broadwell,mic-knl}
case "$COMPILER" in
    cce-10.0)
        module swap cce cce/10.0.2
        MAKE_OPTS='COMPILER=CRAY MPI_COMPILER=ftn C_MPI_COMPILER=cc'
        ;;
    gcc-9.3)
        module swap PrgEnv-{cray,gnu}
        module swap gcc gcc/9.3.0
        MAKE_OPTS='COMPILER=GNU MPI_COMPILER=ftn C_MPI_COMPILER=cc'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=knl -funroll-loops"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=knl -funroll-loops"'
        ;;
    intel-2019)
        module swap PrgEnv-{cray,intel}
        module swap intel intel/19.0.4.243
        MAKE_OPTS='COMPILER=INTEL MPI_COMPILER=ftn C_MPI_COMPILER=cc'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_INTEL="-O3 -no-prec-div -xMIC-AVX512"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_INTEL="-O3 -no-prec-div -restrict -fno-alias -xMIC-AVX512"'
        ;;
    pgi-20.1)
        module swap PrgEnv-{cray,pgi}
        module swap pgi pgi/20.1.1
        MAKE_OPTS='COMPILER=PGI C_MPI_COMPILER=cc MPI_COMPILER=ftn'
        ;;
    *)
        echo
        echo "Invalid compiler '$COMPILER'."
        usage
        exit 1
        ;;
esac


case "$MODEL" in
    omp|mpi)
        ;;

    kokkos)
        module use /lus/snx11029/p02100/modules/modulefiles
        module load kokkos/2.8.00/intel/skylake
        MAKE_OPTS='CXX=CC'
        export SRC_DIR=$PWD/cloverleaf_kokkos
        ;;

    acc)
        MAKE_OPTS=$MAKE_OPTS' FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=multicore -tp=skylake" CFLAGS_PGI="-O3 -ta=multicore -tp=skylake" OMP_PGI=""'
        export SRC_DIR=$PWD/CloverLeaf-OpenACC
        ;;

    *)
        echo
        echo "Invalid model '$MODEL'."
        usage
        exit 1
        ;;
esac


# Handle actions
if [ "$ACTION" == "build" ]
then
    # Fetch source code
    fetch_src "$MODEL"

    # Perform build
    rm -f "$SRC_DIR/$BENCHMARK_EXE" "$RUN_DIR/$BENCHMARK_EXE"
    if ! eval make -C "$SRC_DIR" -B "$MAKE_OPTS"
    then
        echo
        echo "Build failed."
        echo
        exit 1
    fi

    mkdir -p "$RUN_DIR"
    mv "$SRC_DIR/$BENCHMARK_EXE" "$RUN_DIR"

elif [ "$ACTION" == "run" ]
then
    check_bin "$RUN_DIR/$BENCHMARK_EXE"

    qsub \
        -o "CloverLeaf-$CONFIG.out" \
        -N cloverleaf \
        -V \
        "$SCRIPT_DIR/run.job"
else
    echo
    echo "Invalid action (use 'build' or 'run')."
    echo
    exit 1
fi
