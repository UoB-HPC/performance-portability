check_bin() {
  if [ ! -x "$1" ]; then
    echo "Executable '$1' not found."
    echo "Use the 'build' action first."
    exit 1
  fi
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

fetch_src() {
  if [ ! -e BabelStream/main.cpp ]; then
    if ! git clone https://github.com/tom91136/BabelStream; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  fi
}
