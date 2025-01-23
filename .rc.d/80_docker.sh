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

# Setup binfmt in docker
# https://stackoverflow.com/questions/72444103/what-does-running-the-multiarch-qemu-user-static-does-before-building-a-containe
docker_setup_binfmt() {
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
}

# Check if an image exists
docker_img_exists() {
    for IMG; do
        if ! docker inspect --type=image "$IMG" >/dev/null 2>&1; then
            return 1
        fi
    done
    return 0
}

# Check if a container exists
docker_cont_exists() {
    for CONT; do
        if ! docker inspect --type=container "$CONT" >/dev/null 2>&1; then
            return 1
        fi
    done
    return 0
}

# Check if an image has a container running
# http://stackoverflow.com/questions/43721513/ddg#43723174
docker_img_is_running() {
    for IMG; do
        if [ -z "$(docker ps -q --filter ancestor="$IMG" 2>&1)" ]; then
            return 1
        fi
    done
    return 0
}

# Check if a container is running
# http://stackoverflow.com/questions/43721513/ddg#43723174
docker_cont_is_running() {
    for CONT; do
        if [ "$(docker container inspect -f '{{.State.Status}}' "$CONT")" != "running" ]; then
            return 1
        fi
    done
    return 0
}

# List containers sorted by descending creation date
docker_cont_ls() {
    local IMG="${1:+--filter ancestor='$1'}"
    local NUM="${2:+-n $2}"; NUM="${NUM:--a}" # -a or -n show containers in all states
    eval docker container ls -q "$NUM" "$IMG"
}

# List running containers sorted by descending creation date
docker_cont_ls_running() {
    local IMG="${1:+--filter ancestor='$1'}"
    local NUM="${2:--0}" # head -n -0 shows all
    eval docker container ls -q "$IMG" | head -n "$NUM"
}

# Check if a tty is attached to a container
docker_cont_is_attached() {
    for CONT; do
        if ! pgrep -f "docker.*attach $CONT" >/dev/null 2>&1; then
            return 1
        fi
    done
    return 0
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
    local NAME="${NAME:+-u $NAME}"
    local WORKDIR="${WORKDIR:+--workdir $WORKDIR}"
    local REMOVE_CONT="${REMOVE_CONT:+--rm}"
    local ENV="${ENV:+--env $ENV}" # Ex: -e VAR=xxx"
    shift
    docker run -it $BIN $MOUNT $NETWORK $NAT $DEVICE $PLT $CAPABILITIES $PRIVILEGED $NAME $WORKDIR $REMOVE_CONT $ENV "$IMG" "$@"
}

# Docker run inside an existing container in interactive mode (-i) with a terminal (-t)
docker_exec() {
    local CONTAINER="${1:?No container specified...}"
    local PRIVILEGED="${PRIVILEGED:+--privileged}"
    local NAME="${NAME:+-u $NAME}"
    local WORKDIR="${WORKDIR:+--workdir $WORKDIR}"
    local ENV="${ENV:+--env $ENV}" # Ex: -e VAR=xxx"
    shift
    docker exec -it $PRIVILEGED $NAME $WORKDIR $ENV "$CONTAINER" "${@:sh}"
}

# Attach to containers
docker_attach() {
    for CONT; do
        if docker_cont_is_running "$CONT"; then
            if docker_cont_is_attached "$CONT"; then
                docker_exec "$CONT"
            else
                docker attach "$CONT"
            fi
        else
            docker start -ia "$CONT"
        fi
    done
}

# Resume & attach a container
docker_resume() {
    for CONT; do
        docker start "$1" &&
        docker attach "$1" ||
        true
    done
}

# Docker start an existing container & attach
docker_start() {
    local IMG_OR_CONT="${1:?No image or container specified...}"
    if docker_img_exists "$IMG_OR_CONT"; then
        local LAST_CONT="$(docker_cont_ls "$IMG_OR_CONT" 1)"
        if [ -n "$LAST_CONT" ]; then
            echo "Resume image $IMG_OR_CONT newest container $LAST_CONT"
            docker container ls -a --filter id="$LAST_CONT"
            docker_attach "$LAST_CONT"
        else # Image never ran
            echo "Start a new container for image $IMG_OR_CONT"
            docker image ls -a | awk -v id="$IMG_OR_CONT" '{if (match($3, id) || NR==1) {print $0}}'
            docker_run "$@"
        fi
    elif docker_cont_exists "$IMG_OR_CONT"; then
        echo "Resume the container: $IMG_OR_CONT"
        docker container ls -a --filter id="$IMG_OR_CONT"
        docker_attach "$@"
    else
        echo >&2 "Error: neither image or container $IMG_OR_CONT exist..."
        return 1
    fi
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

# Stop specific containers (by id, name or image name) or all containers
docker_stop() {
    if [ $# -eq 0 ]; then
        docker ps -q | xargs -r docker stop
    else
        for VAL; do
            docker ps -q --filter id="$VAL" | xargs -r docker stop
            docker ps -q --filter name="$VAL" | xargs -r docker stop
            docker ps -q --filter ancestor="$VAL" | xargs -r docker stop
        done
    fi
}

# Delete specific containers (by id, name or image name)
docker_rm_cont() {
    for VAL; do
        docker container ls -aq --filter id="$VAL" | xargs -r docker container rm -f
        docker container ls -aq --filter name="$VAL" | xargs -r docker container rm -f
        docker container ls -aq --filter ancestor="$VAL" | xargs -r docker container rm -f
    done
}

# Delete image
docker_rm_img() {
    docker_stop "$@"
    for IMG; do
        docker rmi -f "$IMG"
    done
}

# Get docker run command
docker_cmdline() {
    python3 - "$@" <<EOF
#!/bin/python3
import sys
import json
import traceback
import subprocess
if __name__ == '__main__':
    out = subprocess.getoutput('docker container inspect "%s" >&2' % container)
    res = json.loads(out)
    for cont in res:
        cmd = ['docker', 'run']
        # From cont[]
        if cont['Platform']: cmd += ['--platform=' + cont['Platform']]
        # From cont['Config']
        if cont['Config']['AttachStdin']: cmd += ['-i']
        if cont['Config']['Tty']: cmd += ['-t']
        if cont['Config']['User']: cmd += ['--user=' + cont['Config']['User']]
        if cont['Config']['WorkingDir']: cmd += ['--workdir=' + cont['Config']['WorkingDir']]
        if cont['Config']['Entrypoint']: cmd += ['--entrypoint=' + cont['Config']['Entrypoint']]
        for env in cont['Config']['Env'] or (): cmd += ['--env', env]
        # From cont['HostConfig']
        for bind in cont['HostConfig']['Binds'] or (): cmd += ['--volume=' + bind]
        for dev in cont['HostConfig']['Devices'] or (): cmd += ['--device=%s:%s:%s' % (dev['PathOnHost'], dev['PathInContainer'], dev['CgroupPermissions'])]
        for cap in cont['HostConfig']['CapAdd'] or (): cmd += ['--cap-add=' + cap]
        if cont['HostConfig']['NetworkMode']: cmd += ['--network=' + cont['HostConfig']['NetworkMode']]
        if cont['HostConfig']['Privileged']: cmd += ['--privileged']
        if cont['HostConfig']['AutoRemove']: cmd += ['--rm']
        cmd += [cont['Config']['Image']]
        # Finalize with the cmd to execute
        cmd += [cont['Path']]
        for arg in cont['Args'] or (): cmd += [arg]
        # Print command line
        print(' '.join(cmd))
EOF
}

# Aliases
alias docker_run_rm='docker_run --rm'
alias docker_lsi='docker images'
alias docker_lsc='docker container ls'
alias docker_lsca='docker container ls -a'
alias docker_rmi='docker rmi'
alias docker_rmif='docker rmi -f'
alias docker_rmc='docker rm'
alias docker_rmcf='docker rm -f'
alias docker_rmi_dangling='docker image prune || { docker images -qa -f "dangling=true" | xargs -r docker rmi -f; }'
alias docker_rmc_dangling='docker container prune || { docker container ls -a | cut -f1 | tail -n +2 | xargs -r docker rm -f; }'
alias docker_rm_dangling='docker_rmc_dangling && docker_rmi_dangling'
# Tool to get container runtime parameters
alias docker_args='docker_cmdline'
alias runlike="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro assaflavie/runlike"
