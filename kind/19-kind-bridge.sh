echo "Creating the 'kind' docker network, type bridge"
docker network create \
    -d=bridge \
    --scope=local \
    --attachable=false \
    --gateway=172.18.0.1 \
    --ingress=false \
    --internal=false \
    --subnet=172.18.0.0/16 \
    -o "com.docker.network.bridge.enable_ip_masquerade"="true" \
    -o "com.docker.network.driver.mtu"="1500" kind || true

echo "Configuring the 'kind' network with the docker registries"
docker network connect kind ${DOCKERIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${DOCKERIO_REG1_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${QUAYIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${GCRIO_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${USDOCKERPKGDEV_CACHE_NAME} 2>/dev/null || true
docker network connect kind ${USCENTRAL1DOCKERPKGDEV_CACHE_NAME} 2>/dev/null || true

