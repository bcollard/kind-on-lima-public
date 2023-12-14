#!/usr/bin/env bash

KIND_HOME_DIR=${HOME}/.kube/kind
mkdir -p ${KIND_HOME_DIR}

# DOCKER IMAGE CACHES ("registry v2" or "distribution:2.8.1")
registry_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "${REGISTRY_IMAGE}:${REGISTRY_TAG}" | wc -l)
if [ ${registry_img_loaded} -ne 1 ]; then
  echo "Loading the ${REGISTRY_IMAGE} image into the VM..."
  docker load < ${LIMA_DATA_DIR}/distribution-distribution-${REGISTRY_TAG}.tar
fi

# the gang of four... or more
cat > registries <<EOF
${DOCKERIO_CACHE_NAME} ${DOCKERIO_CACHE_PORT} ${DOCKERIO_REMOTE_URL} ${DOCKERIO_CACHE_DIR} ${DOCKERIO_LOCAL_URL_ALIAS}
${DOCKERIO_REG1_CACHE_NAME} ${DOCKERIO_REG1_CACHE_PORT} ${DOCKERIO_REG1_REMOTE_URL} ${DOCKERIO_REG1_CACHE_DIR} ${DOCKERIO_REG1_LOCAL_URL_ALIAS}
${QUAYIO_CACHE_NAME} ${QUAYIO_CACHE_PORT} ${QUAYIO_REMOTE_URL} ${QUAYIO_CACHE_DIR} ${QUAYIO_LOCAL_URL_ALIAS}
${GCRIO_CACHE_NAME} ${GCRIO_CACHE_PORT} ${GCRIO_REMOTE_URL} ${GCRIO_CACHE_DIR} ${GCRIO_LOCAL_URL_ALIAS}
${USDOCKERPKGDEV_CACHE_NAME} ${USDOCKERPKGDEV_CACHE_PORT} ${USDOCKERPKGDEV_REMOTE_URL} ${USDOCKERPKGDEV_CACHE_DIR} ${USDOCKERPKGDEV_LOCAL_URL_ALIAS}
${USCENTRAL1DOCKERPKGDEV_CACHE_NAME} ${USCENTRAL1DOCKERPKGDEV_CACHE_PORT} ${USCENTRAL1DOCKERPKGDEV_REMOTE_URL} ${USCENTRAL1DOCKERPKGDEV_CACHE_DIR} ${USCENTRAL1DOCKERPKGDEV_LOCAL_URL_ALIAS}
EOF


# THE LOOP
cat registries | while read cache_name cache_port cache_remote_url cache_dir cache_local_url_alias; do

# is the docker cache running?
IS_CACHE_RUNNING="$(docker inspect -f '{{.State.Running}}' "${cache_name}" 2>/dev/null || true)"

# remove the container if stopped
if [ "${IS_CACHE_RUNNING}" = "false" ]; then
  echo "Removing stopped container ${cache_name}"
  docker rm -f "${cache_name}" 2>/dev/null || true
fi

# start the container if not running
if [[ -z "${IS_CACHE_RUNNING}" || "${IS_CACHE_RUNNING}" = "false" ]] ; then
  cat > ${KIND_HOME_DIR}/${cache_name}-cache-config.yml <<EOF
version: 0.1
proxy:
  remoteurl: ${cache_remote_url}
  username: ${DOCKERHUB_USERNAME}
  password: ${DOCKERHUB_PASSWORD}
log:
  fields:
    service: registry
  accesslog:
    disabled: false
  # level: debug

storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :${cache_port}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
  echo "Starting ${cache_name} mirror"
  docker run \
    -d --restart=always -v ${KIND_HOME_DIR}/${cache_name}-cache-config.yml:/etc/docker/registry/config.yml -p "${cache_port}:${cache_port}" \
    -v ${cache_dir}:/var/lib/registry --name "${cache_name}" \
    ${REGISTRY_IMAGE}:${REGISTRY_TAG}

fi

# Connect the cache to the kind docker network
echo "Updating the 'kind' network with the ${cache_name} docker registry"
docker network connect kind ${cache_name} 2>/dev/null || true

done
# END OF LOOP


# LOCALHOST CACHE
reg_name="${LOCALHOST_CACHE_NAME}"
reg_port="${LOCALHOST_CACHE_PORT}"
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" = "false" ]; then
  echo "Removing stopped container ${reg_name}"
  docker rm -f "${reg_name}" 2>/dev/null || true
fi
if [[ -z "${running}" || "${running}" = "false" ]] ; then
  docker run \
    -d --restart=always -p "0.0.0.0:${reg_port}:${reg_port}" --name "${reg_name}" \
    ${REGISTRY_IMAGE}:${REGISTRY_TAG}
fi

docker network connect kind ${reg_name} 2>/dev/null || true

