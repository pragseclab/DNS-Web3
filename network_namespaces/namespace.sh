#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <namespace-name>"
    exit 1
fi

NS_NAME="$1"
VETH="$NS_NAME"
VETH_BR="${NS_NAME}-br"
BRIDGE="v-net-0"

ip netns del "$NS_NAME" 2>/dev/null || true
ip link delete "$VETH" 2>/dev/null || true
ip link delete "$VETH_BR" 2>/dev/null || true

ip netns add "$NS_NAME"

ip link add "$VETH" type veth peer name "$VETH_BR"
ip link set "$VETH" netns "$NS_NAME"
ip link set "$VETH_BR" master "$BRIDGE"
ip link set "$VETH_BR" up

OCTET=$(shuf -i 10-254 -n 1)
NS_IP="192.168.15.$OCTET"
ip -n "$NS_NAME" addr add "$NS_IP"/24 dev "$VETH"
ip -n "$NS_NAME" link set "$VETH" up
ip -n "$NS_NAME" route add default via 192.168.15.5

ip netns exec "$NS_NAME" ip link set lo up
ip netns exec "$NS_NAME" sysctl -w net.ipv6.conf.lo.disable_ipv6=0
ip netns exec "$NS_NAME" sysctl -w net.ipv6.conf.all.disable_ipv6=0
if ! ip netns exec "$NS_NAME" ip -6 addr show dev lo | grep -q "::1/128"; then
    ip netns exec "$NS_NAME" ip -6 addr add ::1/128 dev lo
fi

mkdir -p /etc/netns/"$NS_NAME"
echo "nameserver 8.8.8.8" > /etc/netns/"$NS_NAME"/resolv.conf

echo "$NS_NAME" > /etc/netns/"$NS_NAME"/hostname
cat <<EOF > /etc/netns/"$NS_NAME"/hosts
127.0.0.1       localhost
$NS_IP          $NS_NAME
EOF

if ip netns exec "$NS_NAME" ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
    echo "[+] Internet connection established for $NS_NAME"
else
    echo "[!] Warning: no internet connectivity in $NS_NAME — check bridge setup"
fi
