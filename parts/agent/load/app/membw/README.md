# agent/load/app/membw — `VXEN8-ALOD-AA8T`

A memory-bandwidth load: `vxmembw` copies large buffers in a loop and serves the copy rate on
`/metrics`.

## What it is

- `vxmembw` (`vxmembw.py`, Apache-2.0) is this part's own code. Each of `--workers` processes
  copies one buffer of `--buffer-mib` MiB into another in a loop, with numpy's `copyto`.
- A buffer much larger than the last-level cache sends every copy to DRAM, so the workers load
  the memory bus the node shares. Each copied byte is read once and written once.
- numpy 2.5.4 (BSD-3-Clause), pinned by hash in `requirements.txt`, compiled from
  `requirements.in` with `uv pip compile --generate-hashes --exclude-newer 2026-11-06`. The base is
  `python:3.12-slim`, pinned by digest.

## What it is not

- Not a bandwidth benchmark. It is a load: the rate it reaches depends on the host and on
  everything else using the bus.
- It does not pin itself. Pin the container to the CPUs the load should run on.

## Run

```
vxmembw [--workers N] [--buffer-mib M] [--duration-s S] [--metrics-listen ADDR:PORT]
```

| Flag | Meaning | Default |
|---|---|---|
| `--workers` | copy processes | `1` |
| `--buffer-mib` | buffer copied by each worker, in MiB (two buffers of this size per worker) | `64` |
| `--duration-s` | run time. `0` runs until SIGTERM or SIGINT | `0` |
| `--metrics-listen` | the `/metrics` address | `0.0.0.0:9471` |

| Series | Kind | Meaning |
|---|---|---|
| `vxmembw_copied_bytes_total` | counter | bytes copied by all workers |
| `vxmembw_workers` | gauge | `--workers` |
| `vxmembw_buffer_bytes` | gauge | each worker's buffer size |

On exit, `vxmembw` prints one JSON summary to stdout: workers, buffer size, allowed CPUs, run
time, bytes copied and the mean copy rate in GiB/s.

## Published

`ghcr.io/vxedge/parts/agent/load/app/membw:0.1.0`, `sha256:bc7c29f272b200f6a60b967d0617262364a5bf9f2e8ad1ff422215789f5869ab`.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/agent/load/app/membw 0.1.0
```
