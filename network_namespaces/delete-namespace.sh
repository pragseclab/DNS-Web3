#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <namespace-name>"
    exit 1
fi

NS_NAME="$1"
VETH="$NS_NAME"
VETH_BR="${NS_NAME}-br"
echo "[*] Deleting network namespace: $NS_NAME"
ip netns del "$NS_NAME" 2>/dev/null || echo "Namespace $NS_NAME does not exist"
ip link delete "$VETH" 2>/dev/null || echo "No veth interface $VETH found"
ip link delete "$VETH_BR" 2>/dev/null || echo "No bridge veth $VETH_BR found"
rm -rf /etc/netns/"$NS_NAME"
echo "[+] Cleanup complete for namespace: $NS_NAME"