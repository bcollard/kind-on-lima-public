##########
# add route from host to lima
# run on Lima shell
##########

echo "Starting script 35-lima-to-kind-routing.sh"

# # view routes
# ip route
# route

# # view interfaces
# ip link
# ifconfig br-078c5e602e30

# # show net if addresses
# ip -d address
# sudo lshw -class network

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
echo "Variables used in the script, printed in the form a of table:"
echo "Variable | Value"
echo "---------|-----------------------------"
echo "if_prefix | ${if_prefix}"
echo "KIND_IF  | ${KIND_IF}"
echo "HOST_IF  | ${HOST_IF}"
echo "SRC_IP   | ${SRC_IP}"
echo "SRC_IP_F3B | ${SRC_IP_F3B}"
echo "SRC_IP_GW | ${SRC_IP_GW}"
echo "DST_NET  | ${DST_NET}"


echo "showing the route to the Kind network"
ip -o a s dev ${HOST_IF}

# clean
#sudo iptables -t filter -D FORWARD -4 -p tcp -s ${SRC_IP} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF} || true
echo "Cleaning the iptables rules"
sudo iptables -v -t filter -D DOCKER-USER -4 -p tcp -s ${SRC_IP_GW} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF} || true

# add logs
#echo "Adding logging to the iptables rules"
#sudo iptables -v -t filter -I FORWARD 1 -4 -p tcp -s ${SRC_IP_GW} -d ${DST_NET} -j LOG --log-prefix "LIMA-KIND-FORWARD: " --log-level 4
# delete it
#sudo iptables -L FORWARD --line-numbers
#sudo iptables -D FORWARD 3

# add conntrack on the DOCKER-USER chain
# https://docs.docker.com/engine/network/packet-filtering-firewalls/
echo "Adding conntrack to the iptables rules"
sudo iptables -v -t filter -I DOCKER-USER 1 -4 -p tcp -s ${SRC_IP_GW} -d ${DST_NET} -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT


# add iptable
echo "Adding the iptables rules"
sudo iptables -v -t filter -I DOCKER-USER 2 -4 -p tcp -s ${SRC_IP_GW} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF}

echo "Listing the iptables rules"
sudo iptables -S

echo "Script 35-lima-to-kind-routing.sh completed."
