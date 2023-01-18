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
  ZONE=europe-west1-b
fi
TWO_DIGITS=$(printf "%02d\n" ${NUM})
KIND_HOME_DIR=${HOME}/.kube/kind
CLUSTER_CONFIG_FILE=${KIND_HOME_DIR}/$NAME.yaml
METALLB_CONFIG_FILE=${KIND_HOME_DIR}/$NAME-metallb.yaml

# PREP
rm -v ${CLUSTER_CONFIG_FILE} || true
rm -v ${METALLB_CONFIG_FILE} || true

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
kubeadmConfigPatches:
- |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true,topology.kubernetes.io/region=${REGION},topology.kubernetes.io/zone=${ZONE}"
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
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."us-docker.pkg.dev"]
    endpoint = ["http://${USDOCKERPKGDEV_CACHE_NAME}:${USDOCKERPKGDEV_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."us-docker.pkg.dev".tls]
    insecure_skip_verify = true
EOF

# KinD image
kind_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "kindest/node:${KIND_NODE_VERSION}" | wc -l)
if [ ${kind_img_loaded} -ne 1 ]; then
  echo "Loading the KinD node image to the VM..."
  docker load < ${LIMA_DATA_DIR}/kind-${KIND_NODE_VERSION}-image.tar
fi

# KinD cluster
echo "Creating the KinD cluster with name ${NAME}"
kind create cluster -q --config=${CLUSTER_CONFIG_FILE} --image kindest/node:${KIND_NODE_VERSION} --retain
#kind export logs --name ${NAME}; kind delete cluster
echo "KinD cluster creation complete!"

export CONTEXT_NAME="kind-${NAME}"

# METALLB
echo "Loading the MetalLB images to the KinD node"
kind load image-archive ${LIMA_DATA_DIR}/quay.io-metallb-controller-v0.11.0.tar --name ${NAME}
kind load image-archive ${LIMA_DATA_DIR}/quay.io-metallb-speaker-v0.11.0.tar --name ${NAME}

echo "Installing MetalLB"
kubectl --context ${CONTEXT_NAME} apply -f ${LIMA_WORKDIR}/metallb/namespace.yaml
kubectl --context ${CONTEXT_NAME} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" 
kubectl --context ${CONTEXT_NAME} apply -f ${LIMA_WORKDIR}/metallb/metallb.yaml
kubectl --context ${CONTEXT_NAME} -n metallb-system wait po --for condition=Ready --timeout -1s --all

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

kubectl --context ${CONTEXT_NAME} apply -f ${METALLB_CONFIG_FILE}

# Registries
echo "Configuring image registry mirrors"
exec ${LIMA_WORKDIR}/lima/17-docker-registries.sh
echo "Registries configured and attached to local Kind bridge"

echo "End of script"
