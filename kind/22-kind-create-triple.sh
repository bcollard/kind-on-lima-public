# if there is an arg, use it in a new var named ACCOUNT
if [ -n "$1" ]; then
  ACCOUNT=$1
  time ./kind/20-kind-create.sh 1 $ACCOUNT-global &
  time ./kind/20-kind-create.sh 2 $ACCOUNT-west eu-west-1 &
  time ./kind/20-kind-create.sh 3 $ACCOUNT-east eu-west-2 &
else
  time ./kind/20-kind-create.sh 1 mgmt &
  time ./kind/20-kind-create.sh 2 cluster1 eu-west-1 &
  time ./kind/20-kind-create.sh 3 cluster2 eu-west-2 &  
fi


wait
echo "kind-create-triple target completed!"

