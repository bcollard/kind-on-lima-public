# test if docker daemon is running
if ! docker info > /dev/null 2>&1; then
  echo "Docker daemon is not running. Please start it first."
  exit 1
fi

# pull images
docker pull ${REGISTRY_IMAGE}:${REGISTRY_TAG}
docker pull quay.io/metallb/controller:${METALLB_VERSION}
docker pull quay.io/metallb/speaker:${METALLB_VERSION}
docker pull kindest/node:${KIND_NODE_VERSION}
docker pull quay.io/frrouting/frr:7.5.1

# save images
docker save ${REGISTRY_IMAGE}:${REGISTRY_TAG} > ${LIMA_DATA_DIR}/distribution-distribution-${REGISTRY_TAG}.tar
docker save quay.io/metallb/controller:${METALLB_VERSION} > ${LIMA_DATA_DIR}/quay.io-metallb-controller-${METALLB_VERSION}.tar
docker save quay.io/metallb/speaker:${METALLB_VERSION} > ${LIMA_DATA_DIR}/quay.io-metallb-speaker-${METALLB_VERSION}.tar
docker save kindest/node:${KIND_NODE_VERSION} > ${LIMA_DATA_DIR}/kind-${KIND_NODE_VERSION}-image.tar
docker save quay.io/frrouting/frr:7.5.1 > ${LIMA_DATA_DIR}/quay.io-frrouting-frr-7.5.1.tar
