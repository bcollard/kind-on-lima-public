#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Usage: $0 <KinD cluster name>"
  exit 1
fi

# test if $1 is a valid kind cluster
if ! kind get clusters | grep -q $1; then
  echo "ERROR: $1 is not a valid KinD cluster"
  exit 1
fi

kind delete cluster --name $1
kubectl config delete-context $1