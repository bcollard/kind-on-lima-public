#!/usr/bin/env bash

echo "Using limactl version: "
${LIMA_WORKDIR}/bin/limactl --version

# limactl start ./03-docker.yaml
${LIMA_WORKDIR}/bin/limactl start ./lima/${LIMA_INSTANCE}.yaml --tty=false --name ${LIMA_INSTANCE}

${LIMA_WORKDIR}/bin/lima -- sudo sysctl fs.inotify.max_user_watches=524288
${LIMA_WORKDIR}/bin/lima -- sudo sysctl fs.inotify.max_user_instances=512
