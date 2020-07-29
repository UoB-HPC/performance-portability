
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
  echo " omp"
  echo " omp-target"
  echo " acc"
  echo " kokkos"
  echo " raja"
  echo " opencl"
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

  MODEL=$1

  case "$MODEL" in
  omp)
    if [ ! -e TeaLeaf_ref/tea.f90 ]; then
      git clone https://github.com/UK-MAC/TeaLeaf_ref
    fi
    ;;
  kokkos | omp-target | acc | raja)
    if [ ! -e TeaLeaf/2d/main.c ]; then
      git clone https://github.com/UoB-HPC/TeaLeaf
      mkdir -p TeaLeaf/2d/Benchmarks
      wget https://raw.githubusercontent.com/UK-MAC/TeaLeaf_ref/master/Benchmarks/tea_bm_5.in
      mv tea_bm_5.in TeaLeaf/2d/Benchmarks
    fi
    ;;
  cuda)
    if [ ! -e TeaLeaf_CUDA/tea.f90 ]; then
      git clone https://github.com/UK-MAC/TeaLeaf_CUDA
    fi
    ;;
  opencl)
    if [ ! -e TeaLeaf_OpenCL/tea.f90 ]; then
      git clone https://github.com/UK-MAC/TeaLeaf_OpenCL
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
