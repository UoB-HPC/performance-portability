check_bin() {
  if [ ! -x "$1" ]; then
    echo "Executable '$1' not found."
    echo "Use the 'build' action first."
    exit 1
  fi
}


loadOneAPI() {
  if [ -z "${1:-}" ]; then
    echo "${FUNCNAME[0]}: Usage: ${FUNCNAME[0]} /path/to/oneapi/source.sh"
    echo "No OneAPI path provided. Stop."
    exit 5
  fi

  local oneapi_env="${1}"

  set +u # setvars can't handle unbound vars
  CURRENT_SCRIPT_DIR="$SCRIPT_DIR" # save current script dir as the setvars overwrites it

  # their script also terminates the shell for some reason so we short-circuit it first
  source "$oneapi_env"  --force || true

  set -u
  SCRIPT_DIR="$CURRENT_SCRIPT_DIR" #recover script dir
}


KOKKOS_VERSION=3.3.01
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
    if ! git clone https://github.com/uob-hpc/BabelStream; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  fi
}
