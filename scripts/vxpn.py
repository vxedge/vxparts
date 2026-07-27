#!/usr/bin/env python3
"""vxpn — compute and verify vxedge part numbers (VXPN).

A VXPN is an ARINC-665-*shaped* identifier for a loadable, deterministically derived from
the part's class/subtype/layer/name. It is NOT a second source of truth: nothing maps a VXPN
to a registry location via a side table — the VXPN is computed from the pull path, and
`decode` recovers the path components from the VXPN. See ../PART-NUMBERING.md.

    ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle   ->   VXE39-ZLNX-SQ8W

Usage:
    vxpn.py encode <class> <subtype> <layer> <name>
    vxpn.py encode-path <parts-path>        # e.g. zone/linux/stack/probe-bundle
    vxpn.py verify <vxpn>                   # check-character validation
    vxpn.py decode <vxpn>                   # -> class/subtype/layer + name digest
"""
import hashlib
import sys

# Format: MMMCC-SSSS-SSSS (ARINC 665 §2.1.2 shape)
#   MMM  = supplier code   ("VXE" for parts produced by this project)
#   CC   = check characters (transcription-error detection)
#   SSSS = class(1) + subtype(3)
#   SSSS = layer(1) + name digest(3)
SUPPLIER = "VXE"
B36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

CLASS_CODE = {"zone": "Z", "hpc": "H", "gw": "G", "agent": "A", "svc": "S"}
LAYER_CODE = {
    "firmware": "F", "os": "O", "hypervisor": "H", "middleware": "M",
    "app": "A", "config": "C", "stack": "S",
}
# Explicit codes so the mapping is stable even if a subtype name is later reworded.
SUBTYPE_CODE = {
    "qnx": "QNX", "zephyr": "ZEP", "freertos": "FRT", "linux": "LNX", "aaos": "AAO",
    "ad": "ADS", "cockpit": "CKP", "motion": "MOT", "sim": "SIM",
    "tcu": "TCU", "nos": "NOS",
}
CLASS_DECODE = {v: k for k, v in CLASS_CODE.items()}
LAYER_DECODE = {v: k for k, v in LAYER_CODE.items()}
SUBTYPE_DECODE = {v: k for k, v in SUBTYPE_CODE.items()}


def _b36(n: int, width: int) -> str:
    out = ""
    for _ in range(width):
        n, r = divmod(n, 36)
        out = B36[r] + out
    return out


def name_digest(name: str) -> str:
    """3 base36 chars from the name — deterministic, and collision-checkable in CI."""
    h = int.from_bytes(hashlib.sha256(name.encode()).digest()[:4], "big")
    return _b36(h % (36 ** 3), 3)


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
    if cls not in CLASS_CODE:
        raise SystemExit(f"unknown class '{cls}' (expected one of {sorted(CLASS_CODE)})")
    if layer not in LAYER_CODE:
        raise SystemExit(f"unknown layer '{layer}' (expected one of {sorted(LAYER_CODE)})")
    if subtype not in SUBTYPE_CODE:
        raise SystemExit(
            f"unknown subtype '{subtype}' — add it to SUBTYPE_CODE in {sys.argv[0]} so the "
            f"code stays stable, rather than deriving one on the fly"
        )
    seg1 = CLASS_CODE[cls] + SUBTYPE_CODE[subtype]
    seg2 = LAYER_CODE[layer] + name_digest(name)
    # Check characters cover the supplier code too, so a corrupted MMM is caught as well.
    return f"{SUPPLIER}{check_chars(SUPPLIER + seg1 + seg2)}-{seg1}-{seg2}"


def parse(vxpn: str):
    parts = vxpn.split("-")
    if len(parts) != 3 or len(parts[0]) != 5 or len(parts[1]) != 4 or len(parts[2]) != 4:
        raise SystemExit(f"malformed VXPN '{vxpn}' (expected MMMCC-SSSS-SSSS)")
    return parts[0][:3], parts[0][3:], parts[1], parts[2]


def verify(vxpn: str) -> bool:
    supplier, cc, seg1, seg2 = parse(vxpn)
    return cc == check_chars(supplier + seg1 + seg2)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "encode" and len(sys.argv) == 6:
        print(encode(*sys.argv[2:6]))
    elif cmd == "encode-path" and len(sys.argv) == 3:
        seg = sys.argv[2].strip("/").split("/")
        if len(seg) != 4:
            raise SystemExit("expected <class>/<subtype>/<layer>/<name>")
        print(encode(*seg))
    elif cmd == "verify" and len(sys.argv) == 3:
        ok = verify(sys.argv[2])
        print("valid" if ok else "INVALID check characters")
        return 0 if ok else 1
    elif cmd == "scan":
        # Walk parts/ and assign a VXPN to every part directory, failing on collisions.
        # The name digest is 3 base36 chars (~46.6k values), so collisions get likely past a
        # couple hundred parts — this is the CI gate that catches one before it ships.
        import pathlib
        root = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "parts")
        seen, bad = {}, 0
        for d in sorted(root.glob("*/*/*/*")):
            if not d.is_dir():
                continue
            cls, subtype, layer, name = d.parts[-4:]
            pn = encode(cls, subtype, layer, name)
            path = "/".join(d.parts[-4:])
            if pn in seen:
                print(f"COLLISION: {pn}  {path}  <->  {seen[pn]}")
                bad += 1
            seen[pn] = path
            print(f"{pn}  {path}")
        if bad:
            print(f"\n{bad} collision(s) — rename a part or widen the digest", file=sys.stderr)
            return 1
        print(f"\n{len(seen)} part(s), no collisions")
    elif cmd == "decode" and len(sys.argv) == 3:
        supplier, _, seg1, seg2 = parse(sys.argv[2])
        if not verify(sys.argv[2]):
            raise SystemExit("refusing to decode: check characters do not validate")
        print(f"supplier:     {supplier}")
        print(f"class:        {CLASS_DECODE.get(seg1[0], '?')}")
        print(f"subtype:      {SUBTYPE_DECODE.get(seg1[1:], '?')}")
        print(f"layer:        {LAYER_DECODE.get(seg2[0], '?')}")
        print(f"name digest:  {seg2[1:]}  (one-way — the registry holds the readable name)")
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
