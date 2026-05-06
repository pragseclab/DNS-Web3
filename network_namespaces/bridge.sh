#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root."
    exit 1
fi

BRIDGE="v-net-0"
BRIDGE_IP="192.168.15.5/24"
SUBNET="192.168.15.0/24"

WAN_IF=$(ip route show default | awk '/default/ {print $5; exit}')
if [ -z "$WAN_IF" ]; then
    echo "[!] Could not detect a default network interface. Check 'ip route show default'."
    exit 1
fi

echo "[*] WAN interface: $WAN_IF"

# Remove bridge and any previously added rules cleanly before recreating
ip link delete "$BRIDGE" 2>/dev/null || true
iptables -D FORWARD -i "$BRIDGE" -o "$WAN_IF" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$WAN_IF" -o "$BRIDGE" -j ACCEPT 2>/dev/null || true
iptables -t nat -D POSTROUTING -s "$SUBNET" -o "$WAN_IF" -j MASQUERADE 2>/dev/null || true

sysctl -w net.ipv4.ip_forward=1 > /dev/null

ip link add "$BRIDGE" type bridge
ip addr add "$BRIDGE_IP" dev "$BRIDGE"
ip link set "$BRIDGE" up

iptables -t nat -A POSTROUTING -s "$SUBNET" -o "$WAN_IF" -j MASQUERADE
iptables -A FORWARD -i "$BRIDGE" -o "$WAN_IF" -j ACCEPT
iptables -A FORWARD -i "$WAN_IF" -o "$BRIDGE" -j ACCEPT
iptables -P FORWARD ACCEPT

echo "[+] Bridge '$BRIDGE' is up on $BRIDGE_IP (WAN: $WAN_IF)"