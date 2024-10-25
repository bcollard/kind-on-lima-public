#!/usr/bin/env bash
KIND_HOME_DIR=${HOME}/.kube/kind

# for each kind cluster, delete it
for cluster in $(kind get clusters); do
  echo "Deleting KinD cluster: $cluster"
  kind delete cluster --name $cluster
  kubectl config delete-context $cluster
done
