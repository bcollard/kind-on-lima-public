#!/usr/bin/env bash

# create a new function named log that takes two arguments: the first is the word to be coloered in red, the second is the sentence with default color
log() {
  RED='\e[31m'
  CYAN='\e[36m'
  NC='\e[0m'
  echo -e "${CYAN}[${NAME}]${NC} $1"
}

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

# if kubernetes context already exists, delete it
if kubectl config get-contexts ${NAME} > /dev/null 2>&1; then
  log "Deleting existing kubernetes context ${NAME}"
  kubectl config delete-context ${NAME}
fi

# let
TWO_DIGITS=$(printf "%02d\n" ${NUM})
KIND_HOME_DIR=${HOME}/.kube/kind
KUBE_CONFIG_FILE=${KIND_HOME_DIR}/${NAME}.kubeconfig
CLUSTER_CONFIG_FILE=${KIND_HOME_DIR}/${NAME}.yaml
METALLB_CONFIG_FILE=${KIND_HOME_DIR}/${NAME}-metallb.yaml

# PREP
rm -v ${KUBE_CONFIG_FILE} || true
rm -v ${CLUSTER_CONFIG_FILE} || true
rm -v ${METALLB_CONFIG_FILE} || true

## KIND 

# CLUSTER config with CONTAINERD PATCHES
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
# - role: worker
# - role: worker
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
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${LOCALHOST_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${LOCALHOST_CACHE_NAME}:${LOCALHOST_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${LOCALHOST_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${LOCALHOST_LOCAL_URL_ALIAS}:5000"]
    endpoint = ["http://${LOCALHOST_CACHE_NAME}:${LOCALHOST_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${LOCALHOST_LOCAL_URL_ALIAS}:5000".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${QUAYIO_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${QUAYIO_CACHE_NAME}:${QUAYIO_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${QUAYIO_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${GCRIO_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${GCRIO_CACHE_NAME}:${GCRIO_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${GCRIO_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${DOCKERIO_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${DOCKERIO_CACHE_NAME}:${DOCKERIO_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${DOCKERIO_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${DOCKERIO_LOCAL_URL_ALIAS}".auth]
    username = "${DOCKERHUB_USERNAME}"
    password = "${DOCKERHUB_PASSWORD}"
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${DOCKERIO_REG1_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${DOCKERIO_REG1_CACHE_NAME}:${DOCKERIO_REG1_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${DOCKERIO_REG1_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${DOCKERIO_REG1_LOCAL_URL_ALIAS}".auth]
    username = "${DOCKERHUB_USERNAME}"
    password = "${DOCKERHUB_PASSWORD}"
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${USDOCKERPKGDEV_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${USDOCKERPKGDEV_CACHE_NAME}:${USDOCKERPKGDEV_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${USDOCKERPKGDEV_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${USCENTRAL1DOCKERPKGDEV_LOCAL_URL_ALIAS}"]
    endpoint = ["http://${USCENTRAL1DOCKERPKGDEV_CACHE_NAME}:${USCENTRAL1DOCKERPKGDEV_CACHE_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."${USCENTRAL1DOCKERPKGDEV_LOCAL_URL_ALIAS}".tls]
    insecure_skip_verify = true
EOF

# KinD image
kind_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "kindest/node:${KIND_NODE_VERSION}" | wc -l)
if [ ${kind_img_loaded} -ne 1 ]; then
  log "Loading the KinD node image to the VM..."
  docker load < ${LIMA_DATA_DIR}/kind-${KIND_NODE_VERSION}-image.tar
fi

# KinD cluster
log "Creating the KinD cluster with name ${NAME}"
kind create cluster --config=${CLUSTER_CONFIG_FILE} --image kindest/node:${KIND_NODE_VERSION} --retain --name ${NAME} --kubeconfig ${KUBE_CONFIG_FILE}
#kind export logs --name ${NAME}; kind delete cluster
log "KinD cluster creation complete!"

# rename the kubernetes context 
kubectl --kubeconfig ${KUBE_CONFIG_FILE} config rename-context "kind-${NAME}" "${NAME}"

export CONTEXT_NAME="${NAME}"
export SUBNET_PREFIX=`docker network inspect kind | jq -r '.[0].IPAM.Config[0].Subnet' | awk -F. '{print $1"."$2}'`

# METALLB
# MetalLB image
metallb_img_loaded=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep "quay.io/metallb/controller:${METALLB_VERSION}" | wc -l)
if [ ${metallb_img_loaded} -ne 1 ]; then
  log "Loading the MetalLB image to the VM..."
  docker load < ${LIMA_DATA_DIR}/quay.io-metallb-controller-${METALLB_VERSION}.tar
  docker load < ${LIMA_DATA_DIR}/quay.io-metallb-speaker-${METALLB_VERSION}.tar
  docker load < ${LIMA_DATA_DIR}/quay.io-frrouting-frr-7.5.1.tar
fi

log "Loading the MetalLB images to the KinD node"
kind load image-archive ${LIMA_DATA_DIR}/quay.io-metallb-controller-${METALLB_VERSION}.tar --name ${NAME}
kind load image-archive ${LIMA_DATA_DIR}/quay.io-metallb-speaker-${METALLB_VERSION}.tar --name ${NAME}
kind load image-archive ${LIMA_DATA_DIR}/quay.io-frrouting-frr-7.5.1.tar --name ${NAME}

log "Installing MetalLB"
# kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} apply -f ${LIMA_WORKDIR}/metallb/namespace.yaml
# kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" 
# kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} apply -f ${LIMA_WORKDIR}/metallb/metallb.yaml
## # https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml
## # https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-frr.yaml
kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} apply -f ${LIMA_WORKDIR}/metallb/metallb-native-${METALLB_VERSION}.yaml
kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} apply -f ${LIMA_WORKDIR}/metallb/metallb-frr-${METALLB_VERSION}.yaml

kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} -n metallb-system wait pod --all --timeout=90s --for=condition=Ready
kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} -n metallb-system wait deploy controller --timeout=90s --for=condition=Available
kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} -n metallb-system wait apiservice v1beta1.metallb.io --timeout=90s --for=condition=Available

sleep 5

log "Configuring MetalLB (with Layer 2)"
cat << EOF > ${METALLB_CONFIG_FILE}
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - ${SUBNET_PREFIX}.${NUM}.1-${SUBNET_PREFIX}.${NUM}.7
  - ${SUBNET_PREFIX}.${NUM}.16-${SUBNET_PREFIX}.${NUM}.254
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
EOF

log "Applying file ${METALLB_CONFIG_FILE}"
kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} apply -f ${METALLB_CONFIG_FILE}

log "Configuring local registry"
cat <<EOF | kubectl --kubeconfig ${KUBE_CONFIG_FILE} --context ${CONTEXT_NAME} apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "${LOCALHOST_CACHE_NAME}:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# sleep random time
sleep $((1 + RANDOM % 10))

# kubeconfig merging
log "Importing the new kubeconfig file at ${KUBE_CONFIG_FILE}"
kubectl konfig import -s ${KUBE_CONFIG_FILE}

log "Imported OK"
kubectl config view # -minify --flatten --context ${NAME} > ${KUBE_CONFIG_FILE}

log "End of script"
