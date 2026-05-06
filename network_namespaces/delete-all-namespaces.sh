#!/bin/bash

set -e

echo "[*] Listing all network namespaces..."
ALL_NS=$(ip netns list | awk '{print $1}' | grep '^ns-')
if [ -z "$ALL_NS" ]; then
    echo "[!] No network namespaces found."
    exit 0
fi
for NS in $ALL_NS; do
    echo "[-] Deleting namespace: $NS"
    ip netns del "$NS" 2>/dev/null || echo "Failed to delete namespace: $NS"
    ip link delete "$NS" 2>/dev/null || true
    ip link delete "${NS}-br" 2>/dev/null || true
    rm -rf /etc/netns/"$NS"
done
echo "[+] All custom namespaces deleted."
