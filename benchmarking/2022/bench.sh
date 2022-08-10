#!/bin/bash

set -eu

BASE="$PWD"
ONEAPI=oneapi-2022.2
NVHPC=nvhpc-22.7
GCC=gcc-12.1

cloverleaf=true
bude=true
babelstream=true

declare -A models
models["tbb"]=false
models["omp"]=false
models["cuda"]=false
models["sycl"]=false
models["kokkos"]=true

models["std-data"]=false
models["std-indices"]=false

models["std-data-dplomp"]=false
models["std-indices-dplomp"]=false

export LARGE=true

build_and_submit() {

    echo "[exec] build $1 $2 $3"
    "../$1/benchmark.sh" build "$2" "$3"
    echo "[exec] $4 $1 $2 $3"
    "../$1/benchmark.sh" "$4" "$2" "$3"
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
    bench milan-isambard $NVHPC run \
        omp \
        std-data std-indices
    bench milan-isambard $GCC run \
        omp tbb \
        std-data std-indices \
        std-data-dplomp std-indices-dplomp
    bench a100-isambard $NVHPC run \
        cuda omp \
        std-data std-indices

    cd "$BASE/bude/results"
    bench milan-isambard $NVHPC run \
        omp \
        std-indices
    bench milan-isambard $GCC run \
        omp tbb \
        std-indices std-indices-dplomp
    bench a100-isambard $NVHPC run \
        cuda omp \
        std-indices

    cd "$BASE/cloverleaf/results"
    bench milan-isambard $NVHPC run \
        omp \
        std-indices
    bench milan-isambard $GCC run \
        omp tbb \
        std-indices std-indices-dplomp
    bench a100-isambard $NVHPC run \
        cuda omp \
        std-indices
    ;;
p2)
    cd "$BASE/babelstream/results"
    bench icl-isambard $NVHPC run \
        omp \
        std-data std-indices
    bench icl-isambard $GCC run \
        omp tbb \
        std-data std-indices \
        std-data-dplomp std-indices-dplomp
    bench v100-isambard $NVHPC run \
        cuda omp \
        std-data std-indices

    cd "$BASE/bude/results"
    bench icl-isambard $NVHPC run \
        omp \
        std-indices
    bench icl-isambard $GCC run \
        omp tbb \
        std-indices std-indices-dplomp
    bench v100-isambard $NVHPC run \
        cuda omp \
        std-indices

    cd "$BASE/cloverleaf/results"
    bench icl-isambard $NVHPC run \
        omp \
        std-indices
    bench icl-isambard $GCC run \
        omp tbb \
        std-indices std-indices-dplomp
    bench v100-isambard $NVHPC run \
        cuda omp \
        std-indices
    ;;

aws)
    cd "$BASE/babelstream/results"
    bench graviton2-aws $NVHPC run \
        omp \
        std-data std-indices
    bench graviton2-aws $GCC run \
        omp tbb \
        std-data std-indices \
        std-data-dplomp std-indices-dplomp

    bench graviton3-aws $NVHPC run \
        omp \
        std-data std-indices
    bench graviton3-aws $GCC run \
        omp tbb \
        std-data std-indices \
        std-data-dplomp std-indices-dplomp

    cd "$BASE/bude/results"

    bench graviton2-aws $NVHPC run \
        omp \
        std-indices
    bench graviton2-aws $GCC run \
        omp tbb \
        std-indices std-indices-dplomp

    bench graviton3-aws $NVHPC run \
        omp \
        std-indices
    bench graviton3-aws $GCC run \
        omp tbb \
        std-indices std-indices-dplomp

    cd "$BASE/cloverleaf/results"
    bench graviton2-aws $NVHPC run \
        omp \
        std-indices
    bench graviton2-aws $GCC run \
        omp tbb \
        std-indices std-indices-dplomp

    bench graviton3-aws $NVHPC run \
        omp \
        std-indices
    bench graviton3-aws $GCC run \
        omp tbb \
        std-indices std-indices-dplomp

    ;;

xci)
    cd "$BASE/babelstream/results"
    bench tx2-isambard $NVHPC run \
        omp \
        std-data std-indices
    bench tx2-isambard $GCC run \
        omp tbb \
        std-data std-indices \
        std-data-dplomp std-indices-dplomp

    cd "$BASE/bude/results"
    bench tx2-isambard $NVHPC run \
        omp \
        std-indices
    bench tx2-isambard $GCC run \
        omp tbb \
        std-indices std-indices-dplomp

    cd "$BASE/cloverleaf/results"
    bench tx2-isambard $NVHPC run \
        omp \
        std-indices
    bench tx2-isambard $GCC run \
        omp tbb \
        std-indices std-indices-dplomp
    ;;
zoo)
    export LARGE=false
    cd "$BASE/babelstream/results"
    bench irispro580-zoo $ONEAPI run \
        kokkos sycl omp \
        std-data std-indices

    cd "$BASE/bude/results"
    bench irispro580-zoo $ONEAPI run \
        kokkos sycl omp \
        std-indices

    cd "$BASE/cloverleaf/results"
    bench irispro580-zoo $ONEAPI run \
        kokkos sycl omp \
        std-indices
    ;;

devcloud)
    export PAGER='cat' # don't page anything
    export LESS="-F -X ${LESS:-}"
    export LARGE=false
    cd "$BASE/babelstream/results"
    bench uhdp630-devcloud $ONEAPI run \
        sycl omp \
        std-data std-indices

    cd "$BASE/bude/results"
    bench uhdp630-devcloud $ONEAPI run \
        sycl omp \
        std-indices

    cd "$BASE/cloverleaf/results"
    bench uhdp630-devcloud $ONEAPI run \
        sycl omp \
        std-indices
    ;;
*)
    echo "Bad platform $1"
    ;;
esac

echo "All done!"
