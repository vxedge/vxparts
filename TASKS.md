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
  - [x] **First real publish to GHCR (2026-07-28)**:
        `ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle:0.1.0`,
        `sha256:33c9c8d8625bd5c6d1f4d3d0c561fdaa930e057fcd1fb24fb3badb402f25429d`. Push +
        pull round-trip byte-identical for all three files; `artifactType:
        application/vnd.vxedge.part.v1` and all seven `org.vxedge.*` annotations (including
        `pn=VXE7G-ZLNX-SHAE`) survive GHCR's manifest storage unchanged; `oras repo tags`
        enumerates it — the registry-is-the-catalogue claim now holds against a real
        registry, not just a local `registry:2`. Package **visibility: private**, consistent
        with going-public being deferred; publishing it is a separate deliberate step.
  - [ ] **Cutover not done yet, and not safe to do casually**: `vxzones/scripts/build-guest-bundle.sh`
        is still the live recipe backing `exp-002`/`exp-002b` (`vxperiments/experiments/exp-002*.yaml`,
        `vxperiments/scripts/run-exp-002*.sh` all reference `vxzones/images/linux-probe/bundle`
        directly) — the H3 numbers on record were measured against that path. Repointing those
        manifests/scripts at a `vxparts`-published artifact is a separate step requiring
        re-validation that the bundle is bit-for-bit equivalent (or a documented, justified
        diff) before H3 numbers are trusted post-move. Until that lands, treat the `vxzones`
        copy as the one still in use and the `vxparts` copy as the new canonical *source* for
        anything net-new.
- [x] Migrate `vxzones`'s zone manifests into `parts/zone/...` — **confirmed 2026-08-04**:
      `vxzones` never actually had zone manifests beyond `linux-probe` (its own board,
      `vxzones/TASKS.md`, still shows "Zone manifests for the six roles" as `[ ]`, never
      built — "zero code beyond linux-probe" throughout its own history). There was nothing
      to migrate beyond what already landed above. Every item on `vxzones`' own backlog
      (Zephyr/FreeRTOS/QNX/AAOS images, sensor-node variant, digest tooling, Kuksa, CAN, RSU,
      restbus, Renode, Jetson/DRIVE AGX validation) is already tracked here — see the
      `zone`-class section below plus Phase 3/4 — verified item-by-item against
      `vxzones/TASKS.md` before checking this off, not assumed.
- [x] Migrate `vxcompute`'s docs-only backlog (below) into this board — **confirmed
      2026-08-04**: verified item-by-item against `vxcompute/TASKS.md`. Everything was
      already migrated in the 2026-07-26 re-scope (see the `hpc`-class section below) except
      one real gap, found and added: the minimal responder/echo container for measuring
      **service response time** (`ARCHITECTURE.md` §12's own compute metric class, distinct
      from `vxprobe`'s network-RTT numbers) — `vxcompute`'s own Phase 1 item, missed in the
      original re-scope. `vxcompute`'s other two Phase-1 items (repo layout, a §6.1
      `compute:` manifest) are genuinely obsolete, not gaps: superseded by this repo's own
      layout and by the §6.0 workspace model (§6.1 stopped being a provisioning input
      2026-07-31) respectively.
- [x] Both migrations confirmed complete, then `vxzones` and `vxcompute` **archived on GitHub
      2026-08-04** (not deleted — verified via `gh repo view --json isArchived`, both
      `true`). Propagated ahead of the archival itself: workspace root `CLAUDE.md` repo
      table, `docs/ARCHITECTURE.md` §4, every other repo's `AGENTS.md`/skill naming
      `vxzones`/`vxcompute`; a closing note pushed to each repo's own `TASKS.md` before
      archiving (afterward they're read-only, no more pushes possible).

## Track D consequences for this repo (design closed 2026-07-29)

`docs/TASKS.md` Track D settled the vehicle-model design. Three things land here, none needing
a GPU:

- [x] **`veh` class in `schema/taxonomy.yaml`** — landed 2026-08-05: `code: V`, subtype `car`
      (`code: CAR`), vehicle models are `config`-layer parts at `parts/veh/car/config/<name>`,
      numbered by the existing VXPN scheme. A separate model-number scheme (VXMN) was proposed
      and rejected: one number kind, one publishing contract, so sharing an experiment stays a
      single `oras pull`. Subtypes start at `car`; the class axis leaves room for other
      mobility entities without implementing any. `vxpn.py lint`/`scan` both clean (13 parts,
      no collisions). Scaffolded `parts/veh/car/config/reference-sedan-6zone/` (`todo`, no
      payload yet — none of `vxperiments`' existing vehicle documents is the full six-zone
      reference topology this name promises; populating it is a design decision — hand-author
      one, or defer to Track M/`vxmodels` rendering it from SysML v2 — not data entry, so left
      `todo` deliberately, same discipline as `hpc/ad/config/autoware-params`).
- [x] **`requires:` block in `part.yaml` — schema half landed 2026-08-05.** Optional block
      (`arch`, `libc`, `cpu.cores`, `memory_gb`, `gpu.vram_gb`, `gpu.compute_capability`), as
      distinct from the `resources` a component is *allocated* in a vehicle model, and
      distinct from the coarser workspace-level `.vxp requires: {gpu: none|tier2}` preflight
      that already exists in `vxedge-core` (`package.rs`) — that one gates a whole workspace
      against a host tier before provisioning starts; this one is per-part, meant to feed a
      future part → component → host check. `scripts/vxpn.py`: `_validate_requires()` rejects
      unknown keys/shapes at `lint`/`meta` time, and a declared block is emitted as
      `org.vxedge.requires` (JSON-encoded) alongside the part's other annotations. First real
      usage: `parts/hpc/sim/app/carla-server/part.yaml` (`arch: x86_64`, `gpu.vram_gb: 8`,
      `gpu.compute_capability: "7.0"`, grounded in this repo's own recorded CARLA VRAM note
      and `vxedge-core`'s `TIER2_MIN_COMPUTE_CAP`). Verified: valid/invalid blocks both
      exercised directly against `_validate_requires`, `lint`/`scan` clean.
  - [ ] **Enforcement half still blocked, not done**: `vxedge manifest validate` checking
        part → component → host against this block has nothing to check yet — it needs Track D
        dimension 1 (a real `parts:` list in zone/hpc manifests, replacing today's single flat
        `image` string per node) to exist first. That is the check that would have caught the
        Tier 2 GPU shortfall at validate time instead of after a build; still future work.
      `depends_on` is metadata only — validated for presence in the same baseline, never
      version-solved; a resolver is a package manager and would be a separate decision. Not
      touched by this pass.
- [x] **Composite-part OCI index convention — landed 2026-08-05** (`docs/TASKS.md` #19 item
      3). `scripts/publish/publish-composite.sh`: a `stack`-layer part declares its
      `constituents:` (already-published `<path>:<tag>` refs) in `part.yaml`;
      `vxpn.py build` gates the script to `build: composite` parts only. The non-obvious
      part: `oras manifest index create` requires every referenced manifest to already exist
      in the INDEX'S OWN repository — a real registry enforces this, a naive single-repo
      local test would not have caught it — so the script first cross-mounts each
      constituent's manifest into the composite's own repo with `oras cp` (a same-registry
      mount, not a re-upload, since digests are content-addressed and survive the copy
      unchanged) before indexing the resulting in-repo digests. Verified against a disposable
      local `registry:2` end-to-end, using the real unmodified script (only `oras` itself
      shimmed with `--plain-http`, everything else genuine): two throwaway constituents
      pushed, mounted, indexed, fetched back, digests confirmed to match; both error paths
      (wrong layer, missing `constituents:`) fail loudly. `ad-baseline`/`sim-baseline` now
      carry real `constituents:` lists — still blocked on `autoware-params`/`scenarios`
      themselves being non-`todo`, not on tooling anymore (see their own READMEs).
      A vehicle-as-composite (structure config + every baseline part, one pullable unit) is
      the same convention, second consumer — not built as its own thing, since nothing about
      it differs from what already landed.
- [ ] Publish the manifest **JSON Schema generated from `vxedge-core`** as a config part
      (`parts/ctl/schema/config/manifest-schema`) — editor autocomplete and inline validation
      for hand-authored workspaces.
  - [x] `ctl` class in `schema/taxonomy.yaml` — landed 2026-08-05: `code: C`, subtype `schema`
        (`code: SCH`); scaffolded `parts/ctl/schema/config/manifest-schema/` (`todo`, no
        payload yet). `vxpn.py lint`/`scan` clean.
  - [ ] The schema itself: real Rust codegen in `vxedge` (`schemars` on `vxedge-core`'s
        workspace document structs — `Experiment`/`Vehicle`/`Road`/`Baseline`/`Component` —
        emitted via a script/xtask), not something to fabricate on the `vxparts` side. Tracked
        as part of `docs/TASKS.md` #19 item 4, alongside the registry-fetch mechanism.

## Part numbering (see `PART-NUMBERING.md`)

- [x] **Taxonomy and per-part metadata extracted to data (2026-07-28).** `vxpn.py` had the
      vocabulary hardcoded and the publish script scraped `# license:` comments out of
      Containerfiles — both are now `schema/taxonomy.yaml` (classes/subtypes/layers/supplier/
      digest width) and `parts/*/part.yaml` (licence, upstream pin, GPU, SBOM, annotations),
      resolved through one `vxpn.py meta` call that every publish script and build recipe goes
      through. Subtypes became class-scoped in the move, so `hpc/qnx` is now rejected instead
      of silently encoded, and the taxonomy self-checks on load (duplicate codes, wrong code
      width, a class with no subtypes). Upstream pins moved out of Containerfiles too — the
      recipe takes `ARG UPSTREAM` and the script injects `<ref>@<digest>` from `part.yaml`, so
      recipes carry no version data. **Verified: every existing part number and the published
      bundle's `initrd.img` digest are byte-identical after the refactor.**

- [x] VXPN scheme + `scripts/vxpn.py` (2026-07-26): ARINC-665-shaped `MMMCC-SSSS-SSSS`
      (`VXE7G-ZLNX-SHAE`), **computed from** the part's class/subtype/layer/name rather than
      mapped to it — no side table, preserving the same single-source-of-truth rule that ruled
      out `catalog.yaml`. `encode`/`encode-path`/`verify`/`decode`/`scan`. Check characters
      measured at 100% detection for single-char substitutions and adjacent transpositions.
      Stamped into `meta.json` as `org.vxedge.pn`, so it rides to the registry as an annotation.
- [x] **Taxonomy completed to cover all five classes (2026-07-28).** A catalogue pass over
      the 2026-07-20 E/E architecture found `agent` and `svc` had **no subtypes defined at
      all** — so `vxprobe`, `vxtraffic`, all three `vxota` crates and both `vxtelemetry`
      crates, every one of them shipped working code, could not be assigned a part number.
      Open5GS/UERANSIM (the components behind the H2 result) had no home either. Added:
      `agent`→`probe`/`load`/`collect`, `svc`→`ota`/`telemetry`/`observability`/`signal`,
      `gw`→`5gc`/`ran`/`dp`, `zone`→`mcu`. `svc/signal` exists because the entire VSS/Kuksa
      signal plane — Track D dimensions 2 and 3 — had no representation in the part system.
      Verified: the already-published `VXE7G-ZLNX-SHAE` is unchanged by the addition.
- [ ] `vxpn.py scan` as a CI merge gate — the 3-char name digest holds ~46.6k values, so
      collisions get likely past a couple hundred parts; widen before that, not after.
      Measured on the 77-part candidate catalogue: 0 collisions, but that counts only *named*
      parts — per-zone configs and per-scenario variants push toward the limit fast
- [ ] `org.vxedge.rxswin` (UN R156 / ISO 24089) at vehicle-manifest level — gated on Track D
      dimension 3's `vxedge manifest bom`; an RxSWIN describes a *set* of parts, never one part
- [ ] Supplier-code registry for third-party `MMM` values — only needed once a part arrives
      from outside the project

## Registry & classification (design, mostly decided — see `AGENTS.md`)

- [x] `parts/<class>/<subtype>/<layer>/<name>/` directory layout (build recipe + README only,
      no composition data)
- [x] `scripts/publish/publish-container.sh` (2026-07-28) — podman build+push for `hpc`/`gw`-class
      parts, stamping `org.vxedge.pn/class/subtype/layer/license/gpu` as OCI labels. Derives
      both the registry ref and the VXPN from the part's own directory path, so neither is
      passed in and neither can be mistyped. Two guardrails, both tested: it refuses a
      Containerfile with no pinned `@sha256:` digest (a part built on a moving tag is not
      reproducible, §13), and refuses one that declares no `# license:` line. `VXPARTS_NO_PUSH=1`
      builds and verifies labels without pushing, for CI. Smoke-tested end to end against a
      local image.
- [x] `scripts/publish/publish-files.sh` (2026-07-28) — ORAS push for `config`-layer parts.
      Config is a part in its own right: a run's parameters are as much an input to its result
      as the code that reads them, so an unversioned params file silently breaks §13.
- [x] `scripts/publish/publish-vm-bundle.sh` — ORAS push for `zone`-class VM/kernel/QNX
      IFS/AAOS system images, same annotation set
- [ ] Composite-part convention: OCI image index for a full loaded stack (e.g.
      `parts/zone/qnx/stack/safety-baseline:2.1.0` indexing its os+middleware+config parts as
      one pullable unit) — document the `oras manifest push --index` (or `docker buildx
      imagetools create`) step
- [ ] Decide publish-tooling shape: thin wrapper CLI (`vxpart`?) vs. documented
      `oras`/`docker` invocations + a script-per-kind — default to the latter until the
      number of artifact kinds/repeated steps justifies a real binary
- [x] CI: automated container-part **build** verification — **delivered 2026-08-04**
      (`docs/TASKS.md` #18, cross-reference here). New `build-containers` job in
      `.github/workflows/parts.yml`: detects which `parts/**` directories changed (`git diff`
      against the PR base or the previous push, first-push-to-a-branch handled by diffing
      against the empty tree) and, for each with a `Containerfile`, runs
      `VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh` — the same script `publish`
      already uses, just without pushing, exactly the mode its own `VXPARTS_NO_PUSH` env var
      exists for ("for CI," per its header comment). Catches a broken Containerfile or a
      label that doesn't survive the build before merge — `validate`'s `lint`/`scan` only
      check `part.yaml`/taxonomy metadata, never invoke `podman`. **Deliberately does not
      publish**: pushing into the org namespace stays the manual, dispatch-only act the
      file's own top comment already explains; this job only builds. A real bug caught while
      writing the change-detection logic: the first version's `awk` field split was off by
      one (`parts/<class>/<subtype>/<layer>`, missing the part's own `<name>` segment) —
      found and fixed by dry-running the exact script against this repo's real history before
      trusting it in CI, not by reasoning about it in the abstract.
- [ ] CI: the other half — `parts/zone/**` → VM/kernel bundle build (`publish-vm-bundle.sh`/
      `publish-vm-disk.sh`), a genuinely different toolchain (QEMU/kernel assembly vs.
      Docker+CUDA) from the container half just delivered above — kept as a separate,
      smaller follow-on rather than blocking the container half on it

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

**Critical path — these eight parts, and only these, close phase 2's open gate half
(`exp-011`). Scaffolded 2026-07-28 with READMEs + Containerfiles; each still needs its
upstream digest resolved and its content filled in. Nothing else in this file is
gate-blocking, and building anything else first is how phase 2 slips further.**

- [x] 1. `parts/hpc/ad/middleware/ros2-humble` (`VXE8J-HADS-MFER`) — its own part so the
      bridge and Autoware are forced to agree on one distro + one RMW by construction.
      **Published 2026-07-28**: `ghcr.io/vxedge/parts/hpc/ad/middleware/ros2-humble:0.1.0`,
      `sha256:63d1fc55b689c82420c51217b7915438dc9495656de135069e96ad72bb5d75df`, private,
      8 `org.vxedge.*` labels intact. First `hpc`-class part and first container part in the
      registry — the ORAS and container publish paths are now both proven against GHCR.
- [ ] 2. `parts/hpc/sim/app/carla-server` (`VXER8-HSIM-AGF3`) — **CC-BY-NC assets, see
      licensing review before tagging**
- [x] 3. `parts/hpc/ad/middleware/carla-client` (`VXECL-HADS-M70H`) — **published 2026-07-28**:
      `sha256:832dedf3a03e4b3f9eefc5f4955bce24ab7f30878579d5db2068f860a3e9d436`, private.
      CARLA 0.9.15 Python client on Humble; the build asserts `import carla` so a broken
      client fails the build rather than the experiment.
  - **Replaced `carla-ros-bridge` (`VXEUS-HADS-M7BO`, retired).** The flagged
      "highest integration risk" was real, and worse than a version bump. Verified
      2026-07-28: `carla-simulator/ros-bridge` master is frozen at 2022-07-22 ("Update CARLA
      version to 0.9.13"), no branch touched since 2023-11, and its README requires CARLA
      **0.9.13** against our pinned **0.9.15** server. It built and imported cleanly — which
      is precisely what made it the dangerous option, since a version-mismatched bridge still
      produces numbers. (The CARLA *simulator* is actively maintained, commit 2026-07-14 —
      the frozen repo is the bridge, a different one.)
  - The supported path for 0.9.15 + Humble is **`autoware_carla_interface`** (inside
      `autoware_universe`, compatibility table 22.04/humble/0.9.15, last touched 2026-07-24).
      It is a ROS2 package that ships inside the `autoware` part; what this repo owes it is a
      matching client, which `carla-client` is. Official cp310 wheel exists on PyPI, so the
      `gezp/carla_ros` rebuild its README suggests is unnecessary here.
  - Forward path, deliberately deferred: `autowarefoundation/carla-autoware-extension`
      (very active) targets CARLA `ue5-dev` **native DDS publishers**, removing the bridge
      process from the data path — but its README states it does not replace
      `autoware_carla_interface` for 0.9.15. Revisit when moving off 0.9.15; not phase 2.
- [ ] 4. `parts/hpc/ad/app/autoware` (`VXERR-HADS-AOHA`) — pins/re-labels the upstream
      prebuilt image; a source build costs hours and changes nothing measured
- [ ] 5. `parts/hpc/ad/config/autoware-params` (`VXEUV-HADS-CCSC`) — explicit per-topic DDS
      QoS; populate once the bridge's topic set is known
- [ ] 6. `parts/hpc/sim/config/scenarios` (`VXEQC-HSIM-CD0I`) — fixed-tick synchronous mode;
      in async mode CARLA's tick rate varies with GPU load, so offered ADAS load would differ
      between runs and exp-011's arms would not be comparable
- [ ] 7–8. `parts/hpc/{sim/stack/sim-baseline,ad/stack/ad-baseline}` (`VXEAO-HSIM-S5WY`,
      `VXES9-HADS-S7Q1`) — **blocked on the composite-part convention above**, the only
      critical-path parts needing new tooling rather than new content. Until it lands, an
      experiment manifest references the constituents individually.

**Explicitly NOT on the critical path** (both contend for the same VRAM as CARLA+Autoware on
a single ≥12GB card): DeepStream/TensorRT and Alpamayo. Adding either before the gate closes
converts a schedule problem into a GPU-contention debugging problem.

> **HELD until GPU access (2026-07-29).** `carla-server` and `autoware` are pinned and
> CI-dispatchable, but they serve only `exp-011`, so there is nothing to gain by publishing
> them before there is a host to run them on. Everything above *builds* without a GPU;
> *running* `exp-011` requires a Tier 2 GPU host (RTX-class, ≥12 GB VRAM, tensor cores for
> DeepStream/TensorRT). This hold blocks nothing else — see `docs/TASKS.md` phase 2, where
> Track D's workspace-model implementation is now the main thread.

- [x] **Container parts build in CI** (2026-07-28, `.github/workflows/parts.yml`):
      `validate` (`vxpn.py lint` + `scan`) on every push/PR; `publish` is
      `workflow_dispatch`-only, because pushing into the org namespace is an outward-facing
      act and should not be a side effect of merging a README fix. The runner frees ~30 GB of
      preinstalled toolchains first, since CARLA's base is 8.9 GB compressed (Autoware amd64
      is 2.0 GB) against a stock runner's ~14 GB free. Publishing a pin-and-relabel part
      should never depend on a particular workstation's hardware.
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
- [ ] Minimal `hpc`-class responder/echo container — measures **service response time**
      specifically (`ARCHITECTURE.md` §12's compute metric class, distinct from the
      network-RTT numbers `vxprobe` already produces). From `vxcompute`'s own phase-1
      scope (`Repo layout`/`vxcompute-central manifest` items are obsolete — superseded by
      this repo's own layout and the §6.0 workspace model respectively — but this one
      metric-class gap survived the migration unaddressed until noticed 2026-08-04 while
      confirming `vxcompute`'s backlog was fully present here before archiving it)

## `gw`-class parts

- [ ] `parts/gw/tcu/app/` — TCU-role gateway image (uplink into vxgateway)
- [x] `parts/gw/nos/os/sonic-vs` — SONiC-VS production-NOS twin, image sourcing + publish
      (`docs/TASKS.md` #16). **Scaffolded, sourced, verified, boot-tested, and published, all
      2026-08-03.** Real upstream mechanism resolved live, not guessed: SONiC-VS is an Azure
      Pipelines build output (`Azure.sonic-buildimage.official.vs`, definition 142) — not
      published to any OCI/ORAS registry, so `build.sh` fetches over HTTPS via Azure's public
      build API and only the republish half is `oras push` (`publish-vm-disk.sh`, new sibling
      to `publish-vm-bundle.sh` for single-disk-image parts). Pinned build 1182664 (branch
      `202505`, buildNumber `20260803.4`, commit `ff3c0c9f6`) rather than "latest," per the
      reproducibility rule. Downloaded (~1.9GB), gzip-verified, decompressed to a valid QEMU
      QCOW2 v3 image, digest recorded in `part.yaml`. **Booted under QEMU/KVM and logged in**
      (`admin`/`YourPaSsWoRd`): `show version` confirmed the exact pinned build, platform
      `x86_64-kvm_x86_64-r0`, ASIC `vs`, every expected container present (`docker-orchagent`
      — SWSS, the component that actually consumes rendered `config_db.json`). Real gotcha
      found and documented: booting mutates a qcow2 (QEMU opens read-write by default, SONiC's
      own first-boot sequence writes to disk) — the published artifact is a re-decompressed,
      never-booted copy, confirmed byte-identical to the pre-boot digest. License confirmed
      (not just guessed): `sonic-buildimage`'s own tooling is Apache-2.0, a built image also
      bundles a ~67KB `ThirdPartyLicenses.txt` of third-party terms — recorded honestly in
      `part.yaml`, not asserted as one clean SPDX. `vxpn.py lint`/`scan` pass
      (`VXES3-GNOS-OBIM`, no collisions). **Published**: `ghcr.io/vxedge/parts/gw/nos/os/
      sonic-vs:202505.1182664`, confirmed via `oras manifest fetch` — pushed layer digest,
      size (6457589760 bytes), and every `org.vxedge.*` annotation match `bundle/meta.json`
      exactly, not just a successful push exit code. **Live config-parity verification also
      done, same day**: `verify-config-parity.py` boots a disposable copy, loads
      `vxedge_core::sonic`'s real rendered output (via the new `render_sonic` example) with
      SONiC's own `config load`, and reads every declared field back via direct CONFIG_DB
      queries. Result: all 4 fields in a 2-VLAN example matched exactly, `sonic-cfggen` accepted
      the JSON with no errors — full account, including two real `pexpect`-over-serial-console
      bugs found and fixed along the way, in this part's own README. **Item #16's SONiC-VS twin
      is now fully closed** — mechanism, image sourcing, publish, and live config-parity
      verification all delivered and proven, not assumed.

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
