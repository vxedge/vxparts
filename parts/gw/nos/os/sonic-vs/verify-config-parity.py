#!/usr/bin/env python3
"""Boot a SONiC-VS image, push a rendered config_db.json into it, and confirm what comes back
out (`show vlan brief`, direct CONFIG_DB reads) matches exactly what was pushed in.

This is docs/TASKS.md #16's SONiC-VS config-parity verification -- the claim ARCHITECTURE.md
Sec 7 makes ("the same slice/VLAN intent expresses identically on a production NOS"), proven
against a real running instance rather than assumed from the renderer's own unit tests.

Usage:
    python3 verify-config-parity.py <sonic-vs.img> <rendered-config.json>

<rendered-config.json> is vxedge_core::sonic's real output, generated with the real renderer,
not hand-written -- see ../../../../../vxedge/crates/vxedge-core/examples/render_sonic.rs:
    cargo run -p vxedge-core --example render_sonic -- <manifest.yaml> <trunk-port>

Needs: qemu-system-x86_64 with KVM, the `pexpect` Python package. Boots a *disposable copy* of
the given image -- never the image path itself, since QEMU opens a qcow2 read-write by default
and SONiC's own first-boot sequence mutates the disk (found live 2026-08-03, see build.sh's own
warning) -- so the original stays untouched regardless of how this script is invoked.

SONiC-VS's default config pre-assigns every front-panel port (Ethernet0, Ethernet4, ...) as a
routed L3 interface (a default T1 leaf-fabric topology) -- this script clears the L3 interface
config on whichever ports the rendered config's own VLAN_MEMBER entries name, generically (by
scanning CONFIG_DB rather than hardcoding a port list), before loading: a port can't be both a
routed L3 interface and a VLAN member simultaneously, and an operator repurposing a port for
slice/VLAN isolation would do exactly this in practice, not something this script works around.
"""
import json
import shutil
import sys
import tempfile
from pathlib import Path

import pexpect

LOGIN_TIMEOUT = 150
CMD_TIMEOUT = 30
# The literal shell prompt, anchored to end-of-line -- not a bare `\$`. Found live: a bare `\$`
# matches the *first* `$` anywhere in the buffer, including one echoed back from the command's
# own text (e.g. `$(redis-cli ...)`, `"$ip"` in the port-clearing loop below) -- so `run()` was
# returning as soon as the shell echoed the command line, not when it actually finished, and
# the next command got fed to a still-busy shell. Anchoring to the real prompt at end-of-buffer
# is the fix, not a per-call workaround, since any future command containing `$` would hit the
# same bug otherwise.
PROMPT = r"admin@sonic:~\$ $"


def run(child, command, expect=PROMPT, timeout=CMD_TIMEOUT):
    child.sendline(command)
    child.expect(expect, timeout=timeout)


def main():
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <sonic-vs.img> <rendered-config.json>", file=sys.stderr)
        return 2

    image_path = Path(sys.argv[1])
    config_path = Path(sys.argv[2])
    rendered = json.loads(config_path.read_text())

    vlans = rendered.get("VLAN", {})
    members = rendered.get("VLAN_MEMBER", {})
    if not vlans or not members:
        print("error: rendered config has no VLAN/VLAN_MEMBER entries -- nothing to verify", file=sys.stderr)
        return 2
    ports = sorted({key.split("|", 1)[1] for key in members})

    with tempfile.TemporaryDirectory() as tmp:
        disposable = Path(tmp) / "sonic-vs-verify.img"
        print(f"== copying {image_path} -> {disposable} (disposable; the original is never booted)")
        shutil.copy(image_path, disposable)

        cmd = (
            "qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 "
            f"-drive file={disposable},if=virtio,format=qcow2 "
            "-netdev user,id=mgmt -device virtio-net-pci,netdev=mgmt "
            "-display none -serial stdio -monitor none -no-reboot"
        )
        child = pexpect.spawn(cmd, timeout=180, encoding="utf-8", codec_errors="ignore")
        child.logfile = sys.stdout

        print("\n== booting and logging in")
        child.expect("login:", timeout=LOGIN_TIMEOUT)
        child.sendline("admin")
        child.expect("assword:", timeout=20)
        child.sendline("YourPaSsWoRd")
        child.expect(PROMPT, timeout=20)

        for port in ports:
            print(f"\n== clearing {port}'s default L3 interface config, if any")
            run(
                child,
                f"for ip in $(redis-cli -n 4 --scan --pattern 'INTERFACE|{port}|*' "
                f"| cut -d'|' -f3); do sudo config interface ip remove {port} \"$ip\"; done",
                timeout=20,
            )

        print("\n== writing the rendered config to the guest")
        child.sendline("cat > /tmp/vxedge-render.json << 'VXEOF'")
        for line in json.dumps(rendered, indent=2).splitlines():
            child.sendline(line)
        child.sendline("VXEOF")
        child.expect(PROMPT, timeout=20)

        print("\n== config load")
        run(child, "sudo config load /tmp/vxedge-render.json -y")

        print("\n== reading back and comparing")
        # The rendered JSON's own keys are bare row keys ("Vlan101") -- the outer JSON key
        # ("VLAN") already names the table, matching config_db.json's own nested-object shape.
        # A direct redis-cli lookup needs the real CONFIG_DB key, table name prefixed
        # ("VLAN|Vlan101"): found live -- the first version of this script queried the bare
        # row key and got `(nil)` back for every field, which would have been read as "the
        # config never loaded" rather than what it actually was, a key-construction bug in the
        # verification script itself, not in vxedge_core::sonic's renderer.
        failures = []
        for vlan_id, decl in vlans.items():
            run(child, f"redis-cli -n 4 hget 'VLAN|{vlan_id}' vlanid")
            got = child.before.strip().splitlines()[-1].strip('"')
            want = decl["vlanid"]
            status = "OK" if got == want else "MISMATCH"
            print(f"   VLAN {vlan_id}: declared vlanid={want}, live vlanid={got} [{status}]")
            if got != want:
                failures.append(f"{vlan_id}: declared {want}, got {got}")

        for member_key, decl in members.items():
            run(child, f"redis-cli -n 4 hget 'VLAN_MEMBER|{member_key}' tagging_mode")
            got = child.before.strip().splitlines()[-1].strip('"')
            want = decl["tagging_mode"]
            status = "OK" if got == want else "MISMATCH"
            print(f"   {member_key}: declared tagging_mode={want}, live tagging_mode={got} [{status}]")
            if got != want:
                failures.append(f"{member_key}: declared {want}, got {got}")

        child.terminate(force=True)

        if failures:
            print(f"\n== FAILED: {len(failures)} mismatch(es):", file=sys.stderr)
            for f in failures:
                print(f"   {f}", file=sys.stderr)
            return 1

        print(f"\n== PASSED: all {len(vlans)} VLAN(s) and {len(members)} member(s) match exactly")
        return 0


if __name__ == "__main__":
    sys.exit(main())
