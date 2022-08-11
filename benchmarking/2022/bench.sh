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
models["tbb"]=true
models["omp"]=true
models["cuda"]=true
models["sycl"]=true
models["kokkos"]=true

models["std-data"]=true
models["std-indices"]=true

models["std-data-dplomp"]=true
models["std-indices-dplomp"]=true

export LARGE=true

build_and_submit() { # platform, compiler, model, action
    echo "[exec] build $1 $2 $3"
    "../$1/benchmark.sh" build "$2" "$3"
    echo "[exec] $4 $1 $2 $3"
    "../$1/benchmark.sh" "$4" "$2" "$3"
}

bench() { # platform, compiler,  action, models...
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

bench_once() {
    echo "No"
    # bench "$1" "$2" "run" "${@:3}"
}

bench_scale() {
    # echo "No"
    bench "$1" "$2" "run-scale" "${@:3}"
    # bench "$1" "$2" "run-scale" "${@:3}"
}

babelstream_gcc_cpu_models=(
    kokkos omp tbb
    std-data std-indices
    std-data-dplomp std-indices-dplomp
)

babelstream_nvhpc_cpu_models=(
    kokkos omp
    std-data std-indices
)

babelstream_nvhpc_gpu_models=(
    kokkos cuda omp
    std-data std-indices
)

generic_gcc_cpu_models=(
    kokkos omp tbb
    std-indices std-indices-dplomp
)

generic_nvhpc_cpu_models=(
    kokkos omp std-indices
)

generic_nvhpc_gpu_models=(
    kokkos cuda omp std-indices
)

case "$1" in
p3)
    cd "$BASE/babelstream/results"
    module unload cce
    bench_scale milan-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    module load cce
    bench_scale milan-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    bench_once a100-isambard $NVHPC "${babelstream_nvhpc_gpu_models[@]}"

    cd "$BASE/bude/results"
    module unload cce
    bench_scale milan-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    module load cce
    bench_scale milan-isambard $GCC "${generic_gcc_cpu_models[@]}"

    bench_once a100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"

    cd "$BASE/cloverleaf/results"
    module unload cce
    bench_scale milan-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    module load cce
    bench_scale milan-isambard $GCC "${generic_gcc_cpu_models[@]}"

    bench_once a100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"
    ;;
p2)
    cd "$BASE/babelstream/results"
    bench_scale icl-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_scale icl-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    bench_once v100-isambard $NVHPC "${babelstream_nvhpc_gpu_models[@]}"

    cd "$BASE/bude/results"
    bench_scale icl-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    bench_scale icl-isambard $GCC "${generic_gcc_cpu_models[@]}"

    bench_once v100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"

    cd "$BASE/cloverleaf/results"
    bench_scale icl-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    bench_scale icl-isambard $GCC "${generic_gcc_cpu_models[@]}"

    bench_once v100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"
    ;;

aws-g2)
    cd "$BASE/babelstream/results"
    bench_scale graviton2-aws $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    # bench_scale graviton2-aws $GCC "${babelstream_gcc_cpu_models[@]}"

    cd "$BASE/bude/results"
    bench_scale graviton2-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_scale graviton2-aws $GCC "${generic_gcc_cpu_models[@]}"

    cd "$BASE/cloverleaf/results"
    bench_scale graviton2-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_scale graviton2-aws $GCC "${generic_gcc_cpu_models[@]}"

    ;;
aws-g3)
    cd "$BASE/babelstream/results"
    bench_scale graviton3-aws $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_scale graviton3-aws $GCC "${babelstream_gcc_cpu_models[@]}"

    cd "$BASE/bude/results"
    bench_scale graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    bench_scale graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"

    cd "$BASE/cloverleaf/results"
    # bench_scale graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    bench_scale graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"

    ;;
xci)
    cd "$BASE/babelstream/results"
    bench_scale tx2-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_scale tx2-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    cd "$BASE/bude/results"
    bench_scale tx2-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    bench_scale tx2-isambard $GCC "${generic_gcc_cpu_models[@]}"

    cd "$BASE/cloverleaf/results"
    bench_scale tx2-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    bench_scale tx2-isambard $GCC "${generic_gcc_cpu_models[@]}"
    ;;
zoo)
    export LARGE=false
    cd "$BASE/babelstream/results"
    bench_once irispro580-zoo $ONEAPI kokkos sycl omp std-data std-indices

    cd "$BASE/bude/results"
    bench_once irispro580-zoo $ONEAPI kokkos sycl omp std-indices

    cd "$BASE/cloverleaf/results"
    bench_once irispro580-zoo $ONEAPI kokkos sycl omp std-indices
    ;;

devcloud)
    export PAGER='cat' # don't page anything
    export LESS="-F -X ${LESS:-}"
    export LARGE=false
    cd "$BASE/babelstream/results"
    bench_once uhdp630-devcloud $ONEAPI sycl omp std-data std-indices

    cd "$BASE/bude/results"
    bench_once uhdp630-devcloud $ONEAPI sycl omp std-indices

    cd "$BASE/cloverleaf/results"
    bench_once uhdp630-devcloud $ONEAPI sycl omp std-indices
    ;;
*)
    echo "Bad platform $1"
    ;;
esac

echo "All done!"
