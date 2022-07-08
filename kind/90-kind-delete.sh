#!/usr/bin/env bash
export KIND_ON_LIMA_DIR=${LIMA_WORKDIR}

if [ -z "$1" ]; then
  echo "Usage: $0 <KinD cluster name>"
  exit 1
fi

kind delete cluster --name $1