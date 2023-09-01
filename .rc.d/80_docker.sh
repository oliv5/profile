#!/bin/sh

# Build an image
docker_build() {
    local DOCKERFILE="${1:?No dockerfile specified...}"
    local NAME="${2:?No image name specified...}"
    local TAG="${3:-latest}"
    local DIR="${4:-.}"
    echo "Using folder '$DIR' (and its content) as context"
    docker build -t "$NAME:$TAG" -f "$DOCKERFILE" "$DIR"
}

# Docker run
docker_run() {
    local IMG="${1:?No image specified...}"
    local BIN="${2:+--entrypoint='$2'}"
    local MOUNT="${3:+-v $3}"
    local NETWORK="${4:+--network=$4}"
    local NAT="${5:+-p $5}"
    local DEVICE="${6:+--device=$6}"
    local PLT="${7:+--platform=$7}"
    local CAPABILITIES="${8:+--cap-add=$8}"
    local PRIVILEGED="${9:+--privileged}"
    shift $(($# > 9 ? 9 : $#))
    docker run -it $BIN $MOUNT $NETWORK $NAT $DEVICE $PLT $CAPABILITIES $PRIVILEGED "$IMG" "$@"
}

# Setup binfmt in docker
# https://stackoverflow.com/questions/72444103/what-does-running-the-multiarch-qemu-user-static-does-before-building-a-containe
docker_setup_binfmt() {
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
}

# Stop container by image name
docker_stopc_by_img() {
    for IMG; do
        docker ps -q --filter ancestor="$IMG" | xargs -r docker stop
    done
}
docker_rmc_by_img() {
    for IMG; do
        docker container ls -q --filter ancestor="$IMG" | xargs -r docker container rm -f
    done
}

# Delete image
docker_rmi() {
    docker_stopc_by_img "$@"
    for IMG; do
        docker rmi -f "$IMG"
    done
}

# Aliases
alias docker_ls_img='docker images'
alias docker_ls_cont='docker container ls'
alias docker_rmi_dangling='docker image prune || { docker images -qa -f "dangling=true" | xargs -r docker rmi -f; }'
alias docker_rmc_dangling='docker container prune || { docker container ls -a | cut -f1 | tail -n +2 | xargs -r docker rm -f; }'
