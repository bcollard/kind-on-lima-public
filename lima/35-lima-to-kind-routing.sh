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
KIND_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep "br-")
SRC_IP=192.168.105.1
DST_NET=172.18.0.0/16
HOST_IF=lima0
sudo iptables -t filter -A FORWARD -4 -p tcp -s ${SRC_IP} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF}
sudo iptables -L
