check_bin() {
  if [ ! -x "$1" ]; then
    echo "Executable '$1' not found."
    echo "Use the 'build' action first."
    exit 1
  fi
}

fetch_src() {
  if [ ! -e BabelStream/main.cpp ]; then
    if ! git clone https://github.com/UoB-HPC/BabelStream; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  fi
}
