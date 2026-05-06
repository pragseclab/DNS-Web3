# Network Namespace Setup

Scripts for creating isolated Linux network namespaces, each with full outbound internet access via a shared bridge. Useful for running applications in network isolation while capturing their network/DNS traffic.

Each namespace gets its own network stack (interfaces, routing table, DNS config) and communicates with the internet through NAT on the host's default interface. Applications inside can make outbound connections normally and receive responses, but are not reachable from the internet.

## Requirements

- Linux (kernel 3.8+)
- `iproute2` (`ip`, `ip netns`)
- `iptables`
- Root access

## Scripts

| Script | Purpose |
|--------|---------|
| `bridge.sh` | Creates the shared bridge and NAT rules. Run once before creating any namespaces. |
| `namespace.sh <name>` | Creates a single namespace connected to the bridge. |
| `delete-namespace.sh <name>` | Tears down a single namespace and its config. |
| `delete-all-namespaces.sh` | Tears down all `ns-*` namespaces. |
| `cleanup.sh` | Full teardown — removes all namespaces, the bridge, and the iptables rules. |

## Usage

**1. Set up the bridge (once per session):**

```bash
sudo ./bridge.sh
```

**2. Create a namespace:**

```bash
sudo ./namespace.sh ns-myapp
```

The namespace gets a random IP in `192.168.15.10–254`. DNS is set to `8.8.8.8`. The script confirms internet connectivity before exiting.

**3. Run something inside the namespace:**

```bash
sudo ip netns exec ns-myapp <command>
```

For example, to capture DNS traffic while running an app:

```bash
sudo ip netns exec ns-myapp tcpdump -l -n udp port 53 -i any &
sudo ip netns exec ns-myapp ./myapp
```

**4. Tear down when done:**

Remove a single namespace:
```bash
sudo ./delete-namespace.sh ns-myapp
```

Remove all namespaces (keeps the bridge):
```bash
sudo ./delete-all-namespaces.sh
```

Full teardown including bridge and iptables rules:
```bash
sudo ./cleanup.sh
```

## Network Layout

```
[namespace: ns-myapp]        [host]                  [internet]
 192.168.15.x        <-->  bridge v-net-0         <-->  WAN
 (veth: ns-myapp)          (192.168.15.5/24)           (MASQUERADE)
                            (veth: ns-myapp-br)
```

The bridge IP (`192.168.15.5`) is also reachable from the host, so you can connect to any port the namespaced app is listening on from the host machine.

## Notes

- `bridge.sh` auto-detects your default WAN interface via `ip route`. If you have multiple interfaces and the wrong one is picked, verify with `ip route show default`.
- The `192.168.15.0/24` subnet is hardcoded. If it conflicts with your existing network, change `BRIDGE_IP` and `SUBNET` at the top of `bridge.sh` and `cleanup.sh`, and `NS_IP`/gateway in `namespace.sh`.
- `cleanup.sh` only removes `ns-*` namespaces and the specific iptables rules added by `bridge.sh`. It does not touch unrelated namespaces or iptables rules on your system.
