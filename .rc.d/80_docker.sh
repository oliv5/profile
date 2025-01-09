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

# Docker run a fresh container in interactive mode (-i) with a terminal (-t) from a specific image
docker_run() {
    local IMG="${1:?No image specified...}"
    local BIN="${BIN:+--entrypoint='$BIN'}"
    local MOUNT="${MOUNT:+--volume $MOUNT}" # Ex: --volume=path:path:rw"
    local NETWORK="${NETWORK:+--network=$NETWORK}" # NETWORK=host to allow all accesses
    local NAT="${NAT:+-p $NAT}"
    local DEVICE="${DEVICE:+--device=$DEVICE}"
    local PLT="${PLT:+--platform=$PLT}"
    local CAPABILITIES="${CAPABILITIES:+--cap-add=$CAPABILITIES}"
    local PRIVILEGED="${PRIVILEGED:+--privileged}"
    local USER="${USER:-root}"; USER="${USER:+-u $USER}"
    local WORKDIR="${WORKDIR:+--workdir $WORKDIR}"
    local REMOVE_CONT="${REMOVE_CONT:+--rm}"
    local ENV="${ENV:+--env $ENV}" # Ex: -e VAR=xxx"
    shift
    docker run -it $BIN $MOUNT $NETWORK $NAT $DEVICE $PLT $CAPABILITIES $PRIVILEGED $USER $WORKDIR $REMOVE_CONT $ENV "$IMG" "$@"
}

# Docker start an existing container & attach
docker_resume() {
    docker start "$@"
    docker attach "$@"
}

# Docker run inside an existing container
docker_exec() {
    local CONTAINER="${1:?No container specified...}"
    local PRIVILEGED="${PRIVILEGED:+--privileged}"
    local USER="${USER:+-u $USER}"
    shift
    docker exec -it $BIN $MOUNT $NETWORK $NAT $DEVICE $PLT $CAPABILITIES $PRIVILEGED $USER "$CONTAINER" "$@"
}

# Detach a single or all running container
docker_detach() {
    if [ $# -eq 0 ]; then
        pkill -9 -f 'docker run'
        pkill -9 -f 'docker.*attach'
    else
        for CONT; do
            pkill -9 -f "docker run.*$CONT"
            pkill -9 -f "docker.*attach $CONT"
        done
    fi
}

# Setup binfmt in docker
# https://stackoverflow.com/questions/72444103/what-does-running-the-multiarch-qemu-user-static-does-before-building-a-containe
docker_setup_binfmt() {
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
}

# Stop all containers
docker_stopc_all() {
    docker ps -q | xargs -r docker stop
}

# Stop container by image name
docker_stopc_by_img() {
    for IMG; do
        docker ps -q --filter ancestor="$IMG" | xargs -r docker stop
    done
}

# Delete container by image name
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
alias docker_lsi='docker images'
alias docker_lsc='docker container ls'
alias docker_lsca='docker container ls -a'
alias docker_rmc='docker rm -f'
alias docker_rmi_dangling='docker image prune || { docker images -qa -f "dangling=true" | xargs -r docker rmi -f; }'
alias docker_rmc_dangling='docker container prune || { docker container ls -a | cut -f1 | tail -n +2 | xargs -r docker rm -f; }'
