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
ROC_STDPAR_INTERPOSE_MS=roc-stdpar-interpose-ms-ecb855a5

bude=true
babelstream=true
cloverleaf=true
tealeaf=true

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
    omp
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
    omp
)
tealeaf_rocm_gpu_models=(
    hip kokkos # kokkos needs hipcc>= 5.2
)

case "$1" in
local)

    cd "$BASE/babelstream/results"

    # HSA_XNACK=0 bench_once radeonvii-local $AOMP omp
    # HSA_XNACK=0 bench_once radeonvii-local $ROCM ocl thrust hip kokkos
    # HSA_XNACK=0 bench_once radeonvii-local $ONEAPI sycl sycl2020
    # HSA_XNACK=0 bench_once radeonvii-local $HIPSYCL sycl

    # HSA_XNACK=1 bench_once radeonvii-local $ONEAPI std-indices
    # HSA_XNACK=1 bench_once radeonvii-local $HIPSYCL std-indices
    HSA_XNACK=1 bench_once radeonvii-local $ROC_STDPAR_INTERPOSE_MS std-indices # hipMalloc
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
    bench_exec exec_build radeonvii-local $ROC_STDPAR_INTERPOSE_MS std-indices # hipMalloc


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
    bench_exec exec_build radeonvii-local $ROC_STDPAR_INTERPOSE_MS std-indices # hipMalloc



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

    bench_exec exec_build radeonvii-local $ROC_STDPAR_INTERPOSE_MS std-indices # hipMalloc


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

cambridge)
    cd "$BASE/babelstream/results"

    bench_once icl-cambridge $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once icl-cambridge $GCC kokkos omp
    bench_once icl-cambridge $ONEAPI "${babelstream_oneapi_cpu_models[@]}"
    bench_once icl-cambridge $HIPSYCL std-indices sycl

    cd "$BASE/cloverleaf/results"
    rm -rf CloverLeaf
    # CPUs
    bench_exec exec_build icl-cambridge $GCC kokkos omp # tpause issue, no std-indices*
    (
        bench_exec exec_build icl-cambridge $NVHPC "${tealeaf_nvhpc_cpu_models[@]}" &
        bench_exec exec_build icl-cambridge $ONEAPI "${tealeaf_oneapi_cpu_models[@]}" &
        bench_exec exec_build icl-cambridge $HIPSYCL std-indices sycl-acc sycl-usm &
        wait
    )
    for bm in 4 16 64 256; do
        # for bm in 16 64; do
        export INPUT_BM="${bm}_300"
        bench_exec exec_submit icl-cambridge $GCC kokkos omp # tpause issue, no std-indices*
        bench_exec exec_submit icl-cambridge $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
        bench_exec exec_submit icl-cambridge $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"
        bench_exec exec_submit icl-cambridge $HIPSYCL std-indices sycl-acc sycl-usm
    done

    cd "$BASE/tealeaf/results"
    rm -rf TeaLeaf

    # CPUs
    bench_exec exec_build icl-cambridge $GCC kokkos omp & # tpause issue, no std-indices*
    (
        bench_exec exec_build icl-cambridge $NVHPC "${tealeaf_nvhpc_cpu_models[@]}" &
        bench_exec exec_build icl-cambridge $ONEAPI "${tealeaf_oneapi_cpu_models[@]}" &
        bench_exec exec_build icl-cambridge $HIPSYCL std-indices sycl-acc sycl-usm &
        wait
    )
    for bm in 1 2 4 8; do
        # for bm in 1; do
        export INPUT_BM="5e_${bm}_2"
        bench_exec exec_submit icl-cambridge $GCC kokkos omp # tpause issue, no std-indices*
        bench_exec exec_submit icl-cambridge $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
        bench_exec exec_submit icl-cambridge $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"
        bench_exec exec_submit icl-cambridge $HIPSYCL std-indices sycl-acc sycl-usm
    done

    ;;
idc)

    cd "$BASE/babelstream/results"
    bench_once pvc-idc $ONEAPI omp kokkos "${babelstream_oneapi_gpu_models[@]}"

    cd "$BASE/tealeaf/results"
    # bench_exec exec_build pvc-idc $ONEAPI omp kokkos "${tealeaf_oneapi_gpu_models[@]}"

    for bm in 8; do
        for stage in false; do
            export INPUT_BM="5e_${bm}"
            export STAGE="$stage"
            bench_exec exec_submit pvc-idc $ONEAPI std-indices #  omp kokkos "${tealeaf_oneapi_gpu_models[@]}"
        done
    done

    cd "$BASE/cloverleaf/results"
    bench_exec exec_build pvc-idc $ONEAPI omp kokkos "${tealeaf_oneapi_gpu_models[@]}"

    for bm in 4 16 64 256; do
        for stage in true false; do
            export INPUT_BM="${bm}"
            export STAGE="$stage"
            bench_exec exec_submit pvc-idc $ONEAPI omp kokkos "${tealeaf_oneapi_gpu_models[@]}"
        done
    done
    ;;
nvidia)

    cd "$BASE/babelstream/results"
    bench_once a100-nvidia $NVHPC "${babelstream_nvhpc_gpu_models[@]}"
    bench_once a100-nvidia $ONEAPI "${babelstream_oneapi_gpu_models[@]}"
    bench_exec exec_build a100-nvidia $HIPSYCL std-indices sycl

    bench_once h100-nvidia $NVHPC "${babelstream_nvhpc_gpu_models[@]}"
    bench_once h100-nvidia $ONEAPI "${babelstream_oneapi_gpu_models[@]}"
    bench_exec exec_build h100-nvidia $HIPSYCL std-indices sycl

    ##########

    export INPUT_BM=5
    cd "$BASE/tealeaf/results"
    rm -rf TeaLeaf
    # GPUs, test with and without staging buffer

    bench_exec exec_build a100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
    bench_exec exec_build a100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
    bench_exec exec_build a100-nvidia $HIPSYCL std-indices sycl-acc sycl-usm

    bench_exec exec_build h100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
    bench_exec exec_build h100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
    bench_exec exec_build h100-nvidia $HIPSYCL std-indices sycl-acc sycl-usm

    for bm in 1 2 4 8; do
        for stage in true false; do
            export INPUT_BM="5e_${bm}_4"
            export STAGE="$stage"
            bench_exec exec_submit a100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
            bench_exec exec_submit a100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"

            bench_exec exec_submit h100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
            bench_exec exec_submit h100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
        done
    done

    ##########

    cd "$BASE/cloverleaf/results"
    rm -rf CloverLeaf
    # GPUs, test with and without staging buffer

    bench_exec exec_build a100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
    bench_exec exec_build a100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
    bench_exec exec_build a100-nvidia $HIPSYCL std-indices sycl-acc sycl-usm

    bench_exec exec_build h100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
    bench_exec exec_build h100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
    bench_exec exec_build h100-nvidia $HIPSYCL std-indices sycl-acc sycl-usm

    for bm in 4 16 64 256; do
        for stage in true false; do
            export INPUT_BM="${bm}_300"
            export STAGE="$stage"
            bench_exec exec_submit a100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
            bench_exec exec_submit a100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"

            bench_exec exec_submit h100-nvidia $NVHPC "${tealeaf_nvhpc_gpu_models[@]}"
            bench_exec exec_submit h100-nvidia $ONEAPI "${tealeaf_oneapi_gpu_models[@]}"
        done
    done

    ;;
p3)
    module use "$HOME/modulefiles/"

    cd "$BASE/babelstream/results"
    # module unload cce
    bench_once milan-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    # module load cce
    bench_once milan-isambard $GCC "${babelstream_gcc_cpu_models[@]}"
    bench_once milan-isambard $ONEAPI "${babelstream_oneapi_cpu_models[@]}"
    bench_once milan-isambard $HIPSYCL std-indices sycl

    bench_once mi100-isambard $AOMP "${babelstream_aomp_gpu_models[@]}"
    bench_once mi100-isambard $ROCM "${babelstream_rocm_gpu_models[@]}"
    bench_once mi100-isambard $ONEAPI "${babelstream_oneapi_gpu_models[@]}"
    bench_once mi100-isambard $HIPSYCL std-indices sycl

    ##########

    cd "$BASE/tealeaf/results"

    # CPUs
    bench_exec exec_build milan-isambard $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
    bench_exec exec_build milan-isambard $GCC "${tealeaf_gcc_cpu_models[@]}"
    bench_exec exec_build milan-isambard $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"
    bench_exec exec_build milan-isambard $HIPSYCL std-indices sycl-acc sycl-usm
    for bm in 1 2 4 8; do
        # for bm in 2; do
        export INPUT_BM="5e_${bm}"
        bench_exec exec_submit milan-isambard $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
        bench_exec exec_submit milan-isambard $GCC "${tealeaf_gcc_cpu_models[@]}"
        bench_exec exec_submit milan-isambard $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"
        bench_exec exec_submit milan-isambard $HIPSYCL std-indices sycl-acc sycl-usm
    done

    # GPUs, test with staging buffer
    bench_exec exec_build mi100-isambard $AOMP "${tealeaf_aomp_gpu_models[@]}"
    bench_exec exec_build mi100-isambard $ROCM "${tealeaf_rocm_gpu_models[@]}"
    bench_exec exec_build mi100-isambard $ONEAPI sycl-acc  # "${tealeaf_oneapi_gpu_models[@]}"
    bench_exec exec_build mi100-isambard $HIPSYCL sycl-acc # sycl-usm std-indices
    for bm in 1 2 4 8; do
        # for bm in 2; do
        for stage in true false; do
            export INPUT_BM="5e_${bm}"
            export STAGE="$stage"
            bench_exec exec_submit mi100-isambard $AOMP "${tealeaf_aomp_gpu_models[@]}"
            bench_exec exec_submit mi100-isambard $ROCM "${tealeaf_rocm_gpu_models[@]}"
            bench_exec exec_submit mi100-isambard $ONEAPI sycl-acc  # "${tealeaf_oneapi_gpu_models[@]}"
            bench_exec exec_submit mi100-isambard $HIPSYCL sycl-acc # sycl-usm std-indices
        done
    done

    ##########

    cd "$BASE/cloverleaf/results"

    # CPUs
    bench_exec exec_build milan-isambard $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
    bench_exec exec_build milan-isambard $GCC "${tealeaf_gcc_cpu_models[@]}"
    bench_exec exec_build milan-isambard $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"
    for bm in 4 16 64 256; do
        # for bm in 16; do
        export INPUT_BM="${bm}_short"
        bench_exec exec_submit milan-isambard $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
        bench_exec exec_submit milan-isambard $GCC "${tealeaf_gcc_cpu_models[@]}"
        bench_exec exec_submit milan-isambard $ONEAPI "${tealeaf_oneapi_cpu_models[@]}"
    done

    # GPUs, test with staging buffer
    bench_exec exec_build mi100-isambard $AOMP "${tealeaf_aomp_gpu_models[@]}"
    bench_exec exec_build mi100-isambard $ROCM "${tealeaf_rocm_gpu_models[@]}"
    bench_exec exec_build mi100-isambard $ONEAPI sycl-acc  # "${tealeaf_oneapi_gpu_models[@]}"
    bench_exec exec_build mi100-isambard $HIPSYCL sycl-acc # sycl-usm std-indices
    for bm in 4 16 64 256; do
        # for bm in 16; do
        for stage in true false; do
            export INPUT_BM="${bm}"
            export STAGE="$stage"
            bench_exec exec_submit mi100-isambard $AOMP "${tealeaf_aomp_gpu_models[@]}"
            bench_exec exec_submit mi100-isambard $ROCM "${tealeaf_rocm_gpu_models[@]}"
            bench_exec exec_submit mi100-isambard $ONEAPI sycl-acc  # "${tealeaf_oneapi_gpu_models[@]}"
            bench_exec exec_submit mi100-isambard $HIPSYCL sycl-acc # sycl-usm std-indices
        done
    done
    ;;
p2) ;;  # nope
xci) ;; # nope
aws)
    cd "$BASE/babelstream/results"
    # bench_once graviton3e-aws $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    # bench_once graviton3e-aws $GCC "${babelstream_gcc_cpu_models[@]}"
    # bench_once graviton3e-aws $ACFL "${babelstream_gcc_cpu_models[@]}"
    # bench_once graviton3e-aws $HIPSYCL std-indices sycl

    cd "$BASE/cloverleaf/results"

    # (
    #     bench_exec exec_build graviton3e-aws $NVHPC "${tealeaf_nvhpc_cpu_models[@]}" &
    #     bench_exec exec_build graviton3e-aws $GCC "${tealeaf_gcc_cpu_models[@]}" &
    #     bench_exec exec_build graviton3e-aws $ACFL "${tealeaf_gcc_cpu_models[@]}" &
    #     bench_exec exec_build graviton3e-aws $HIPSYCL std-indices sycl-acc sycl-usm &
    #     wait
    # )

    for bm in 4 16 64 256; do
        # for bm in 16; do
        export INPUT_BM="${bm}"
        bench_exec exec_submit graviton3e-aws $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
        bench_exec exec_submit graviton3e-aws $GCC "${tealeaf_gcc_cpu_models[@]}"
        bench_exec exec_submit graviton3e-aws $ACFL "${tealeaf_gcc_cpu_models[@]}"
        bench_exec exec_submit graviton3e-aws $HIPSYCL std-indices sycl-acc sycl-usm
    done

    cd "$BASE/tealeaf/results"

    # (
    #     bench_exec exec_build graviton3e-aws $NVHPC "${tealeaf_nvhpc_cpu_models[@]}" &
    #     bench_exec exec_build graviton3e-aws $GCC "${tealeaf_gcc_cpu_models[@]}" &
    #     bench_exec exec_build graviton3e-aws $ACFL "${tealeaf_gcc_cpu_models[@]}" &
    #     bench_exec exec_build graviton3e-aws $HIPSYCL std-indices sycl-acc sycl-usm &
    #     wait
    # )
    for bm in 1 2 4 8; do
        # for bm in 1; do
        export INPUT_BM="5e_${bm}"
        bench_exec exec_submit graviton3e-aws $NVHPC "${tealeaf_nvhpc_cpu_models[@]}"
        bench_exec exec_submit graviton3e-aws $GCC "${tealeaf_gcc_cpu_models[@]}"
        bench_exec exec_submit graviton3e-aws $ACFL "${tealeaf_gcc_cpu_models[@]}"
        bench_exec exec_submit graviton3e-aws $HIPSYCL std-indices sycl-acc sycl-usm
    done

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
