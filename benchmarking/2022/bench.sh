#!/bin/bash

set -eu

BASE="$PWD"
NVHPC=nvhpc-22.5
GCC=gcc-12.1

cloverleaf=true
bude=false
babelstream=false

declare -A models
models["tbb"]=true
models["omp"]=true
models["cuda"]=true

models["std-data"]=true
models["std-indices"]=true
models["std-ranges"]=true

models["std-data-dplomp"]=true
models["std-indices-dplomp"]=true
models["std-ranges-dplomp"]=true

export LARGE=true

build_and_submit() {

    echo "[exec] build $1 $2 $3"
    "../$1-isambard/benchmark.sh" build "$2" "$3"
    echo "[exec] $4 $1 $2 $3"
    "../$1-isambard/benchmark.sh" "$4" "$2" "$3"
}

bench() {

    local impl
    impl="$(basename "$(dirname "$PWD")")"
    if [ "${!impl}" = true ]; then
        for m in "${@:4}"; do
            if [ "${models[$m]}" = true ]; then
                build_and_submit "$1" "$2" "$m" "$3"
            fi
        done
    fi
}

case "$1" in
p3)

    cd "$BASE/babelstream/results"
    bench milan $NVHPC run \
        omp \
        std-data std-indices
    bench milan $GCC run \
        omp tbb \
        std-data std-indices std-ranges \
        std-data-dplomp std-indices-dplomp std-ranges-dplomp
    bench a100 $NVHPC run \
        cuda omp \
        std-data std-indices

    cd "$BASE/bude/results"
    bench milan $NVHPC run \
        omp \
        std-indices
    bench milan $GCC run \
        omp tbb \
        std-indices std-ranges \
        std-indices-dplomp std-ranges-dplomp
    bench a100 $NVHPC run \
        cuda omp \
        std-indices

    cd "$BASE/cloverleaf/results"
    bench milan $NVHPC run \
        omp \
        std-indices
    bench milan $GCC run \
        omp tbb \
        std-indices \
        std-indices-dplomp
    bench a100 $NVHPC run \
        cuda omp \
        std-indices

    ;;

p2)

    cd "$BASE/babelstream/results"
    bench icl $NVHPC run \
        omp \
        std-data std-indices
    bench icl $GCC run \
        omp tbb \
        std-data std-indices std-ranges \
        std-data-dplomp std-indices-dplomp std-ranges-dplomp
    bench v100 $NVHPC run \
        cuda omp \
        std-data std-indices

    cd "$BASE/bude/results"
    bench icl $NVHPC run \
        omp \
        std-indices
    bench icl $GCC run \
        omp tbb \
        std-indices std-ranges \
        std-indices-dplomp std-ranges-dplomp
    bench v100 $NVHPC run \
        cuda omp \
        std-indices

    cd "$BASE/cloverleaf/results"
    bench icl $NVHPC run \
        omp \
        std-indices
    bench icl $GCC run \
        omp tbb \
        std-indices \
        std-indices-dplomp
    bench v100 $NVHPC run \
        cuda omp \
        std-indices

    ;;
xci)

    cd "$BASE/babelstream/results"
    bench tx2 $NVHPC run \
        omp \
        std-data std-indices
    bench tx2 $GCC run \
        omp tbb \
        std-data std-indices std-ranges \
        std-data-dplomp std-indices-dplomp std-ranges-dplomp

    cd "$BASE/bude/results"
    bench tx2 $NVHPC run \
        omp \
        std-indices
    bench tx2 $GCC run \
        omp tbb \
        std-indices std-ranges \
        std-indices-dplomp std-ranges-dplomp

    cd "$BASE/cloverleaf/results"
    bench tx2 $NVHPC run \
        omp \
        std-indices
    bench tx2 $GCC run \
        omp tbb \
        std-indices \
        std-indices-dplomp

    ;;

*)
    echo "Bad platform $1"
    ;;
esac

echo "All done!"
