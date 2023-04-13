time ./kind/20-kind-create.sh 1 mgmt &
time ./kind/20-kind-create.sh 2 cluster1 &
time ./kind/20-kind-create.sh 3 cluster2 &

wait
echo "kind-create-triple target completed!"

