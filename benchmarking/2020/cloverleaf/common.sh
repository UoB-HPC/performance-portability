check_bin() {
  if [ ! -x "$1" ]; then
    echo "Executable '$1' not found."
    echo "Use the 'build' action first."
    exit 1
  fi
}

usage() {
  echo
  echo "Usage: ./fetch [MODEL]"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  omp-target"
  echo "  kokkos"
  echo "  cuda"
  echo "  opencl"
  echo "  acc"
  echo
  echo "The default programming model is '$DEFAULT_MODEL'."
  echo
}

KOKKOS_VERSION=3.1.01
fetch_kokkos() {
  KOKKOS_SRC_DIR="kokkos-${KOKKOS_VERSION}"
  KOKKOS_DIST="${KOKKOS_VERSION}.tar.gz"
  if [ ! -d ${KOKKOS_SRC_DIR} ]; then
    if ! wget "https://github.com/kokkos/kokkos/archive/${KOKKOS_DIST}"; then
      echo
      echo "Failed to Kokkos source code."
      echo
      exit 1
    fi
    tar -xf ${KOKKOS_DIST}
    rm ${KOKKOS_DIST}
  fi
  echo ${KOKKOS_SRC_DIR}
}

DEFAULT_MODEL=omp
fetch_src() {
  # Process arguments
  MODEL=$1

  case "$MODEL" in
  omp)
    if [ ! -e CloverLeaf_ref/clover.f90 ]; then
      git clone https://github.com/UK-MAC/CloverLeaf_ref
    fi
    ;;
  omp-target)
    if [ ! -e CloverLeaf-OpenMP4/clover.f90 ]; then
      git clone -b doe-p3-2019 https://github.com/UoB-HPC/CloverLeaf-OpenMP4
    fi
    ;;
  kokkos)
    if [ ! -e cloverleaf_kokkos/clover_leaf.cpp ]; then
      git clone https://github.com/tom91136/cloverleaf_kokkos
    fi
    ;;
  cuda)
    if [ ! -e CloverLeaf_CUDA/clover_leaf.f90 ]; then
      git clone --depth 1 https://github.com/UK-MAC/CloverLeaf_CUDA.git
    fi
    ;;
  opencl)
    if [ ! -e CloverLeaf/src/opencldefs.h ]; then
      git clone https://github.com/UoB-HPC/CloverLeaf
    fi
    ;;
  acc)
    if [ ! -e CloverLeaf-OpenACC/clover.f90 ]; then
      git clone https://github.com/UoB-HPC/CloverLeaf-OpenACC
    fi
    ;;
  sycl)
    if [ ! -e cloverleaf_sycl/CMakeLists.txt ]; then
      git clone https://github.com/UoB-HPC/cloverleaf_sycl
    fi
    ;;
  *)
    echo
    echo "Invalid model '$MODEL'."
    usage
    exit 1
    ;;
  esac
}

build_bin() {

  MODEL=$1
  MAKE_OPTS=$2
  SRC_DIR=$3
  BINARY=$4
  RUN_DIR=$5
  BENCHMARK_EXE=$6

  rm -f $RUN_DIR/$BENCHMARK_EXE

  if [ "$MODEL" == "sycl" ]; then
    cd $SRC_DIR || exit
    rm -rf build
    module load cmake/3.12.3
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release $MAKE_OPTS
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv build/$BINARY $BINARY
    cd $SRC_DIR/.. || exit
  else

    if [ "$MODEL" == "opencl" ]; then
      mkdir -p $SRC_DIR/obj $SRC_DIR/mpiobj
    fi

    if ! eval make -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
      echo
      echo "Build failed."
      echo
      exit 1
    fi

  fi

  mkdir -p $RUN_DIR
  mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE
}
