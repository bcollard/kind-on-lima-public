#!/usr/bin/env bash

${LIMACTL_BIN} start ${LIMA_INSTANCE} --log-level=debug

${LIMA_BIN} -- sudo sysctl fs.inotify.max_user_watches=524288
${LIMA_BIN} -- sudo sysctl fs.inotify.max_user_instances=512
