# Part numbering for vxedge loadables

How every loadable in this repo is identified, and why the scheme is shaped the way it is.
Tooling: `scripts/vxpn.py`. Storage/publishing conventions: `AGENTS.md`.

## The three identifiers, and what each one is for

A loadable carries three identifiers that answer three different questions. Keeping them
distinct is the whole design — conflating them is what produces unmaintainable part systems.

| Identifier | Answers | Example | Mutable? |
|---|---|---|---|
| **Pull path + tag** | *Where do I get it, and which release?* | `ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle:0.1.0` | tag can move |
| **VXPN** (part number) | *What kind of part is this?* | `VXE7G-ZLNX-SHAE` | never |
| **Digest** | *Exactly which bytes?* | `sha256:b3634b26…` | never |

The VXPN identifies a *part type*; the tag and digest identify a *version of it*. A manifest
that must be reproducible pins the digest. A manifest that tracks a part across upgrades
references the VXPN. Humans reading a BOM or a label use the VXPN.

## Why not just the pull path?

The pull path is already unique and already the source of truth — and it stays that way. The
VXPN exists for the places a slash-delimited URL does not survive:

- Bills of software, spreadsheets, procurement records, supplier correspondence.
- Anywhere a number is read aloud, printed on a label, or retyped — the check characters catch
  transcription errors that a URL silently accepts.
- Cross-referencing a part across registries, or after a registry migration.

Crucially, **the VXPN is computed from the path, not mapped to it**. There is no lookup table
anywhere in this repo. `vxpn.py encode-path zone/linux/stack/probe-bundle` derives the number,
and `vxpn.py decode` recovers class/subtype/layer from it. This preserves the standing
single-source-of-truth rule: a side table mapping opaque part numbers to registry refs was
considered and rejected, for the same reason a `catalog.yaml` was rejected — it would be a
second thing to keep in sync, and it would drift.

## Format

ARINC 665's Loadable Software Part Number shape, `MMMCC-SSSS-SSSS`:

```
VXE7G-ZLNX-SHAE
│  │  ││    ││
│  │  ││    │└─ name digest (3 base36 chars, from sha256 of the part name)
│  │  ││    └── layer:   F firmware  O os  H hypervisor  M middleware
│  │  ││                 A app       C config           S stack
│  │  │└─────── subtype: QNX ZEP FRT LNX AAO | ADS CKP MOT SIM | TCU NOS
│  │  └──────── class:   Z zone  H hpc  G gw  A agent  S svc
│  └─────────── check characters (cover MMM + both segments)
└────────────── supplier code — VXE for parts produced by this project
```

`SSSS-SSSS` is the supplier-defined product identifier; we spend it on the classification
itself so the number is *legible* — `ZLNX-S…` reads as "zone / linux / stack" without a
lookup. Third-party suppliers contributing parts get their own `MMM`, exactly as in avionics.

## Provenance, and what this is *not*

The scheme borrows from two industries deliberately, and claims conformance to neither.

**[ARINC 665](https://www.scribd.com/document/658674712/ARINC-665-1-Loadable-SW-standards)**
(Loadable Software Standards) supplies the format: `MMMCC-SSSS-SSSS`, where `MMM` is a
per-supplier code, `CC` is check characters computed from the rest, and `SSSS-SSSS` is a
supplier-defined product identifier. This is the mature answer to "how do you number software
parts that get loaded onto expensive things", refined across decades of avionics practice —
which is where this project's own domain experience comes from, and it transfers cleanly to
zonal SDV loadables.

Two deliberate divergences from ARINC 665:

1. **We do not mint a new part number for every change.** ARINC 665 requires it; we use
   VXPN + SemVer tag + digest instead, which matches automotive practice and how OCI
   registries actually work.
2. **The check-character algorithm is ours**, not ARINC's — the exact routine lives in the
   paid standard and is deliberately not reimplemented here. Ours is a position-weighted
   mod-36 sum, measured at 100% detection for single-character substitutions and adjacent
   transpositions on the current format (the realistic retyping failures). It is an
   error-*detecting* code, not a cryptographic one — the digest is what provides integrity.

**[UN R156](https://certx.com/automotive/software-update-for-road-vehicles-ep-3-focus-on-vehicle-requirements-rxswin-vta/)**
(Software Update Management Systems) and
**[ISO 24089](https://certx.com/automotive/software-update-for-road-vehicles-ep-1-overview-of-un-r156-and-iso-24089/)**
(Road vehicles — Software update engineering) supply the vehicle-level concept. R156 defines
**RxSWIN**, the identifier for the type-approval-relevant software of a vehicle system, which
must be updated whenever that software changes. That is precisely the roll-up a
digital-twin vehicle manifest needs, and it is a regulatory reality for any SDV shipped in a
UNECE market — so the model should carry it rather than invent an equivalent.

Not implemented yet — see the open item below. When it lands, an RxSWIN is a property of a
*vehicle manifest* (a set of parts), never of a single part, and it belongs with Track D
dimension 3's bill-of-software work rather than here.

## Open items

- [ ] `org.vxedge.rxswin` on composite/`stack` parts + a vehicle-level roll-up, once Track D
      dimension 3 (`vxedge manifest bom`) defines the whole-vehicle bill of software. The
      natural pairing is a CycloneDX SBOM per part, with the RxSWIN computed over the set —
      this also feeds the licensing review (`docs/TASKS.md`, go-public prerequisites).
- [ ] `vxpn.py scan` in CI as a merge gate: the 3-char name digest holds ~46.6k values, so
      collisions become likely somewhere past a couple hundred parts. Widen the digest (or
      shorten the supplier segment) before that, not after.
- [ ] Supplier-code registry for third-party `MMM` values — needed only when a part arrives
      from outside the project. Deliberately not built in advance.
