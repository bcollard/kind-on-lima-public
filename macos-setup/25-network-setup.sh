
# REQS:
# - Kind is running with MetalLB

##########
# Host
##########

# show members of the bridge vnet
ifconfig bridge100

# get IP addr on the lima0 interface
LIMA_IP_ADDR=$(limactl shell ${LIMA_INSTANCE} -- ip -o -4 a s | grep lima0 | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2)
echo $LIMA_IP_ADDR

# add route to the Lima VM
sudo route -nv add -net 172.18 ${LIMA_IP_ADDR}

# check route
route get 172.18.1.1
#traceroute 172.18.1.1

# delete route
#sudo route -nv delete -net 172.18 ${LIMA_IP_ADDR}
