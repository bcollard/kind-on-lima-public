# docker work dir and cache dirs
sudo mkdir ${LIMA_DATA_DIR}
sudo chown $(whoami) ${LIMA_DATA_DIR}
sudo mkdir ${GCRIO_CACHE_DIR} ${QUAYIO_CACHE_DIR} ${DOCKERIO_CACHE_DIR} ${USDOCKERPKGDEV_CACHE_DIR}

# pull images
docker pull distribution/distribution:2.8.1
docker pull quay.io/metallb/controller:v0.11.0
docker pull quay.io/metallb/speaker:v0.11.0
docker pull nginx:1.22
docker pull kindest/node:${KIND_NODE_VERSION}

# save images
docker save distribution/distribution:2.8.1 > ${LIMA_DATA_DIR}/distribution-distribution-2.8.1.tar
docker save quay.io/metallb/controller:v0.11.0 > ${LIMA_DATA_DIR}/quay.io-metallb-controller-v0.11.0.tar
docker save quay.io/metallb/speaker:v0.11.0 > ${LIMA_DATA_DIR}/quay.io-metallb-speaker-v0.11.0.tar
docker save nginx:1.22 > ${LIMA_DATA_DIR}/nginx-1.22-image.tar
docker save kindest/node:${KIND_NODE_VERSION} > ${LIMA_DATA_DIR}/kind-${KIND_NODE_VERSION}-image.tar


