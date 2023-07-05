#!/bin/bash

set -eu

BASE="$PWD"
ONEAPI=oneapi-2023.1
NVHPC=nvhpc-23.5
GCC=gcc-13.1
ACFL=acfl-23.04.1
CCE=cce-14.0.1

ROCM=rocm-4.5.1
AOMP=aomp-16.0.3

# cloverleaf=false
tealeaf=true
babelstream=false

declare -A models
models["tbb"]=true
models["omp"]=true
models["cuda"]=true
models["hip"]=true
models["sycl-acc"]=true
models["sycl-usm"]=true
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
                build_and_submit "$1" "$2" "$m" "$3" "$impl" &
            fi
        done
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

## babelstream
babelstream_gcc_cpu_models=(
    kokkos omp
    tbb
    std-indices
    std-indices-dplomp
)
babelstream_oneapi_cpu_models=(
    kokkos omp tbb
    std-indices
    std-indices-dplomp
    sycl sycl2020
)
babelstream_cce_cpu_models=(
    kokkos omp # tbb
    # std-indices # XXX doesn't work with CCE
    # std-indices-dplomp # XXX doesn't work with CCE
)
babelstream_nvhpc_cpu_models=(
    kokkos omp
    std-indices
)
babelstream_nvhpc_gpu_models=(
    kokkos cuda omp
    std-indices
)
babelstream_oneapi_gpu_models=(
    sycl sycl2020
    std-indices
)
babelstream_aomp_gpu_models=(
    kokkos hip omp
)
babelstream_rocm_gpu_models=(
    hip # kokkos needs hipcc>= 5.2
)

## tealeaf
tealeaf_gcc_cpu_models=(
    kokkos omp
    #tbb
    std-indices
    std-indices-dplomp
)
tealeaf_oneapi_cpu_models=(
    kokkos omp #tbb
    std-indices
    std-indices-dplomp
    sycl-acc sycl-usm
)
tealeaf_cce_cpu_models=(
    kokkos omp # #tbb
    # std-indices # XXX doesn't work with CCE
    # std-indices-dplomp # XXX doesn't work with CCE
)
tealeaf_nvhpc_cpu_models=(
    kokkos omp
    std-indices
)
tealeaf_nvhpc_gpu_models=(
    kokkos cuda omp
    std-indices
)
tealeaf_oneapi_gpu_models=(
    sycl-acc sycl-usm
    std-indices
)
tealeaf_aomp_gpu_models=(
    kokkos hip omp
)
tealeaf_rocm_gpu_models=(
    hip # kokkos needs hipcc>= 5.2
)

case "$1" in
cambridge)
    cd "$BASE/babelstream/results"
    bench_once a100-cambridge $NVHPC "${babelstream_nvhpc_gpu_models[@]}"
    bench_once a100-cambridge $ONEAPI "${babelstream_oneapi_gpu_models[@]}"

    bench_once icl-cambridge $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once icl-cambridge $GCC "${babelstream_gcc_cpu_models[@]}"
    bench_once icl-cambridge $ONEAPI "${babelstream_oneapi_cpu_models[@]}"
    ;;
p3)
    cd "$BASE/babelstream/results"
    module unload cce
    bench_once milan-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    module load cce
    bench_once milan-isambard $GCC "${babelstream_gcc_cpu_models[@]}"
    bench_once milan-isambard $ONEAPI "${babelstream_oneapi_cpu_models[@]}"

    bench_once mi100-isambard $AOMP "${babelstream_aomp_gpu_models[@]}"
    bench_once mi100-isambard $ROCM "${babelstream_rocm_gpu_models[@]}"
    bench_once mi100-isambard $ONEAPI "${babelstream_oneapi_gpu_models[@]}"

    export INPUT_BM=5
    cd "$BASE/tealeaf/results"
    # module unload cce
    bench_once milan-isambard $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
    # module load cce
    bench_once milan-isambard $GCC "${tealeaf_gcc_cpu_models[@]}"
    bench_once milan-isambard $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"

    # bench_once mi100-isambard $AOMP "${tealeaf_aomp_gpu_models[@]}"
    # bench_once mi100-isambard $ROCM "${tealeaf_rocm_gpu_models[@]}"
    # bench_once mi100-isambard $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
    ;;
p2)
    cd "$BASE/babelstream/results"
    bench_once icl-isambard $ONEAPI "${babelstream_gcc_cpu_models[@]}"
    bench_once icl-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once icl-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    bench_once v100-isambard $NVHPC "${babelstream_nvhpc_gpu_models[@]}"

    # cd "$BASE/bude/results"
    # # bench_once icl-isambard $ONEAPI "${generic_gcc_cpu_models[@]}"
    # bench_once icl-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # # bench_once icl-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # bench_once v100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once icl-isambard $ONEAPI "${generic_gcc_cpu_models[@]}"
    # bench_once icl-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once icl-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # bench_once v100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"
    ;;

aws-g3)
    cd "$BASE/babelstream/results"
    bench_once graviton3-aws $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once graviton3-aws $GCC "${babelstream_gcc_cpu_models[@]}"
    bench_once graviton3-aws $ACFL "${babelstream_gcc_cpu_models[@]}"

    # cd "$BASE/bude/results"
    # bench_once graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # # bench_once graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"
    # # bench_once graviton3-aws $ACFL "${generic_gcc_cpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"
    # bench_once graviton3-aws $ACFL "${generic_gcc_cpu_models[@]}"
    ;;
aws-g3e)
    cd "$BASE/babelstream/results"
    bench_once graviton3e-aws $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once graviton3e-aws $GCC "${babelstream_gcc_cpu_models[@]}"
    bench_once graviton3e-aws $ACFL "${babelstream_gcc_cpu_models[@]}"

    # cd "$BASE/bude/results"
    # bench_once graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # # bench_once graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"
    # # bench_once graviton3-aws $ACFL "${generic_gcc_cpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"
    # bench_once graviton3-aws $ACFL "${generic_gcc_cpu_models[@]}"
    ;;
xci)
    cd "$BASE/babelstream/results"
    bench_once tx2-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once tx2-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    # cd "$BASE/bude/results"
    # bench_once tx2-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once tx2-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once tx2-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once tx2-isambard $GCC "${generic_gcc_cpu_models[@]}"
    ;;
a64fx)
    cd "$BASE/babelstream/results"
    bench_once a64fx-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once a64fx-isambard $GCC "${babelstream_gcc_cpu_models[@]}"
    # bench_once a64fx-isambard $CCE "${babelstream_cce_cpu_models[@]}" # OMP is broken
    bench_once a64fx-isambard $ACFL "${babelstream_gcc_cpu_models[@]}"

    # cd "$BASE/bude/results"
    # bench_once a64fx-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once a64fx-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once a64fx-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once a64fx-isambard $GCC "${generic_gcc_cpu_models[@]}"
    ;;
*)
    echo "Bad platform $1"
    ;;
esac
wait
echo "All done!"
