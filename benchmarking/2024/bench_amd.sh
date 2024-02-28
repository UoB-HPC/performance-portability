#!/bin/bash

set -eu

BASE="$PWD"

ROCM=rocm-5.7.1

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

    for m in "${@:4}"; do
        if [ "${models[$m]}" = true ]; then
            $1 "$2" "$3" "$m" "$app"
        fi
    done
}

bench_once() {
    bench "$1" "$2" "run" "${@:3}"
}

case "$1" in
aac)

    ROCM=rocm-5.7.1

    cd "$BASE/babelstream/results"

    (
        HSA_XNACK=0 bench_exec exec_build mi210-amdaac $ROCM hip
        wait
    )

    HSA_XNACK=1 bench_exec exec_submit mi210-amdaac $ROCM hip
    HSA_XNACK=0 bench_exec exec_submit mi210-amdaac $ROCM hip

    cd "$BASE/babelstream-gonzalo/results"

    (
        HSA_XNACK=0 bench_exec exec_build mi210-amdaac $ROCM hip
        wait
    )

    HSA_XNACK=1 bench_exec exec_submit mi210-amdaac $ROCM hip
    HSA_XNACK=0 bench_exec exec_submit mi210-amdaac $ROCM hip

    ;;
lumi)

    # ROCM=rocm-5.2.3
    ROCM=rocm-5.6.1

    cd "$BASE/babelstream/results"
    HSA_XNACK=0 bench_exec exec_build mi250x-lumi $ROCM hip

    HSA_XNACK=1 bench_exec exec_submit mi250x-lumi $ROCM hip
    HSA_XNACK=0 bench_exec exec_submit mi250x-lumi $ROCM hip

    cd "$BASE/babelstream-gonzalo/results"
    HSA_XNACK=0 bench_exec exec_build mi250x-lumi $ROCM hip

    HSA_XNACK=1 bench_exec exec_submit mi250x-lumi $ROCM hip
    HSA_XNACK=0 bench_exec exec_submit mi250x-lumi $ROCM hip

    ;;
*)
    echo "Bad platform $1"
    ;;
esac
wait
echo "All done!"
