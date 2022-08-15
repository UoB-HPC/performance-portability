#!/bin/bash

set -eu

BASE="$PWD"

cloverleaf=true
bude=true
babelstream=true

declare -A models
models["kokkos"]=true
models["omp"]=true
models["omp-target"]=true
models["sycl"]=true
models["kokkos"]=true

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

case "$1" in
p3)

    cd "$BASE/bude/results"

    (
        bench milan-isambard cce run kokkos omp omp-target &
        bench milan-isambard llvm-14 run kokkos omp omp-target &
        bench milan-isambard gcc-12.1 run kokkos omp omp-target &
        bench milan-isambard aocc-3.2.0 run kokkos omp omp-target &

        bench milan-isambard hipsycl-gcc run sycl &
        # bench milan-isambard hipsycl-llvm run sycl # doesn't link, ld doesn't like some of the ELF sections (!?)
        bench milan-isambard oneapi-2022.2 run sycl &
        wait
    )
    ;;
p2)

    cd "$BASE/bude/results"
    (
        bench icl-isambard cce run kokkos omp omp-target &
        bench icl-isambard llvm-14 run kokkos omp omp-target &
        bench icl-isambard gcc-12.1 run kokkos omp omp-target &
        bench icl-isambard oneapi-2022.2 run kokkos omp omp-target &

        # bench icl-isambard hipsycl-gcc run sycl # doesn't compile, local_ptr/multi_ptr overload ambiguous
        bench icl-isambard hipsycl-llvm run sycl &
        bench icl-isambard oneapi-2022.2 run sycl &
        wait
    )
    ;;
aws-g3)

    cd "$BASE/bude/results"
    bench graviton3-aws nvhpc-22.7 run kokkos omp omp-target
    bench graviton3-aws arm-22.0.1 run kokkos omp omp-target
    bench graviton3-aws gcc-12.1 run kokkos omp omp-target

    bench graviton3-aws hipsycl-gcc run sycl
    ;;
*)
    echo "Bad platform $1"
    ;;
esac

echo "All done!"
