#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root."
    exit 1
fi

BRIDGE="v-net-0"
SUBNET="192.168.15.0/24"

WAN_IF=$(ip route show default | awk '/default/ {print $5; exit}')

echo "[*] Cleaning up all network namespaces and related config..."

# Only delete namespaces with the ns- prefix (created by namespace.sh)
for ns in $(ip netns list | awk '{print $1}' | grep '^ns-'); do
    echo "[-] Deleting namespace: $ns"
    ip netns del "$ns" 2>/dev/null || true
    rm -rf "/etc/netns/$ns"
done

# Remove leftover bridge-side veth interfaces matching our naming convention
for veth in $(ip link show | grep -oP '^\d+: \K[^:@]+' | grep '^ns-.*-br$'); do
    echo "[-] Removing orphan veth: $veth"
    ip link delete "$veth" 2>/dev/null || true
done

# Delete the bridge
echo "[-] Deleting bridge: $BRIDGE"
ip link delete "$BRIDGE" type bridge 2>/dev/null || true

# Remove only the specific iptables rules added by bridge.sh
if [ -n "$WAN_IF" ]; then
    iptables -D FORWARD -i "$BRIDGE" -o "$WAN_IF" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WAN_IF" -o "$BRIDGE" -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s "$SUBNET" -o "$WAN_IF" -j MASQUERADE 2>/dev/null || true
fi

echo "[+] Cleanup complete."
