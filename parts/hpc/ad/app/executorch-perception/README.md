# hpc/ad/app/executorch-perception — `VXETT-HADS-AXJ1`

ExecuTorch inference on the CPU, at a fixed frame rate, with `vxet`, a tool that serves each
frame's inference latency and deadline misses on `/metrics`.

## What it is

- [ExecuTorch](https://github.com/pytorch/executorch) 1.6.0, commit `4776f71`, BSD-3-Clause, with
  its XNNPACK backend. It comes with PyTorch 2.15.0 and torchvision 0.29.2 from their published
  CPU wheels. Every Python package is pinned by hash in `requirements.txt`, compiled from
  `requirements.in` with `uv pip compile --generate-hashes --exclude-newer 2026-11-06`.
- Two programs, exported at build time by `export.py` (this part's own code, Apache-2.0):

  | Model | Input | File | sha256 |
  |---|---|---|---|
  | torchvision `mobilenet_v2` | 1×3×224×224, fp32 | `/models/mobilenet_v2.pte` | `42f58fd97b8b828f6705a0f91cf20f2be3eed0911c9c11b519ab14a1dcc89660` |
  | torchvision `resnet18` | 1×3×224×224, fp32 | `/models/resnet18.pte` | `145038889893e41dd1d5b3bf59b9eedb2517c024b6ad8c3328cb513cb8f61a4f` |

  - The weights are random (seed 0), not trained. Inference cost depends on the graph and the
    input shape, not on the weight values, and no pretrained weights are downloaded.
  - Every operator is lowered to XNNPACK. `export.py` fails the build if one falls back to
    ExecuTorch's portable kernels.
  - The export is deterministic, and the build checks both files against the sha256 above.
- `vxet` (`vxet.py`, Apache-2.0) is this part's own code. It runs one program at a fixed frame
  rate:
  - Frame *k* is released at start + *k*/rate and is due one period later.
  - A frame that finishes after its due time is a deadline miss.
  - Releases that pass while a frame is still running are dropped, as by a camera with a
    one-frame buffer. Each one counts as a frame and a miss.
  - With `--rate-hz 0`, frames run back to back, with no deadline.
- The base is `python:3.12-slim`, pinned by digest. The image sets `OMP_NUM_THREADS=1`: inference
  runs on ExecuTorch's XNNPACK pool, and torch's own OpenMP pool would otherwise start one idle
  thread per CPU.

## What it is not

- Not a trained perception function: the outputs are meaningless by design.
- Not a statement about a production SoC, an NPU or a quantised model. It measures fp32 XNNPACK on
  the CPUs the container is given.
- x86_64 only, for now.

## Run

```
vxet --model {mobilenet_v2,resnet18} [--rate-hz N] [--threads T] [--duration-s S]
     [--warmup-s W] [--metrics-listen ADDR:PORT]
```

| Flag | Meaning | Default |
|---|---|---|
| `--model` | the program to run | required |
| `--rate-hz` | frame rate; the deadline is one period. `0` runs back to back | `30` |
| `--threads` | XNNPACK threads. `0` keeps ExecuTorch's default: one per CPU the process may use | `0` |
| `--duration-s` | measured time. `0` runs until SIGTERM or SIGINT | `0` |
| `--warmup-s` | frames run first and not counted | `5` |
| `--metrics-listen` | the `/metrics` address | `0.0.0.0:9470` |

The default thread count follows the CPU affinity mask, so pinning the container (for example
`taskset -c 8-11 podman run …`) also sizes the pool.

Metrics, each labelled `model="<name>"`. Frames run during warm-up are not counted:

| Series | Kind | Meaning |
|---|---|---|
| `vxexecutorch_inference_seconds{quantile="0.5"\|"0.9"\|"0.99"\|"0.999"}` | summary | latency of `execute()`, over the whole run |
| `vxexecutorch_inference_seconds_max`, `_mean`, `_stddev` | gauge | the same distribution |
| `vxexecutorch_frames_total` | counter | frames released |
| `vxexecutorch_deadline_misses_total` | counter | frames not finished by their due time, dropped ones included |
| `vxexecutorch_period_seconds` | gauge | the configured period, `0` back to back |
| `vxexecutorch_threads` | gauge | the XNNPACK thread count |

Latencies are kept in a log-linear histogram with under 0.1 % relative error, as vxprobe keeps
round trips. The quantile lines appear after the first counted frame.

On exit, `vxet` prints one JSON summary to stdout: frames, misses, latency quantiles in
microseconds, the thread and allowed CPU counts, the ExecuTorch version and commit, and the
program's sha256.

## Published

`ghcr.io/vxedge/parts/hpc/ad/app/executorch-perception:0.1.0`, `sha256:ab1ff2797076cc2b339b14492094c821affe73b9459acf4f8fa43a64e11e6f9d`.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/hpc/ad/app/executorch-perception 0.1.0
```

The build installs about 1.5 GB of Python packages, exports both programs and runs `vxet` for
one second.
