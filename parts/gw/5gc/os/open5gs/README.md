# parts/gw/5gc/os/open5gs

The Open5GS 5G core (`docs/ROADMAP.md` priority-1 buildout item, 2026-08-05: "already running,
already producing H2's real numbers via local podman, just never wrapped"). This part is that
wrap — same content as `vxedge/containers/fiveg/Containerfile.open5gs`, re-homed under
`vxparts`' class/subtype/layer structure so it's a real, publishable, digest-pinned loadable
instead of a bare `podman build` step inside the `vxedge` repo.

Classification: `class=gw`, `subtype=5gc`, `layer=os` (taxonomy's own description of `os`:
"guest operating system **or base container image**" — this is the container case, same as
`gw/nos/os/sonic-vs`).

## Not a relabeled upstream image

Unlike `hpc/ad/middleware/ros2-humble` (a thin relabel of an official OCI image), Open5GS has
no official container image this project validated against — it installs via the
`ppa:open5gs/latest` Ubuntu PPA, confirmed 2026-08-05 (same non-OCI-upstream honesty
`gw/nos/os/sonic-vs`'s README already applies to its own Azure-Pipelines source). `upstream.ref`/
`digest` in `part.yaml` pin the actual `FROM` base
(`docker.io/library/ubuntu:24.04@sha256:561618e2...`, resolved 2026-08-05) — the value
`publish-container.sh`'s `--build-arg UPSTREAM=<ref>@<digest>` mechanism injects. The Open5GS
package version target (`2.8.0`, matching what `vxedge-core::fiveg`'s renderer is validated
against — `crates/vxedge-core/src/fiveg/mod.rs:9`) lives in `annotations.open5gs-version`, not
in `upstream`, because a PPA install isn't byte-reproducible the way a digest-pinned image pull
is: apt always resolves "whatever's current in the PPA today." That's a real, known limitation,
not glossed over — re-pin `open5gs-version` deliberately (and note in this file) if a PPA
update is ever suspected of changing NF behavior underneath a frozen experiment result.

## License

**AGPL-3.0** (confirmed via the upstream `open5gs/open5gs` repo's own SPDX metadata,
2026-08-05) — this is one of the two cases `docs/ROADMAP.md`'s workspace-licensing-review item
flags explicitly as "the one[s] to check carefully against any linking/service story." This
part runs Open5GS as a standalone containerized service (no vxedge code links against it), the
normal AGPL network-service deployment shape — but the final call on redistribution terms for
a *built* image belongs to whoever owns that review, not assumed settled here.

## Build

```
../../../../../scripts/publish/publish-container.sh gw/5gc/os/open5gs 0.1.0
# or, for a local build without publishing:
VXPARTS_NO_PUSH=1 ../../../../../scripts/publish/publish-container.sh gw/5gc/os/open5gs 0.1.0
```

## Deploying (unchanged from `vxedge/containers/fiveg`)

This image only replaces `vx5g-core`'s *build* path — the pod-orchestration mechanics it runs
under are unchanged and still live in `vxedge/containers/fiveg/pod-up.sh` (mongo → nrf →
{ausf,udm,udr,pcf,bsf,nssf} → amf → per-slice smf/upf, one container per NF, each running
`open5gs-<nf>d -c /etc/vx5g/<nf>.yaml` against a vxedge-rendered config bind-mount). Repointing
`pod-up.sh` at this part's published tag instead of the locally-built `vx5g-core` image is a
deliberate, separate follow-up (mirrors the `exp-002`/`probe-bundle` cutover pattern) — not
done in the same change that authors this part, so H2's currently-passing result isn't put at
risk by an unproven swap.

## Verified 2026-08-05

`VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/gw/5gc/os/open5gs 0.1.0` built
clean; all 10 `org.vxedge.*` labels confirmed intact via `podman image inspect` (the script's
own round-trip check). Ran the built image with no arguments and confirmed every expected NF
binary is present and executable: `open5gs-amfd`, `-ausfd`, `-bsfd`, `-hssd`, `-mmed`, `-nrfd`,
`-nssfd`, `-pcfd`, `-pcrfd`, `-scpd`, `-seppd`, `-sgwcd`, `-sgwud`, `-smfd`, `-udmd`, `-udrd`,
`-upfd` — the full Open5GS NF set. `vxpn.py lint`/`scan` both pass with no collisions (16 parts
total in the catalogue after this landing). Not yet re-verified against a live pod run under
`pod-up.sh` with this image swapped in for `vx5g-core` — that's the deploy-cutover step
described above, deliberately out of scope for this pass.
