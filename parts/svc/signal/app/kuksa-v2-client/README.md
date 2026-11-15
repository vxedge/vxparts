# svc/signal/app/kuksa-v2-client — `VXE9M-SSIG-APK2`

`kv2`, a test client for the Eclipse Kuksa databroker's `kuksa.val.v2` API. It prints one JSON line
per event on stdout and nothing else, so a check or a campaign step reads its output directly.

## What it is

- `kv2.py` (Apache-2.0) is this part's own code. It calls the generated `kuksa.val.v2` stubs that
  `kuksa-client` 0.6.0 ships. It does not use the SDK's `VSSClient`, whose `get` is `kuksa.val.v1`
  and whose publish and subscribe fall back to v1, so a v1 answer cannot pass for a v2 one.
- Every Python package is pinned by hash (`requirements.txt`, compiled from `requirements.in` with
  `uv pip compile --generate-hashes`), and the `python:3.12-slim` base by digest (`part.yaml`).
- It moved here from vxperiments' exp-015 and exp-017 (`tools/kv2`), where it was the local image
  `localhost/vxperiments/kv2:1`. `kv2.py` is unchanged.

## Run

```
kv2 [--server HOST:PORT] [--connect-s S] COMMAND ...

info                                      the broker's name, version and commit
metadata PATH                             a VSS entry's type, entry type and limits
list [ROOT]                               the entries under ROOT (default Vehicle)
get PATH                                  the current value
publish PATH VALUE [--as TYPE]            set a sensor's value
actuate PATH VALUE [--as TYPE]            ask a provider to set an actuator
subscribe PATHS... [--count N]            one line per update
provide-actuator PATHS... [--mode M]      act as an actuator's provider
provide-signal PATH ...                   act as a signal's provider
```

The default server is `127.0.0.1:55555`. A connection that is not ready within `--connect-s`
prints `{"result": "refused"}`. Every other outcome is `"ok"` or `"error"` with the gRPC status
code, so a caller classifies the output, never the exit code alone.

## Verified 2026-11-16

In one pod with `svc/signal/app/kuksa-databroker:0.2.0` (databroker 0.7.1, `--insecure`), using
the broker's default VSS tree:

- `info` reported databroker 0.7.1;
- `metadata Vehicle.Speed` returned `DATA_TYPE_FLOAT`, `ENTRY_TYPE_SENSOR`;
- `subscribe Vehicle.Speed --count 2` opened, then received the initial empty value and the
  value `publish` set; `get` returned the same 42.5;
- `get Vehicle.Nope` returned `"result": "error"` with `NOT_FOUND`.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/svc/signal/app/kuksa-v2-client 0.1.0
```
