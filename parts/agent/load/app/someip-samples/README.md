# agent/load/app/someip-samples

COVESA vsomeip and its four example applications. An experiment runs a service side on one node and a
client side on another to put SOME/IP traffic on a vehicle's network: service discovery over UDP
multicast, request and response, and event notification.

## What it is

- [vsomeip](https://github.com/COVESA/vsomeip) 3.8.0 (released 2026-11-03), commit `f1518b3`, built from
  source, MPL-2.0. The build checks the clone against the pinned commit. Upstream's `LICENSE` travels in
  the image under `/opt/vsomeip/`.
- The applications are upstream's own examples: `request-sample`, `response-sample`, `notify-sample` and
  `subscribe-sample`. Their service is `0x1234`, instance `0x5678`.
- The entrypoint is `someip`, a shell script in this part (Apache-2.0). It writes the node's address into
  upstream's UDP sample configuration and starts one example.
- Builder and runtime are `debian:trixie-slim`, pinned by digest. vsomeip needs Boost 1.75 or later and
  C++20.

## What it is not

- Not a meter. The examples print each message; they report no latency or loss. Measure the network
  with `agent/probe/app/vxprobe` while this part loads it.
- Not a vehicle application, and not a model of a specific vehicle's services.
- x86_64 only, for now.

## Run

```
someip response  [ARGS...]   answer requests            (service side)
someip request   [ARGS...]   send requests              (client side; --cycle MS, --tcp, --quiet)
someip notify    [ARGS...]   publish an event           (service side; --cycle MS)
someip subscribe [ARGS...]   subscribe to that event    (client side)
```

| Variable | Meaning | Default |
|---|---|---|
| `SOMEIP_UNICAST` | this node's address | the first address `hostname -I` prints |
| `SOMEIP_NETMASK` | its netmask, used by the client side | `255.255.255.0` |
| `SOMEIP_LOG_LEVEL` | vsomeip log level | `info` |

Two things a node must provide:

- **A multicast route.** vsomeip starts service discovery only when a route covers its multicast group
  (`224.244.224.245`) through the node's interface. A default route does not count. `someip` adds
  `224.0.0.0/4` on that interface, which needs `NET_ADMIN`. If it cannot, it prints a warning and
  discovery does not start.
- **One network namespace per side.** Each side runs its own vsomeip routing manager, so the service
  side and the client side cannot share a network namespace.

`response` offers its service for 10 s and withdraws it for 10 s, in a loop. That is upstream's example
behaviour, so a `request` client sees the service come and go.

## Published

`ghcr.io/vxedge/parts/agent/load/app/someip-samples:0.1.0`, `sha256:9bfc942ecc88d5eee852b6209abc25989b10ed0ae0879973bfe9cf8f06f47d50`.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/agent/load/app/someip-samples 0.1.0
```

Without `VXPARTS_NO_PUSH=1` the script also pushes the image.

## Verified 2026-11-13 (3.8.0)

- The local build was clean, and all 9 `org.vxedge.*` labels were intact.
- `vxpn.py lint` and `vxpn.py scan` pass, with no part-number collision.
- Smoke test under rootless Podman, two containers on one bridge network, each with `NET_ADMIN`:
  - `request --cycle 200` against `response`: the client found the service through service discovery
    and received 46 responses in 9 s;
  - `subscribe` against `notify --cycle 100`: the subscription was accepted and the client received
    133 notifications in 12 s.
- Without `NET_ADMIN` the entrypoint printed its warning, and without a multicast route service
  discovery did not start.
- Not verified yet: a run between two nodes of a vehicle, across a gateway slice.
