#!/usr/bin/env bash

# limactl start ./03-docker.yaml
${LIMA_WORKDIR}/bin/limactl start ./lima/docker.yaml --tty=false

${LIMA_WORKDIR}/bin/lima -- sudo sysctl fs.inotify.max_user_watches=524288
${LIMA_WORKDIR}/bin/lima -- sudo sysctl fs.inotify.max_user_instances=512
