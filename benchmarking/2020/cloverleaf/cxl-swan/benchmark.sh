#!/bin/bash

DEFAULT_COMPILER=intel-2019
DEFAULT_MODEL=mpi
function usage
{
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid model and compiler options:"
  echo "  mpi | omp"
  echo "    cce-10.0"
  echo "    gcc-9.3"
  echo "    intel-2019"
  echo "    pgi-20.1"
  echo
  echo "  kokkos"
  echo "    cce-10.0"
  echo "    gcc-9.3"
  echo "    intel-2019"
  echo
  echo "  acc"
  echo "    pgi-20.1"
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
export MODEL="${2:-$DEFAULT_MODEL}"
COMPILER="${3:-$DEFAULT_COMPILER}"
SCRIPT="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$SCRIPT")")"
source "$SCRIPT_DIR/../common.sh"

export BENCHMARK_EXE=clover_leaf
export CONFIG="cxl_${COMPILER}_${MODEL}"
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"


# Set up the environment
module swap craype-{broadwell,x86-cascadelake}
case "$COMPILER" in
  cce-10.0)
    module swap cce cce/10.0.2
    MAKE_OPTS='COMPILER=CRAY MPI_COMPILER=ftn C_MPI_COMPILER=cc'
    MAKE_OPTS=$MAKE_OPTS' FLAGS_CRAY="-em -ra -h acc_model=fast_addr:no_deep_copy:auto_async_all -h omp"'
    MAKE_OPTS=$MAKE_OPTS' CFLAGS_CRAY="-Ofast -ffast-math -ffp-contract=fast -march=cascadelake -funroll-loops -fopenmp"'
    ;;
  gcc-9.3)
    module swap PrgEnv-{cray,gnu}
    module swap gcc gcc/9.3.0
    MAKE_OPTS='COMPILER=GNU MPI_COMPILER=ftn C_MPI_COMPILER=cc'
    MAKE_OPTS=$MAKE_OPTS' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=cascadelake -funroll-loops"'
    MAKE_OPTS=$MAKE_OPTS' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=cascadelake -funroll-loops"'
    ;;
  intel-2019)
    module swap PrgEnv-{cray,intel}
    module swap intel intel/19.0.4.243
    MAKE_OPTS='COMPILER=INTEL MPI_COMPILER=ftn C_MPI_COMPILER=cc'
    MAKE_OPTS=$MAKE_OPTS' FLAGS_INTEL="-O3 -no-prec-div -xCASCADELAKE"'
    MAKE_OPTS=$MAKE_OPTS' CFLAGS_INTEL="-O3 -no-prec-div -restrict -fno-alias -xCASCADELAKE"'
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
    if ! [[ "$COMPILER" =~ (cce|gcc|intel)- ]]; then
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
    fi

    KOKKOS_PATH="$PWD/$(fetch_kokkos)"
    echo "Using KOKKOS_PATH='${KOKKOS_PATH}'"
    MAKE_OPTS+=" KOKKOS_PATH='${KOKKOS_PATH}' ARCH=SKX DEVICE=OpenMP CXX=CC"
    [[ "$COMPILER" =~ cce- ]] && MAKE_OPTS+=" KOKKOS_INTERNAL_OPENMP_FLAG=-fopenmp"
    SRC_DIR="$PWD/cloverleaf_kokkos"
    ;;

  acc)
    if ! [[ "$COMPILER" =~ pgi- ]]; then
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
    fi

    MAKE_OPTS+=' FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=multicore -tp=skylake" CFLAGS_PGI="-O3 -ta=multicore -tp=skylake" OMP_PGI=""'
    SRC_DIR="$PWD/CloverLeaf-OpenACC"
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
