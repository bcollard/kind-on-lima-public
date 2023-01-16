#!/usr/bin/env bash

# for each kind cluster, delete it
for cluster in $(kind get clusters); do
  kind delete cluster --name $cluster
done
