# TASKS.md — vxedge/vxparts

This repo is the unified loadable registry, created 2026-07-26 to replace the `vxzones`
(zone VM images) / `vxcompute` (compute containers) split — see `docs/TASKS.md` Track P for
the program-level rationale and Track D for the four-dimension digital-twin model this repo's
`parts:` list feeds into. Not a GitHub rename: `vxzones` and `vxcompute` remain in place until
their content migrates here, at which point both are archived (not deleted).

**Stakes, as of 2026-07-26 (zero code in this repo):** phase 2's gate (`docs/TASKS.md`) is
half-passed — H2 (vlan vs s-nssai) HOLDS (2026-07-18) — but the other half, real ADAS traffic
(`exp-011`, CARLA → ROS2 → Autoware, `vxperiments/TASKS.md`), is blocked on this repo landing
its first parts (`hpc/ad`, `hpc/sim`). Track M's M4 (`vxmodels/TASKS.md`) is blocked
transitively on the same thing.

## Migration (do first — everything else assumes this landed)

- [x] Repo scaffolding (2026-07-26): `README.md`, `AGENTS.md`, `CHANGELOG.md`, this file.
- [x] `parts/{zone,hpc,gw,agent,svc}/` directory skeleton + `scripts/publish/` (2026-07-26)
- [x] Copy the `linux-probe` guest bundle recipe into
      `parts/zone/linux/stack/probe-bundle/build.sh` (2026-07-26), adapted to stamp
      `org.vxedge.*` classification fields into `meta.json`; `.gitignore`'d `bundle/` output
      dir matches `vxzones`' own `images/*/bundle/` convention (host-generated, not committed)
- [x] `oras` CLI v1.3.3 installed (2026-07-26, `~/.local/bin/oras`, checksum-verified from
      the upstream release; no sudo — `~/.local/bin` is already on PATH)
- [x] `scripts/publish/publish-vm-bundle.sh` validated against a **local** `registry:2`
      (2026-07-26): push + pull round-trip byte-identical for `vmlinuz`/`initrd.img`/
      `meta.json`; `artifactType: application/vnd.vxedge.part.v1`; all six `org.vxedge.*`
      keys land as manifest annotations; `oras repo ls` / `repo tags` enumerate the part by
      its class/subtype/layer path — i.e. the registry-is-the-catalogue claim demonstrably
      works without a catalog file
- [x] **End-to-end proven with the real kernel (2026-07-26)**: built → pushed → pulled fresh
      from the registry → **booted the pulled artifact** under `qemu-microvm` (kernel → `/init`
      → `vx.ip=` cmdline applied to eth0 → `vxprobe` reflector listening on :9800, ~2.0s to
      payload). This is the first time a vxedge loadable has round-tripped through a registry
      and booted from the pulled copy.
- [x] **Made the initramfs build byte-reproducible (2026-07-26).** Found while checking
      migration equivalence: the inherited recipe produced a *different* `initrd.img` sha256
      on every run — same script, same host, same inputs — because cpio embeds per-file mtimes
      and gzip embeds a build timestamp. The digests recorded in `meta.json` therefore
      identified a particular build, not its inputs, which quietly undercuts §13's
      digest-based reproducibility rule (and the whole premise of digest-addressed parts).
      Fixed with `SOURCE_DATE_EPOCH`-pinned mtimes + sorted member order + `cpio
      --reproducible` + `gzip -n`; two consecutive builds now produce an identical digest, and
      the result still boots.
  - [ ] **Same bug is still live in `vxzones/scripts/build-guest-bundle.sh`** — port the fix
        there too, or land it as part of the cutover. Any H3 digest on record from that script
        is not rebuildable to the same hash.
  - [ ] Audit whether other artifact kinds (container builds, future QNX/AAOS bundles) have
        the same non-reproducibility, before they get digest-pinned in manifests
- [x] Migration equivalence to the `vxzones` bundle **established by content, not by hash**
      (bit-for-bit was never achievable — see reproducibility item above): identical file
      trees/permissions/symlinks, byte-identical `busybox` and `vxprobe`, identical `vmlinuz`
      digest; the only diff is two cosmetic strings (`vxzones` → `vxparts` in an `/init`
      comment and its console line). Confirmed nothing in any repo greps that console line.
  - [ ] **Real publish to `ghcr.io/vxedge/parts/...` still not done** — validated only against
        a local `registry:2`. Needs an explicit go-ahead, since it publishes into the org
        namespace and would be the project's first public artifact.
  - [ ] **Cutover not done yet, and not safe to do casually**: `vxzones/scripts/build-guest-bundle.sh`
        is still the live recipe backing `exp-002`/`exp-002b` (`vxperiments/experiments/exp-002*.yaml`,
        `vxperiments/scripts/run-exp-002*.sh` all reference `vxzones/images/linux-probe/bundle`
        directly) — the H3 numbers on record were measured against that path. Repointing those
        manifests/scripts at a `vxparts`-published artifact is a separate step requiring
        re-validation that the bundle is bit-for-bit equivalent (or a documented, justified
        diff) before H3 numbers are trusted post-move. Until that lands, treat the `vxzones`
        copy as the one still in use and the `vxparts` copy as the new canonical *source* for
        anything net-new.
- [ ] Migrate `vxzones`'s zone manifests into `parts/zone/...`
- [ ] Migrate `vxcompute`'s docs-only backlog (below) into this board
- [ ] Once both migrations land: archive `vxzones` and `vxcompute` on GitHub (not delete);
      update workspace root `CLAUDE.md` repo table, `docs/ARCHITECTURE.md`, every other repo's
      `AGENTS.md` naming `vxzones`/`vxcompute`, and `docs/TASKS.md` Track P

## Part numbering (see `PART-NUMBERING.md`)

- [x] VXPN scheme + `scripts/vxpn.py` (2026-07-26): ARINC-665-shaped `MMMCC-SSSS-SSSS`
      (`VXE7G-ZLNX-SHAE`), **computed from** the part's class/subtype/layer/name rather than
      mapped to it — no side table, preserving the same single-source-of-truth rule that ruled
      out `catalog.yaml`. `encode`/`encode-path`/`verify`/`decode`/`scan`. Check characters
      measured at 100% detection for single-char substitutions and adjacent transpositions.
      Stamped into `meta.json` as `org.vxedge.pn`, so it rides to the registry as an annotation.
- [ ] `vxpn.py scan` as a CI merge gate — the 3-char name digest holds ~46.6k values, so
      collisions get likely past a couple hundred parts; widen before that, not after
- [ ] `org.vxedge.rxswin` (UN R156 / ISO 24089) at vehicle-manifest level — gated on Track D
      dimension 3's `vxedge manifest bom`; an RxSWIN describes a *set* of parts, never one part
- [ ] Supplier-code registry for third-party `MMM` values — only needed once a part arrives
      from outside the project

## Registry & classification (design, mostly decided — see `AGENTS.md`)

- [ ] `parts/<class>/<subtype>/<layer>/<name>/` directory layout (build recipe + README only,
      no composition data)
- [ ] `scripts/publish/publish-container.sh` — docker/podman push for `hpc`/`gw`-class parts,
      stamping `org.vxedge.class/subtype/layer/backend/arch/license` annotations
- [ ] `scripts/publish/publish-vm-bundle.sh` — ORAS push for `zone`-class VM/kernel/QNX
      IFS/AAOS system images, same annotation set
- [ ] Composite-part convention: OCI image index for a full loaded stack (e.g.
      `parts/zone/qnx/stack/safety-baseline:2.1.0` indexing its os+middleware+config parts as
      one pullable unit) — document the `oras manifest push --index` (or `docker buildx
      imagetools create`) step
- [ ] Decide publish-tooling shape: thin wrapper CLI (`vxpart`?) vs. documented
      `oras`/`docker` invocations + a script-per-kind — default to the latter until the
      number of artifact kinds/repeated steps justifies a real binary
- [ ] CI: path-filtered build+publish workflow (`parts/zone/**` → VM/kernel bundle build,
      `parts/hpc/**`/`parts/gw/**` → container build) — two genuinely different toolchains
      (QEMU/kernel assembly vs. Docker+CUDA), kept as separate jobs sharing one workflow

## `zone`-class parts (from `vxzones`)

- [ ] Zone manifests for the six roles (schema §6.1), initially with placeholder nodes
- [ ] `parts/zone/zephyr/os/` microVM image: virtio-net, boots <1s, runs a UDP echo/probe
      payload
- [ ] `parts/zone/freertos/os/`: same contract
- [ ] `parts/zone/qnx/os/` — QNX SDP 8 guest recipe (x86-64 QEMU): fetch/build instructions,
      virtio drivers, probe payload; document the QNX-hypervisor-inversion caveat in the
      recipe README (never commit QNX binaries — recipe + fetch instructions only)
- [ ] `parts/zone/aaos/os/` — AAOS emulator image for `rear-left`/`rear-right` infotainment
      nodes (virtio-gpu; GPU passthrough variant documented)
- [ ] `parts/zone/linux/app/` sensor-node image variant emitting camera/lidar-shaped traffic
      (pre-CARLA synthetic)
- [ ] Digest tooling: build → sha256 tag → publish (per-`meta.json` digests exist for
      linux-probe already — generalize per-part)

## `hpc`-class parts (from `vxcompute`, re-scoped 2026-07-26)

**GPU-constraint direction, decided 2026-07-20 in `vxcompute`, carried forward:** the
documented Tier 2 GPU minimum (`docs/TESTBED-SETUP.md`: RTX-class, ≥12GB VRAM) may be tight
once CARLA + Autoware/ROS2 + DeepStream/TensorRT run concurrently. The fix is **more GPU**, not
lowering CARLA's rendering/sensor quality — fidelity isn't the thing to trade away. Design
defaults: off-screen Vulkan rendering, GPU shared only between CARLA and inference (no MIG on
consumer RTX cards), synchronous fixed-tick CARLA mode, H2's host-confound controls (cpu
governor pinning, cpu affinity, randomized load order).

- [ ] `parts/hpc/ad/middleware/` — Autoware/ROS2: pinned distro, digest-tagged; consumes
      carla-ros-bridge topics
- [ ] `parts/hpc/sim/app/` — CARLA server + carla-ros-bridge wiring (`source: carla` traffic
      profiles)
- [ ] Closed loop: vehicle control (steer/throttle/brake) published back into CARLA via
      carla-ros-bridge — enables the control-loop latency metric (§12)
- [ ] CARLO-based CI smoke test for the carla-ros-bridge topic contract — CARLO
      (https://github.com/Stanford-ILIAD/CARLO, lightweight 2D CARLA reimplementation) runs
      GPU-free, validating the ROS2 topic contract/actuation-return wiring on ordinary CI
      runners ahead of/alongside the real CARLA integration. **Non-goal: does not replace
      CARLA for any measured experiment** (`ros2-dds-patterns` skill's reproducibility rule)
- [ ] `parts/hpc/ad/app/` — DeepStream/TensorRT perception pipeline (camera-stream inference).
      Candidate complementary input, flagged not decided: Nexar Dashcam Crashes dataset
      (huggingface.co/datasets/nexar-ai/nexar_collision_prediction) as real-video input
      alongside CARLA-synthetic footage. **Open schema question, not resolved here**:
      `traffic_profiles.source` today is `<vxid:nodeid> | 'internet' | 'carla'`
      (`ARCHITECTURE.md` §6.1) — a dataset-replay source needs a new enum value
      (`source: replay` + dataset/path field); per `docs/AGENTS.md`'s propagation rule this is
      an `ARCHITECTURE.md`-first decision, likely needing explicit owner sign-off — do not add
      unilaterally ahead of that
- [ ] GPU pass-through validation: `resources.gpu: passthrough` end-to-end under vxedged
- [ ] `parts/hpc/ad/app/` — Alpamayo-R1 / AlpaSim workload container (second AD stack
      stressing the ADAS slice). Follow-on, gated behind this landing: ASIMOV dataset
      (asimov-benchmark.github.io/v1) as a semantic-safety eval input once running — direct
      fit for Track M's M4 fidelity ledger (`vxmodels/TASKS.md` M4)
- [ ] `parts/hpc/ad/middleware/` variant — rmw_zenoh transport option across zone↔compute
      ROS2 graph
- [ ] Ankaios/BlueChi orchestration option — **not a `hpc` part**; tracked under Track D
      dimension 4 (orchestration & management plane), `docs/TASKS.md`
- [ ] ARM64 container builds (Jetson; Graviton / Snapdragon vSoC cloud parity)
- [ ] GenieX runtime for the Snapdragon vSoC parity build, flagged not decided: Qualcomm
      GenieX (github.com/qualcomm/GenieX) as inference runtime for a small VLM (SmolVLM
      family), scoped to scene/hazard-captioning on the Snapdragon-target build only (e.g.
      paired with the Nexar dashcam dataset above). **Not a DeepStream/TensorRT
      replacement.** Promoting to a named ADAS-slice workload needs an `ARCHITECTURE.md` §10
      change first — not decided here
- [ ] MIG-slice GPU sharing variant (`resources.gpu: mig-slice`)

## `gw`-class parts

- [ ] `parts/gw/tcu/app/` — TCU-role gateway image (uplink into vxgateway)
- [ ] `parts/gw/nos/` — SONiC-VS-adjacent NOS twin packaging, if/when it moves from
      infrastructure config to a published part

## Phase 3 (from `vxzones`, unclassified pending schema)

- [ ] Kuksa client / VSS signal emitters in zone guests (vehicle manifest support)
- [ ] CAN-capable guest variants: QEMU CAN controller / SocketCAN in guests, emitting
      realistic sensor frames onto `type: can` links
- [ ] RSU node image (`type: rsu`): V2I endpoint sourcing/sinking ETSI ITS-style messages
- [ ] Restbus node images: DBC-driven CAN sensor/actuator emitters (per manifest
      `sensors:`/`actuators:` blocks)
- [ ] Renode firmware targets: Zephyr/FreeRTOS builds runnable under `backend: renode`
      (register-level GPIO/ADC/CAN peripherals)

## Phase 4 (optional)

- [ ] Zone images validated on physical Jetson / DRIVE AGX hardware; physical Jetson AGX
      validation for `hpc`-class parts

## Downstream dependency

- [ ] Once `ARCHITECTURE.md` §6 gains the `parts:` list field (Track D dimension 1, gated on
      explicit owner sign-off): update every zone/compute manifest example (§16) and every
      `vxperiments` manifest to reference real `vxparts` paths instead of placeholder `image:`
      strings

Full program-level summary: `docs/TASKS.md` Track P.
