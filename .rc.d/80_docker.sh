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
    local BIN="${1:+--entrypoint='$1'}"
    local MOUNT="${2:+-v $2}"
    local NETWORK="${3:+--network=$3}"
    local NAT="${4:+-p $4}"
    local PLT="${5:+--platform=$5}"
    local CAPABILITIES="${6:+--cap-add=$6}"
    local PRIVILEGED="${7:+--privileged}"
    shift $(($# > 7 ? 7 : $#))
    docker run -it $BIN $MOUNT $NETWORK $NAT $PLT $CAPABILITIES $PRIVILEGED "$@"
}

# Setup binfmt in docker
# https://stackoverflow.com/questions/72444103/what-does-running-the-multiarch-qemu-user-static-does-before-building-a-containe
docker_setup_binfmt() {
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
}

# Aliases
alias docker_ls_img='docker images'
alias docker_ls_cont='docker container ls'
alias docker_rmi_dangling='docker rmi -f $(docker images -qa -f "dangling=true")'
