#!/bin/bash

set -eu

BASE="$PWD"
ONEAPI=oneapi-2023.2
NVHPC=nvhpc-23.5
GCC=gcc-13.1
ACFL=acfl-23.04.1
CCE=cce-14.0.1

ROCM=rocm-5.4.1
AOMP=aomp-16.0.3
HIPSYCL=hipsycl-fd5d1c0
ROC_STDPAR=roc-stdpar-ecb855a5
ROC_STDPAR_INTERPOSE=roc-stdpar-interpose-ecb855a5

bude=false
babelstream=true
cloverleaf=false
tealeaf=false

declare -A models
models["ocl"]=true
models["thrust"]=true
models["tbb"]=true
models["omp"]=true
models["cuda"]=true
models["hip"]=true
models["sycl-acc"]=true
models["sycl-usm"]=true
models["sycl"]=true
models["sycl2020"]=true
models["kokkos"]=true
models["std-indices"]=true
models["std-indices-dplomp"]=true

export LARGE=true

build_and_submit() { # platform, compiler, model, action, impl
    echo "[exec] build $5 $1 $2 $3 "
    "../$1/benchmark.sh" build "$2" "$3"
    echo "[exec] $5 $4 $1 $2 $3"
    "../$1/benchmark.sh" "$4" "$2" "$3"
}

bench() { # platform, compiler,  action, models...
    local impl
    impl="$(basename "$(dirname "$PWD")")"
    if [ "${!impl}" = true ]; then
        for m in "${@:4}"; do
            if [ "${models[$m]}" = true ]; then
                build_and_submit "$1" "$2" "$m" "$3" "$impl"
            fi
        done
    fi
}

##

exec_build() { # platform, compiler, model, app
    echo "[exec] build=$4 $1 $2 $3 "
    "../$1/benchmark.sh" build "$2" "$3"
}

exec_submit() { # platform, compiler, model, app
    echo "[exec] submit=$4 $1 $2 $3"
    "../$1/benchmark.sh" run "$2" "$3"
}

bench_exec() { # op, platform, compiler,  models...
    local app
    app="$(basename "$(dirname "$PWD")")"
    if [ "${!app}" = true ]; then
        for m in "${@:4}"; do
            if [ "${models[$m]}" = true ]; then
                $1 "$2" "$3" "$m" "$app"
            fi
        done
    else
        echo "# skipping $app"
    fi
}

bench_once() {
    # echo "No"
    bench "$1" "$2" "run" "${@:3}"
}

# bench_scale() {
#     # echo "No"
#     # bench "$1" "$2" "run" "${@:3}"
#     # bench "$1" "$2" "run-scale" "${@:3}"
# }


case "$1" in
local)

    cd "$BASE/babelstream/results"

    # HSA_XNACK=0 bench_once radeonvii-local $AOMP omp
    # HSA_XNACK=0 bench_once radeonvii-local $ROCM ocl thrust hip kokkos
    # HSA_XNACK=0 bench_once radeonvii-local $ONEAPI sycl sycl2020
    # HSA_XNACK=0 bench_once radeonvii-local $HIPSYCL sycl

    # HSA_XNACK=1 bench_once radeonvii-local $ONEAPI std-indices
    # HSA_XNACK=1 bench_once radeonvii-local $HIPSYCL std-indices
    HSA_XNACK=1 bench_once radeonvii-local $ROC_STDPAR_INTERPOSE std-indices # hipMalloc
    # HSA_XNACK=1 bench_once radeonvii-local $ROC_STDPAR_INTERPOSE std-indices # hipMallocManaged,  HSA_XNACK=0 is too slow here
    # HSA_XNACK=1 bench_once radeonvii-local $ROC_STDPAR std-indices # malloc

    cd "$BASE/bude/results"

    # bench_exec exec_build radeonvii-local $AOMP omp
    # bench_exec exec_build radeonvii-local $ROCM ocl thrust hip kokkos
    # bench_exec exec_build radeonvii-local $ONEAPI sycl
    # bench_exec exec_build radeonvii-local $HIPSYCL sycl

    # bench_exec exec_build radeonvii-local $ONEAPI std-indices
    # bench_exec exec_build radeonvii-local $HIPSYCL std-indices
    # bench_exec exec_build radeonvii-local $ROC_STDPAR std-indices
    bench_exec exec_build radeonvii-local $ROC_STDPAR_INTERPOSE std-indices # hipMalloc

    for bm in 1 2; do
        export INPUT_BM="bm$bm"

        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $AOMP omp
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $ROCM ocl thrust hip kokkos
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $ONEAPI sycl
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $HIPSYCL sycl

        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $ONEAPI std-indices
        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $HIPSYCL std-indices
        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $ROC_STDPAR std-indices

    done

    cd "$BASE/cloverleaf/results"
    # rm -rf CloverLeaf

    # bench_exec exec_build radeonvii-local $AOMP omp
    # bench_exec exec_build radeonvii-local $ROCM hip kokkos
    # bench_exec exec_build radeonvii-local $ONEAPI sycl-acc
    # bench_exec exec_build radeonvii-local $HIPSYCL sycl-acc

    # bench_exec exec_build radeonvii-local $ONEAPI sycl-usm std-indices
    # bench_exec exec_build radeonvii-local $HIPSYCL sycl-usm std-indices
    # bench_exec exec_build radeonvii-local $ROC_STDPAR std-indices
    bench_exec exec_build radeonvii-local $ROC_STDPAR_INTERPOSE std-indices # hipMalloc

    # for bm in 4 16 64; do
    for bm in 4 16 64; do
        export INPUT_BM="${bm}_300"

        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $AOMP omp
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $ROCM hip kokkos
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $ONEAPI sycl-acc
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $HIPSYCL sycl-acc

        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $ONEAPI sycl-usm std-indices
        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $HIPSYCL sycl-usm std-indices
        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $ROC_STDPAR std-indices

    done

    cd "$BASE/tealeaf/results"
    rm -rf TeaLeaf

    # bench_exec exec_build radeonvii-local $AOMP omp
    # bench_exec exec_build radeonvii-local $ROCM hip kokkos
    # bench_exec exec_build radeonvii-local $ONEAPI sycl-acc
    # bench_exec exec_build radeonvii-local $HIPSYCL sycl-acc

    # bench_exec exec_build radeonvii-local $ONEAPI sycl-usm std-indices
    # bench_exec exec_build radeonvii-local $HIPSYCL sycl-usm std-indices
    # bench_exec exec_build radeonvii-local $ROC_STDPAR std-indices

    bench_exec exec_build radeonvii-local $ROC_STDPAR_INTERPOSE std-indices # hipMalloc

    # for bm in 4 16 64; do
    for bm in 8; do
        export INPUT_BM="5e_${bm}_4"

        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $AOMP omp
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $ROCM hip kokkos
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $ONEAPI sycl-acc
        # HSA_XNACK=0 bench_exec exec_submit radeonvii-local $HIPSYCL sycl-acc

        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $ONEAPI sycl-usm std-indices
        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $HIPSYCL sycl-usm std-indices
        # HSA_XNACK=1 bench_exec exec_submit radeonvii-local $ROC_STDPAR std-indices

    done

    ;;

p3)
    module use "$HOME/modulefiles/"

    cd "$BASE/babelstream/results"

    export UTPX=""
    bench_once mi100-isambard $AOMP omp
    # bench_once mi100-isambard $ROCM hip thrust ocl kokkos
    # bench_once mi100-isambard $ONEAPI sycl-acc sycl-usm std-indices
    # bench_once mi100-isambard $HIPSYCL sycl-acc sycl-usm std-indices
    # bench_once mi100-isambard $ROC_STDPAR_INTERPOSE std-indices

    # export UTPX=utpx
    # bench_once mi100-isambard $ONEAPI sycl-usm std-indices
    # bench_once mi100-isambard $HIPSYCL sycl-usm std-indices
    # bench_once mi100-isambard $ROC_STDPAR_INTERPOSE std-indices

    ##########
    cd "$BASE/bude/results"

    # bench_exec exec_build mi100-isambard $AOMP omp
    # bench_exec exec_build mi100-isambard $ROCM hip thrust ocl kokkos
    # bench_exec exec_build mi100-isambard $ONEAPI sycl std-indices
    # bench_exec exec_build mi100-isambard $HIPSYCL sycl std-indices
    # bench_exec exec_build mi100-isambard $ROC_STDPAR_INTERPOSE std-indices

    for bm in 2; do
        # for bm in 1 2; do
        export INPUT_BM="bm$bm"
        export UTPX=""
        bench_exec exec_submit mi100-isambard $AOMP omp
        bench_exec exec_submit mi100-isambard $ROCM hip thrust ocl kokkos
        bench_exec exec_submit mi100-isambard $ONEAPI sycl std-indices
        bench_exec exec_submit mi100-isambard $HIPSYCL sycl std-indices
        bench_exec exec_submit mi100-isambard $ROC_STDPAR_INTERPOSE std-indices

        export UTPX=utpx
        bench_exec exec_submit mi100-isambard $ONEAPI std-indices
        bench_exec exec_submit mi100-isambard $HIPSYCL std-indices
        bench_exec exec_submit mi100-isambard $ROC_STDPAR_INTERPOSE std-indices
    done

    cd "$BASE/tealeaf/results"

    bench_exec exec_build mi100-isambard $AOMP omp
    bench_exec exec_build mi100-isambard $ROCM hip kokkos
    bench_exec exec_build mi100-isambard $ONEAPI sycl-acc sycl-usm std-indices
    bench_exec exec_build mi100-isambard $HIPSYCL sycl-acc sycl-usm std-indices
    bench_exec exec_build mi100-isambard $ROC_STDPAR_INTERPOSE std-indices

    # for bm in 4 16 64 256; do
    for bm in 1; do
        # for bm in 16; do
        export INPUT_BM="5e_${bm}_4"
        export UTPX=""
        # bench_exec exec_submit mi100-isambard $AOMP omp
        # bench_exec exec_submit mi100-isambard $ROCM hip kokkos
        bench_exec exec_submit mi100-isambard $ONEAPI sycl-acc sycl-usm std-indices
        # bench_exec exec_submit mi100-isambard $HIPSYCL sycl-acc sycl-usm std-indices
        # bench_exec exec_submit mi100-isambard $ROC_STDPAR_INTERPOSE std-indices
        export UTPX=utpx
        # bench_exec exec_submit mi100-isambard $ROC_STDPAR_INTERPOSE std-indices
        # bench_exec exec_submit mi100-isambard $ONEAPI sycl-usm std-indices
        # bench_exec exec_submit mi100-isambard $HIPSYCL sycl-usm std-indices
    done

    ##########

    cd "$BASE/cloverleaf/results"

    # bench_exec exec_build mi100-isambard $AOMP omp
    # bench_exec exec_build mi100-isambard $ROCM hip kokkos
    # bench_exec exec_build mi100-isambard $ONEAPI sycl-acc sycl-usm std-indices
    # bench_exec exec_build mi100-isambard $HIPSYCL sycl-acc sycl-usm std-indices
    # bench_exec exec_build mi100-isambard $ROC_STDPAR_INTERPOSE std-indices

    # for bm in 4 16 64 256; do
    for bm in 64; do
        # for bm in 16; do
        export INPUT_BM="${bm}_300"
        export UTPX=""
        bench_exec exec_submit mi100-isambard $AOMP omp
        bench_exec exec_submit mi100-isambard $ROCM hip kokkos
        bench_exec exec_submit mi100-isambard $ONEAPI sycl-acc sycl-usm std-indices
        bench_exec exec_submit mi100-isambard $HIPSYCL sycl-acc sycl-usm std-indices
        bench_exec exec_submit mi100-isambard $ROC_STDPAR_INTERPOSE std-indices
        export UTPX=utpx
        bench_exec exec_submit mi100-isambard $ROC_STDPAR_INTERPOSE std-indices
        bench_exec exec_submit mi100-isambard $ONEAPI sycl-usm std-indices
        bench_exec exec_submit mi100-isambard $HIPSYCL sycl-usm std-indices
    done
    ;;
*)
    echo "Bad platform $1"
    ;;
esac
wait
echo "All done!"
