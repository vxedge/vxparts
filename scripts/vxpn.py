#!/usr/bin/env python3
"""vxpn — compute and verify vxedge part numbers (VXPN).

A VXPN is an ARINC-665-*shaped* identifier for a loadable, deterministically derived from
the part's class/subtype/layer/name. It is NOT a second source of truth: nothing maps a VXPN
to a registry location via a side table — the VXPN is computed from the pull path, and
`decode` recovers the path components from the VXPN. See ../PART-NUMBERING.md.

    ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle   ->   VXE7G-ZLNX-SHAE

This file holds the *algorithm* only. The vocabulary it encodes — classes, subtypes, layers,
supplier code, digest width — lives in ../schema/taxonomy.yaml, so extending the taxonomy is
a reviewable data change and never a code change.

Usage:
    vxpn.py encode <class> <subtype> <layer> <name>
    vxpn.py encode-path <parts-path>        # e.g. zone/linux/stack/probe-bundle
    vxpn.py verify <vxpn>                   # check-character validation
    vxpn.py decode <vxpn>                   # -> class/subtype/layer + name digest
    vxpn.py meta <part-dir>                 # part.yaml + VXPN -> org.vxedge.* JSON
    vxpn.py build <part-dir>                # resolved build kind: recipe | files | composite
    vxpn.py scan [parts-dir]                # collision gate over a parts/ tree (CI)
    vxpn.py lint [parts-dir]                # taxonomy + part.yaml validation (CI)
"""
import hashlib
import json
import pathlib
import sys

try:
    import yaml
except ImportError:
    raise SystemExit("error: PyYAML required —  pip install --user PyYAML")

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAXONOMY_PATH = ROOT / "schema" / "taxonomy.yaml"


def load_taxonomy(path: pathlib.Path = TAXONOMY_PATH) -> dict:
    """Load and self-check the taxonomy. A malformed vocabulary must fail loudly here
    rather than silently produce part numbers that cannot be decoded."""
    if not path.exists():
        raise SystemExit(f"error: taxonomy not found at {path}")
    t = yaml.safe_load(path.read_text())

    digest_w = t["format"]["name_digest_chars"]
    seg_w = 1 + digest_w  # class|layer code (1) + subtype code or name digest
    for cls, spec in t["classes"].items():
        if len(spec["code"]) != 1:
            raise SystemExit(f"taxonomy: class '{cls}' code must be 1 char")
        if not spec.get("subtypes"):
            raise SystemExit(
                f"taxonomy: class '{cls}' has no subtypes — parts of that class could not "
                f"be numbered at all (this was the state of agent/svc before 2026-07-28)")
        codes = {}
        for sub, sspec in spec["subtypes"].items():
            if len(sspec["code"]) != digest_w:
                raise SystemExit(
                    f"taxonomy: subtype '{cls}/{sub}' code '{sspec['code']}' must be "
                    f"{digest_w} chars to fit segment width {seg_w}")
            if sspec["code"] in codes:
                raise SystemExit(
                    f"taxonomy: duplicate subtype code '{sspec['code']}' in class '{cls}' "
                    f"({sub} vs {codes[sspec['code']]}) — decode would be ambiguous")
            codes[sspec["code"]] = sub
    layer_codes = {}
    for layer, lspec in t["layers"].items():
        if len(lspec["code"]) != 1:
            raise SystemExit(f"taxonomy: layer '{layer}' code must be 1 char")
        if lspec["code"] in layer_codes:
            raise SystemExit(f"taxonomy: duplicate layer code '{lspec['code']}'")
        layer_codes[lspec["code"]] = layer
    return t


TAX = load_taxonomy()
SUPPLIER = TAX["supplier"]["code"]
B36 = TAX["format"]["alphabet"]
DIGEST_W = TAX["format"]["name_digest_chars"]


def _b36(n: int, width: int) -> str:
    out = ""
    for _ in range(width):
        n, r = divmod(n, 36)
        out = B36[r] + out
    return out


def name_digest(name: str) -> str:
    """Base36 digest of the name — deterministic, and collision-checkable in CI."""
    h = int.from_bytes(hashlib.sha256(name.encode()).digest()[:4], "big")
    return _b36(h % (36 ** DIGEST_W), DIGEST_W)


def check_chars(body: str) -> str:
    """Two base36 check characters over the identifier body.

    Position-weighted mod-36 sum: catches single-character substitutions and adjacent
    transpositions, which are the realistic failure modes when a PN is read off a label or
    retyped into a manifest. This is our own algorithm — ARINC 665's exact check-character
    routine is defined in the (paid) standard and is deliberately not reimplemented here.
    """
    vals = [B36.index(c) for c in body if c in B36]
    s1 = sum(vals) % 36
    s2 = sum((i + 1) * v for i, v in enumerate(vals)) % 36
    return B36[s1] + B36[s2]


def encode(cls: str, subtype: str, layer: str, name: str) -> str:
    classes, layers = TAX["classes"], TAX["layers"]
    if cls not in classes:
        raise SystemExit(f"unknown class '{cls}' (expected one of {sorted(classes)})")
    if layer not in layers:
        raise SystemExit(f"unknown layer '{layer}' (expected one of {sorted(layers)})")
    subtypes = classes[cls]["subtypes"]
    # Subtypes are class-scoped: `hpc/qnx` is as wrong as an unknown subtype, and catching it
    # here is why a typo'd path cannot quietly mint a valid-looking number for a nonexistent
    # kind of part.
    if subtype not in subtypes:
        raise SystemExit(
            f"unknown subtype '{subtype}' for class '{cls}' (expected one of "
            f"{sorted(subtypes)}) — add it to {TAXONOMY_PATH.name} so the code stays stable, "
            f"rather than deriving one on the fly")
    seg1 = classes[cls]["code"] + subtypes[subtype]["code"]
    seg2 = layers[layer]["code"] + name_digest(name)
    # Check characters cover the supplier code too, so a corrupted MMM is caught as well.
    return f"{SUPPLIER}{check_chars(SUPPLIER + seg1 + seg2)}-{seg1}-{seg2}"


def parse(vxpn: str):
    seg_w = 1 + DIGEST_W
    parts = vxpn.split("-")
    if (len(parts) != 3 or len(parts[0]) != len(SUPPLIER) + 2
            or len(parts[1]) != seg_w or len(parts[2]) != seg_w):
        raise SystemExit(f"malformed VXPN '{vxpn}' (expected {TAX['format']['pattern']})")
    n = len(SUPPLIER)
    return parts[0][:n], parts[0][n:], parts[1], parts[2]


def verify(vxpn: str) -> bool:
    supplier, cc, seg1, seg2 = parse(vxpn)
    return cc == check_chars(supplier + seg1 + seg2)


def decode(vxpn: str) -> dict:
    supplier, _, seg1, seg2 = parse(vxpn)
    if not verify(vxpn):
        raise SystemExit("refusing to decode: check characters do not validate")
    cls = next((c for c, s in TAX["classes"].items() if s["code"] == seg1[0]), None)
    subtype = None
    if cls:
        subtype = next((n for n, s in TAX["classes"][cls]["subtypes"].items()
                        if s["code"] == seg1[1:]), None)
    layer = next((l for l, s in TAX["layers"].items() if s["code"] == seg2[0]), None)
    return {"supplier": supplier, "class": cls, "subtype": subtype,
            "layer": layer, "name_digest": seg2[1:]}


def part_fields(part_dir: pathlib.Path):
    """class/subtype/layer/name from the part's own location. The path is the address."""
    p = part_dir.resolve()
    try:
        rel = p.relative_to(ROOT / "parts")
    except ValueError:
        raise SystemExit(f"error: {part_dir} is not under {ROOT / 'parts'}")
    if len(rel.parts) != 4:
        raise SystemExit(
            f"error: '{rel}' is not <class>/<subtype>/<layer>/<name>")
    return rel.parts


REQUIRES_KEYS = {"arch", "libc", "cpu", "memory_gb", "gpu"}
REQUIRES_CPU_KEYS = {"cores"}
REQUIRES_GPU_KEYS = {"vram_gb", "compute_capability"}


def _validate_requires(requires: dict, meta_path: pathlib.Path) -> None:
    """Schema-side validation only (Track D consequence b, vxparts/TASKS.md): what a part
    *needs* to run, as distinct from the `resources` a component is *allocated* in a vehicle
    model. `vxedge manifest validate` checking part -> component -> host against this is a
    separate, not-yet-built piece — it is blocked on Track D dimension 1 (a `parts:` list in
    zone/hpc manifests), which does not exist yet. This function only keeps `requires:` blocks
    honest at publish time; it does not itself enforce anything against a host.
    """
    if not isinstance(requires, dict):
        raise SystemExit(f"error: {meta_path} 'requires' must be a mapping")
    unknown = set(requires) - REQUIRES_KEYS
    if unknown:
        raise SystemExit(
            f"error: {meta_path} 'requires' has unknown key(s) {sorted(unknown)} "
            f"(expected a subset of {sorted(REQUIRES_KEYS)})")
    if "memory_gb" in requires and not isinstance(requires["memory_gb"], (int, float)):
        raise SystemExit(f"error: {meta_path} 'requires.memory_gb' must be numeric")
    if "cpu" in requires:
        cpu = requires["cpu"]
        if not isinstance(cpu, dict) or set(cpu) - REQUIRES_CPU_KEYS:
            raise SystemExit(
                f"error: {meta_path} 'requires.cpu' must be a mapping with only "
                f"{sorted(REQUIRES_CPU_KEYS)}")
    if "gpu" in requires:
        gpu = requires["gpu"]
        if not isinstance(gpu, dict) or set(gpu) - REQUIRES_GPU_KEYS:
            raise SystemExit(
                f"error: {meta_path} 'requires.gpu' must be a mapping with only "
                f"{sorted(REQUIRES_GPU_KEYS)}")


def part_meta(part_dir: pathlib.Path) -> dict:
    """Merge the path-derived identity with the part's declared metadata.

    Identity (class/subtype/layer/name) comes from the path and is never restated in
    part.yaml — restating it would create exactly the drift the no-catalog rule exists to
    prevent. part.yaml carries only what the path cannot express: licence, upstream pin,
    GPU requirement, and any extra annotations.
    """
    cls, subtype, layer, name = part_fields(part_dir)
    meta_path = part_dir / "part.yaml"
    if not meta_path.exists():
        raise SystemExit(f"error: {meta_path} not found — every part declares one")
    decl = yaml.safe_load(meta_path.read_text()) or {}

    for forbidden in ("class", "subtype", "layer"):
        if forbidden in decl:
            raise SystemExit(
                f"error: {meta_path} declares '{forbidden}' — that comes from the path, "
                f"and duplicating it here is how the two drift apart")
    if "name" in decl and decl["name"] != name:
        raise SystemExit(
            f"error: {meta_path} says name '{decl['name']}' but its directory is '{name}'")
    if not decl.get("license"):
        raise SystemExit(f"error: {meta_path} declares no 'license:'")

    out = {
        "org.vxedge.pn": encode(cls, subtype, layer, name),
        "org.vxedge.class": cls,
        "org.vxedge.subtype": subtype,
        "org.vxedge.layer": layer,
        "org.vxedge.license": str(decl["license"]),
    }
    if decl.get("gpu"):
        out["org.vxedge.gpu"] = str(decl["gpu"])
    if decl.get("requires"):
        _validate_requires(decl["requires"], meta_path)
        out["org.vxedge.requires"] = json.dumps(decl["requires"], sort_keys=True)
    upstream = decl.get("upstream") or {}
    if upstream.get("ref"):
        out["org.vxedge.upstream"] = str(upstream["ref"])
    if upstream.get("digest"):
        out["org.vxedge.upstream-digest"] = str(upstream["digest"])
    # SBOM is declared here but produced at build time; the annotation is only emitted when
    # the file actually exists, so a declared-but-missing SBOM never becomes a false claim.
    sbom = decl.get("sbom") or {}
    if sbom.get("path") and (part_dir / sbom["path"]).exists():
        out["org.vxedge.sbom"] = str(sbom.get("format", "cyclonedx-json"))
    for k, v in (decl.get("annotations") or {}).items():
        out[f"org.vxedge.{k}"] = str(v)
    return out


def part_build(part_dir: pathlib.Path, layer: str) -> str:
    """How this part is produced: `recipe`, `files`, or `composite`.

    The layer supplies the default; a part may override it. `stack` defaults to `composite`
    because most stacks are OCI indexes over other parts — but a stack can also be genuinely
    built as one artifact (probe-bundle assembles a kernel + initramfs), and the taxonomy
    should describe the common case without forbidding the other one.
    """
    decl = yaml.safe_load((part_dir / "part.yaml").read_text()) or {}
    build = decl.get("build") or TAX["layers"][layer].get("build", "recipe")
    if build not in ("recipe", "files", "composite"):
        raise SystemExit(f"error: {part_dir}/part.yaml has unknown build '{build}'")
    return build


def _iter_parts(root: pathlib.Path):
    for d in sorted(root.glob("*/*/*/*")):
        if d.is_dir():
            yield d


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd, args = sys.argv[1], sys.argv[2:]

    if cmd == "encode" and len(args) == 4:
        print(encode(*args))
    elif cmd == "encode-path" and len(args) == 1:
        seg = args[0].strip("/").split("/")
        if len(seg) != 4:
            raise SystemExit("expected <class>/<subtype>/<layer>/<name>")
        print(encode(*seg))
    elif cmd == "verify" and len(args) == 1:
        ok = verify(args[0])
        print("valid" if ok else "INVALID check characters")
        return 0 if ok else 1
    elif cmd == "decode" and len(args) == 1:
        d = decode(args[0])
        print(f"supplier:     {d['supplier']}")
        print(f"class:        {d['class'] or '?'}")
        print(f"subtype:      {d['subtype'] or '?'}")
        print(f"layer:        {d['layer'] or '?'}")
        print(f"name digest:  {d['name_digest']}  (one-way — the registry holds the name)")
    elif cmd == "meta" and len(args) == 1:
        print(json.dumps(part_meta(pathlib.Path(args[0])), indent=2, sort_keys=True))
    elif cmd == "build" and len(args) == 1:
        d = pathlib.Path(args[0])
        _cls, _sub, layer, _name = part_fields(d)
        print(part_build(d, layer))
    elif cmd == "scan":
        # The name digest is finite, so collisions become likely as the catalogue grows —
        # this is the CI gate that catches one before it ships.
        root = pathlib.Path(args[0] if args else ROOT / "parts")
        seen, bad = {}, 0
        for d in _iter_parts(root):
            path = "/".join(d.parts[-4:])
            pn = encode(*d.parts[-4:])
            if pn in seen:
                print(f"COLLISION: {pn}  {path}  <->  {seen[pn]}")
                bad += 1
            seen[pn] = path
            print(f"{pn}  {path}")
        if bad:
            print(f"\n{bad} collision(s) — rename a part or widen "
                  f"format.name_digest_chars", file=sys.stderr)
            return 1
        capacity = 36 ** DIGEST_W
        print(f"\n{len(seen)} part(s), no collisions "
              f"({DIGEST_W}-char digest, {capacity:,} values)")
    elif cmd == "lint":
        # Taxonomy already self-checked at import; this validates every part declaration
        # against the `build:` contract its layer declares in taxonomy.yaml.
        root = pathlib.Path(args[0] if args else ROOT / "parts")
        bad = todo = 0
        for d in _iter_parts(root):
            path = "/".join(d.parts[-4:])
            try:
                m = part_meta(d)
            except SystemExit as e:
                print(f"FAIL {path}: {e}")
                bad += 1
                continue
            layer = m["org.vxedge.layer"]
            build = part_build(d, layer)
            recipes = [r for r in ("Containerfile", "build.sh") if (d / r).exists()]
            payload = [f for f in d.iterdir()
                       if f.is_file() and f.name not in ("README.md", "part.yaml")]
            note = ""
            if build == "recipe":
                if len(recipes) > 1:
                    print(f"FAIL {path}: {len(recipes)} recipes ({', '.join(recipes)}) — "
                          f"exactly one decides how the part is built")
                    bad += 1
                    continue
                if not recipes:
                    print(f"FAIL {path}: layer '{layer}' needs a build recipe "
                          f"(Containerfile or build.sh)")
                    bad += 1
                    continue
                note = recipes[0]
            elif build == "files":
                if recipes:
                    print(f"FAIL {path}: layer '{layer}' is published as files, but has "
                          f"{recipes[0]} — a config part is its files, it does not build one")
                    bad += 1
                    continue
                if not payload:
                    # Scaffolded but empty: a legitimate intermediate state, tracked in
                    # TASKS.md. Reported so it can't be mistaken for a complete part.
                    print(f"todo {path}  {m['org.vxedge.pn']}  (no payload files yet)")
                    todo += 1
                    continue
                note = f"{len(payload)} file(s)"
            else:  # composite
                note = "composite (indexed, not built)"
            print(f"ok   {path}  {m['org.vxedge.pn']}  {m['org.vxedge.license']}  [{note}]")
        if bad:
            print(f"\n{bad} part(s) failed", file=sys.stderr)
            return 1
        print(f"\nall parts valid" + (f" ({todo} scaffolded, no payload yet)" if todo else ""))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
