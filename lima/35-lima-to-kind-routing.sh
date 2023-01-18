##########
# add route from host to lima
# run on Lima shell
##########

# # view routes
# ip route
# route

# # view interfaces
# ip link
# ifconfig br-078c5e602e30

# # show net if addresses
# ip -d address

# # get IP addr on the lima0 interface
# ip -o -4 a s | grep lima0 | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2

# # show arp cache
# arp

# # tcpdump
# sudo tcpdump -n -A -s 1024 -i lima1 "src host 192.168.105.1"

# # check ip forward is enabled
# cat /proc/sys/net/ipv4/ip_forward

# ip forward from Host to KinD
if_prefix=$(docker network inspect kind --format '{{.Id}}'  | cut --characters -5)
KIND_IF=$(ip link show | grep $if_prefix | head -n1 | cut -d ':' -f2 | tr -d " ")
HOST_IF=lima0
SRC_IP=$(ip -o -4 a s | grep ${HOST_IF} | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2)
SRC_IP_F3B=$(ip -o -4 a s | grep ${HOST_IF} | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2 | cut -d'.' -f1-3)
SRC_IP_GW=${SRC_IP_F3B}.1
DST_NET=172.18.0.0/16

sudo iptables -t filter -A FORWARD -4 -p tcp -s ${SRC_IP} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF}
sudo iptables -t filter -A FORWARD -4 -p tcp -s ${SRC_IP_GW} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF}
sudo iptables -L

# remove ip forward from Host to KinD
# sudo iptables -t filter -D FORWARD -4 -p tcp -s ${SRC_IP} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF}

# get the first three bytes of the IP address
