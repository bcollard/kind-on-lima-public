#!/usr/bin/env bash

${LIMA_WORKDIR}/bin/limactl start ${LIMA_INSTANCE}

${LIMA_WORKDIR}/bin/lima -- sudo sysctl fs.inotify.max_user_watches=524288
${LIMA_WORKDIR}/bin/lima -- sudo sysctl fs.inotify.max_user_instances=512
