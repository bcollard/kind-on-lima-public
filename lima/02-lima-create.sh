#!/usr/bin/env bash

echo "Using limactl version: "
${LIMACTL_BIN} --version

arch=$(uname -m)
macosversion=$(sw_vers -productVersion)

if [ $arch == "arm64" ]; then
    if [ $LIMA_INSTANCE == "vz" ]; then
        if  [[ $macosversion < 13 ]]; then
            echo "Rosetta is not supported on arm64 on macOS 12 or earlier"
            exit 1
        fi
    else
        #enable containerd on arm64 for supporting x86 based images
        sed -i'.bak'  "s+user: false+user: true+g" ./lima/docker.yaml
    fi
    
fi

# limactl start ./03-docker.yaml
${LIMACTL_BIN} start ./lima/${LIMA_INSTANCE}.yaml --tty=false --name ${LIMA_INSTANCE} --log-level=debug

if [ $arch == "arm64" ] && [ $LIMA_INSTANCE == "docker" ]; then
    ${LIMA_BIN} sudo nerdctl run --privileged --rm tonistiigi/binfmt --install all
fi

${LIMA_BIN} -- sudo sysctl fs.inotify.max_user_watches=524288
${LIMA_BIN} -- sudo sysctl fs.inotify.max_user_instances=512
