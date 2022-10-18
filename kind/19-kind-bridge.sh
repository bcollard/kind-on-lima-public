#docker network delete kind || true
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
#docker network connect kind registries || true