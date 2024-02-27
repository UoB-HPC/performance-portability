#!/bin/bash

set -eu

BASE="$PWD"

ROCM=rocm-5.7.1

babelstream=true

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
    bench "$1" "$2" "run" "${@:3}"
}

 
case "$1" in
local)

    ROCM=rocm-5.5.1

    cd "$BASE/babelstream/results"

    (
        bench_exec exec_build radeonvii-local $ROCM hip
        wait
    )

    bench_exec exec_submit radeonvii-local $ROCM hip

    ;;
*)
    echo "Bad platform $1"
    ;;
esac
wait
echo "All done!"
