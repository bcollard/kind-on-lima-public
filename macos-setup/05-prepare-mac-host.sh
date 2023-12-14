# lima workdirs
# test if ${LIMA_HOME} exists
if [ ! -d "${LIMA_HOME}" ]; then
  mkdir ${LIMA_HOME}
fi
# test if ${LIMA_WORKDIR} exists
if [ ! -d "${LIMA_WORKDIR}" ]; then
  mkdir ${LIMA_WORKDIR}
fi

# docker work dir and cache dirs
if [ ! -d "${LIMA_DATA_DIR}" ]; then
  sudo mkdir ${LIMA_DATA_DIR}
fi
sudo chown $(whoami) ${LIMA_DATA_DIR}
sudo mkdir -p ${LOCALHOST_CACHE_DIR} ${GCRIO_CACHE_DIR} ${QUAYIO_CACHE_DIR} ${DOCKERIO_CACHE_DIR} ${DOCKERIO_REG1_CACHE_DIR} ${USDOCKERPKGDEV_CACHE_DIR} ${USCENTRAL1DOCKERPKGDEV_CACHE_DIR}
sudo chown $(whoami) ${LOCALHOST_CACHE_DIR} ${GCRIO_CACHE_DIR} ${QUAYIO_CACHE_DIR} ${DOCKERIO_CACHE_DIR} ${DOCKERIO_REG1_CACHE_DIR} ${USDOCKERPKGDEV_CACHE_DIR} ${USCENTRAL1DOCKERPKGDEV_CACHE_DIR}
