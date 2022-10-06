#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Usage: $0 <KinD cluster name>"
  exit 1
fi

kind delete cluster --name $1