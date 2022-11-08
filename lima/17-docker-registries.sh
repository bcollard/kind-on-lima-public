#!/usr/bin/env bash
KIND_HOME_DIR=${HOME}/.kube/kind
mkdir -p ${KIND_HOME_DIR}

# DOCKER IMAGE CACHES ("registry v2" or "distribution:2.8.1")
registry_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "${REGISTRY_IMAGE_TAG}" | wc -l)
if [ ${registry_img_loaded} -ne 1 ]; then
  echo "Loading the ${REGISTRY_IMAGE_TAG} image into the VM..."
  docker load < ${LIMA_DATA_DIR}/distribution-distribution-2.8.1.tar
fi

DOCKERIO_CACHE_PORT='5030'
DOCKERIO_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${DOCKERIO_CACHE_NAME}" 2>/dev/null || true)"
QUAYIO_CACHE_PORT='5010'
QUAYIO_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${QUAYIO_CACHE_NAME}" 2>/dev/null || true)"
GCRIO_CACHE_PORT='5020'
GCRIO_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${GCRIO_CACHE_NAME}" 2>/dev/null || true)"
USDOCKERPKGDEV_CACHE_PORT='5040'
USDOCKERPKGDEV_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${USDOCKERPKGDEV_CACHE_NAME}" 2>/dev/null || true)"

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
if [ "${USDOCKERPKGDEV_CACHE_RUNNING}" = "false" ]; then
  echo "Removing stopped container ${USDOCKERPKGDEV_CACHE_NAME}"
  docker rm -f "${USDOCKERPKGDEV_CACHE_NAME}" 2>/dev/null || true
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
    ${REGISTRY_IMAGE_TAG}
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
    ${REGISTRY_IMAGE_TAG} 
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
    ${REGISTRY_IMAGE_TAG} 
fi
# us-docker.pkg.dev mirror
if [[ -z "${USDOCKERPKGDEV_CACHE_RUNNING}" || "${USDOCKERPKGDEV_CACHE_RUNNING}" = "false" ]] ; then
  cat > ${KIND_HOME_DIR}/us-docker.pkg.dev-cache-config.yml <<EOF
version: 0.1
proxy:
  remoteurl: https://us-docker.pkg.dev
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :${USDOCKERPKGDEV_CACHE_PORT}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
  echo "Starting us-docker.pkg.dev mirror"
  docker run \
    -d --restart=always -v ${KIND_HOME_DIR}/us-docker.pkg.dev-cache-config.yml:/etc/docker/registry/config.yml -p ${USDOCKERPKGDEV_CACHE_PORT}:${USDOCKERPKGDEV_CACHE_PORT} \
    -v ${USDOCKERPKGDEV_CACHE_DIR}:/var/lib/registry --name "${USDOCKERPKGDEV_CACHE_NAME}" \
    ${REGISTRY_IMAGE_TAG} 
fi

# NETWORK SETUP FOR DOCKER REGISTRIES
echo "Setting up the network for the docker registries"
docker network connect kind ${DOCKERIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${QUAYIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${GCRIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${USDOCKERPKGDEV_CACHE_NAME} 2>/dev/null || true
