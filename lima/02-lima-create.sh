#!/usr/bin/env bash

echo "Using limactl version: "
${LIMACTL_BIN} --version

# limactl start ./03-docker.yaml
${LIMACTL_BIN} start ./lima/${LIMA_INSTANCE}.yaml --tty=false --name ${LIMA_INSTANCE}

${LIMA_BIN} -- sudo sysctl fs.inotify.max_user_watches=524288
${LIMA_BIN} -- sudo sysctl fs.inotify.max_user_instances=512
