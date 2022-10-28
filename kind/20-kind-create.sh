#!/usr/bin/env bash

NUM=$1
NAME=$2
REGION=$3
ZONE=$4

# USAGE
if [ -z "$1" -o -z "$2" ]; then
  echo "Usage: $0 <KinD instance number> <kind cluster name>"
  exit 1
fi

# VARS
if [ -z "$3" ]; then
  REGION=europe-west1
fi

if [ -z "$4" ]; then
  REGION=europe-west1-b
fi
TWO_DIGITS=$(printf "%02d\n" ${NUM})
KIND_HOME_DIR=${HOME}/.kube/kind
CLUSTER_CONFIG_FILE=${KIND_HOME_DIR}/$NAME.yaml
METALLB_CONFIG_FILE=${KIND_HOME_DIR}/$NAME-metallb.yaml

# PREP
rm -v ${CLUSTER_CONFIG_FILE}
rm -v ${METALLB_CONFIG_FILE}
mkdir -p ${KIND_HOME_DIR}

# DOCKER IMAGE CACHES ("registry v2" or "distribution:2.8.1")
registry_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "${REGISTRY_IMAGE_TAG}" | wc -l)
if [ ${registry_img_loaded} -ne 1 ]; then
  echo "Loading the ${REGISTRY_IMAGE_TAG} image into the VM..."
  # docker load < ${REGISTRIES_ROOT_DIR}/registry-image.tar
  docker load < ${REGISTRIES_ROOT_DIR}/distribution-distribution-2.8.1.tar
fi

mkdir -p ${HOME}/.kube/kind
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

# KIND CLUSTER with CONTAINERD PATCHES
cat << EOF > ${CLUSTER_CONFIG_FILE}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${NAME}
# featureGates:
#   "TokenRequest": true
#   "EphemeralContainers": true
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 6443
    hostPort: 70${TWO_DIGITS}
networking:
  serviceSubnet: "10.${NUM}.0.0/16"
  podSubnet: "10.1${NUM}.0.0/16"
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["http://${DOCKERIO_CACHE_NAME}:${DOCKERIO_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."docker.io".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
    endpoint = ["http://${QUAYIO_CACHE_NAME}:${QUAYIO_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."quay.io".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
    endpoint = ["http://${GCRIO_CACHE_NAME}:${GCRIO_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."gcr.io".tls]
    insecure_skip_verify = true
EOF

# KinD image
kind_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "kindest/node:${KIND_NODE_VERSION}" | wc -l)
if [ ${kind_img_loaded} -ne 1 ]; then
  echo "Loading the KinD node image to the VM..."
  docker load < ${REGISTRIES_ROOT_DIR}/kind-${KIND_NODE_VERSION}-image.tar
fi
echo "Creating the KinD cluster with name ${NAME}"
kind create cluster --config=${CLUSTER_CONFIG_FILE} --image kindest/node:${KIND_NODE_VERSION} --retain
#kind export logs --name ${NAME}; kind delete cluster

# NETWORK SETUP FOR DOCKER REGISTRIES
echo "Setting up the network for the docker registries"
docker network connect kind ${DOCKERIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${QUAYIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${GCRIO_CACHE_NAME} 2>/dev/null || true

# METALLB
echo "Loading the MetalLB images to the KinD node"
kind load image-archive ${REGISTRIES_ROOT_DIR}/quay.io-metallb-controller-v0.11.0.tar --name ${NAME}
kind load image-archive ${REGISTRIES_ROOT_DIR}/quay.io-metallb-speaker-v0.11.0.tar --name ${NAME}

echo "Installing MetalLB"
kubectl apply -f ${LIMA_WORKDIR}/metallb/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" 
kubectl apply -f ${LIMA_WORKDIR}/metallb/metallb.yaml
kubectl -n metallb-system wait po --for condition=Ready --timeout -1s --all

SUBNET_PREFIX=`docker network inspect kind | jq -r '.[0].IPAM.Config[0].Subnet' | awk -F. '{print $1"."$2}'`

cat << EOF > ${METALLB_CONFIG_FILE}
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${SUBNET_PREFIX}.${NUM}.1-${SUBNET_PREFIX}.${NUM}.254
EOF

kubectl apply -f ${METALLB_CONFIG_FILE}

# NGINX
echo "loading the Nginx image archive to Kind cluster ${NAME}"
kind load image-archive ${REGISTRIES_ROOT_DIR}/nginx-1.22-image.tar --name ${NAME}


echo "KinD cluster creation complete!"