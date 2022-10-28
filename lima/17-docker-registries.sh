#!/usr/bin/env bash


# DOCKER IMAGE CACHES (registry:2)
registry_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep registry:2 | wc -l)
if [ ${registry_img_loaded} -ne 1 ]; then
  echo "Loading the registry:2 image into the VM..."
  docker load < ${REGISTRIES_ROOT_DIR}/registry-image.tar
fi

DOCKERIO_CACHE_NAME='registry-dockerio'
DOCKERIO_CACHE_PORT='5030'
DOCKERIO_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${DOCKERIO_CACHE_NAME}" 2>/dev/null || true)"
QUAYIO_CACHE_NAME='registry-quayio'
QUAYIO_CACHE_PORT='5010'
QUAYIO_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${QUAYIO_CACHE_NAME}" 2>/dev/null || true)"
GCRIO_CACHE_NAME='registry-gcrio'
GCRIO_CACHE_PORT='5020'
GCRIO_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${GCRIO_CACHE_NAME}" 2>/dev/null || true)"

# clean stopped containers
if [ "${DOCKERIO_CACHE_RUNNING}" = "false" ]; then
  echo "Removing stopped container ${DOCKERIO_CACHE_NAME}"
  docker rm -f "${DOCKERIO_CACHE_NAME}" 2>/dev/null || true
fi
if [ "${QUAYIO_CACHE_RUNNING}" = "false" ]; then
  echo "Removing stopped container ${QUAYIO_CACHE_NAME}"
  docker rm -f "${QUAYIO_CACHE_NAME}" 2>/dev/null || true
fi
if [ "${GCRIO_CACHE_RUNNING}" = "false" ]; then
  echo "Removing stopped container ${GCRIO_CACHE_NAME}"
  docker rm -f "${GCRIO_CACHE_NAME}" 2>/dev/null || true
fi

# docker.io mirror
if [[ -z "${DOCKERIO_CACHE_RUNNING}" || "${DOCKERIO_CACHE_RUNNING}" = "false" ]] ; then
  cat > ${KIND_HOME_DIR}/dockerio-cache-config.yml <<EOF
version: 0.1
proxy:
  remoteurl: https://registry-1.docker.io
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :${DOCKERIO_CACHE_PORT}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
  echo "Starting docker.io mirror"
  docker run \
    -d --restart=always -v ${KIND_HOME_DIR}/dockerio-cache-config.yml:/etc/docker/registry/config.yml -p ${DOCKERIO_CACHE_PORT}:${DOCKERIO_CACHE_PORT} \
    -v ${DOCKERIO_CACHE_DIR}:/var/lib/registry --name "${DOCKERIO_CACHE_NAME}" \
    registry:2
fi
# quay.io mirror
if [[ -z "${QUAYIO_CACHE_RUNNING}" || "${QUAYIO_CACHE_RUNNING}" = "false" ]] ; then
  cat > ${KIND_HOME_DIR}/quayio-cache-config.yml <<EOF
version: 0.1
proxy:
  remoteurl: https://quay.io
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :${QUAYIO_CACHE_PORT}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
  echo "Starting quay.io mirror"
  docker run \
    -d --restart=always -v ${KIND_HOME_DIR}/quayio-cache-config.yml:/etc/docker/registry/config.yml -p ${QUAYIO_CACHE_PORT}:${QUAYIO_CACHE_PORT} \
    -v ${QUAYIO_CACHE_DIR}:/var/lib/registry --name "${QUAYIO_CACHE_NAME}" \
    registry:2 
fi
# gcr.io mirror
if [[ -z "${GCRIO_CACHE_RUNNING}" || "${GCRIO_CACHE_RUNNING}" = "false" ]] ; then
  cat > ${KIND_HOME_DIR}/gcrio-cache-config.yml <<EOF
version: 0.1
proxy:
  remoteurl: https://gcr.io
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :${GCRIO_CACHE_PORT}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
  echo "Starting gcr.io mirror"
  docker run \
    -d --restart=always -v ${KIND_HOME_DIR}/gcrio-cache-config.yml:/etc/docker/registry/config.yml -p ${GCRIO_CACHE_PORT}:${GCRIO_CACHE_PORT} \
    -v ${GCRIO_CACHE_DIR}:/var/lib/registry --name "${GCRIO_CACHE_NAME}" \
    registry:2 
fi

# NETWORK SETUP FOR DOCKER REGISTRIES
echo "Setting up the network for the docker registries"
docker network connect kind ${DOCKERIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${QUAYIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${GCRIO_CACHE_NAME} 2>/dev/null || true

