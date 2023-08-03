#!/usr/bin/env sh
set -ex

IMG=p3hpc23_nv:latest
hpccm --recipe=hpccm_recipe.py | docker build -t ${IMG} -

#   --gpus=all \
#   -u $(id -u):$(id -g) \

CMDS="\
  --privileged \
  --ipc=host \
  --ulimit memlock=-1 \
  -h $(hostname) \
  -v $(pwd):/src \
  -w /src \
  $IMG \
"

docker run -it $CMDS
