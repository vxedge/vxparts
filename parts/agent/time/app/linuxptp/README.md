# agent/time/app/linuxptp

linuxptp's `ptp4l` and `pmc`, with linuxptp's IEEE 802.1AS (gPTP) profile. vxedge runs it for an
experiment's `network.time_sync`: the gateway's `ptp4l` is the grandmaster, with one master port per
follower, and each follower device runs one more `ptp4l` that reports its offset from the grandmaster and
the peer delay.

## What it is

- [linuxptp](https://linuxptp.nwtime.org/) 4.2, Debian trixie's `linuxptp` 4.2-1 package, GPL-2.0-or-later.
  The base is `debian:trixie-slim`, pinned by digest.
- `/etc/linuxptp/gPTP.cfg`: linuxptp's own `configs/gPTP.cfg` from that package, with one change:
  `neighborPropDelayThresh` is 100000 ns instead of the standard's 800 ns. Software timestamps on a veth
  put the peer delay close to 800 ns, and at that threshold a follower dropped out after about 16 s. The
  build checks that this is the only change, so a change in upstream's file fails the build.
- Slim Debian images drop `/usr/share/doc`, where the package keeps its example configurations, so the
  profile is written into the image at build time rather than read from the package at run time.
- The entrypoint is `gptp`, a shell script in this part (Apache-2.0).

## What it is not

- Not hardware time-stamping. Every `ptp4l` here runs with software timestamps (`-S`).
- Not clock discipline. A follower runs free (`free_running 1`): containers share the host's clock, so a
  follower measures the time-sync path and does not steer the clock.
- Not a fixed-role in-vehicle profile. The profile keeps best-master election, which the grandmaster wins
  on `priority1`; in-vehicle networks fix the roles instead.
- x86_64 only, for now.

## Run

```
gptp gateway  --uds PATH IFACE...   the grandmaster: one master port per IFACE, priority1 100
gptp follower --uds PATH IFACE      a follower on one port; it runs free and only measures
gptp hold                           wait until stopped, so a privileged runner can start
                                    ptp4l from this image in another network namespace
```

- `PATH` is `ptp4l`'s management socket (`uds_address`), and `PATH.ro` its read-only one. Every `ptp4l`
  on a host needs its own.
- Read a follower's offset with `pmc -u -b 0 -t 1 -s PATH 'GET CURRENT_DATA_SET'` (`offsetFromMaster`)
  and its peer delay with `'GET PORT_DATA_SET'` (`peerMeanPathDelay`). `-t 1` is the profile's
  `transportSpecific`: without it `ptp4l` ignores the request. With the peer-to-peer delay mechanism,
  `CURRENT_DATA_SET`'s `meanPathDelay` stays 0.
- A follower that runs free never locks its servo, so its port stays `UNCALIBRATED` rather than `SLAVE`
  while it follows a grandmaster.
- Both roles open raw sockets on their interfaces, which needs `NET_RAW`.
- The grandmaster wins election with `priority1 100` against the profile's 248.

Every role logs to standard output (`-m`).

`hold` exists because a grandmaster's ports are a bridge's ports, in the network namespace the bridge
lives in. A rootless container cannot open raw sockets there. So vxedge starts the image in `hold` and
runs `gptp gateway` from the image's file system with the privileges the bridge's namespace needs.
Put that
`PATH` in a host directory mounted into the `hold` container: in the container's own file system, a
`ptp4l` running as the host's root cannot create its socket (`bind` fails with `EOVERFLOW`), because root
is not mapped in the container's user namespace.

## Published

`ghcr.io/vxedge/parts/agent/time/app/linuxptp:0.1.0`, `sha256:cc81350e76480ee37237abcc78f42871d97c71ed1cd35e431a02924a521cc94b`.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/agent/time/app/linuxptp 0.1.0
```

Without `VXPARTS_NO_PUSH=1` the script also pushes the image.

## Verified 2026-11-13 (4.2)

- The local build was clean, and all 8 `org.vxedge.*` labels were intact.
- `vxpn.py lint` and `vxpn.py scan` pass, with no part-number collision.
- `gPTP.cfg` in the image differs from upstream's only in `neighborPropDelayThresh`.
- Run by vxedge's `network.time_sync` on a VLAN-aware Linux bridge, with two followers in rootless
  container groups:
  - the grandmaster, started from the `hold` container with `nsenter --mount --pid` in the bridge's
    network namespace, held both followers;
  - over 20 readings a second apart, in three runs, each follower's mean |offset| was 0.37 to 0.94 µs, the
    largest |offset| 1.6 µs, and the mean peer delay 0.9 to 1.5 µs;
  - removing the `hold` container ended the grandmaster.
- Run rootless with `--network host`, `gptp gateway` fails with `socket failed: Operation not permitted`.
- `pmc` without `-t 1` gets no answer. Under the peer-to-peer delay mechanism, `CURRENT_DATA_SET`'s
  `meanPathDelay` stays 0.
