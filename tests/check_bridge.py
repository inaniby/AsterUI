#!/usr/bin/env python3
"""check_bridge.py -- W3: verify the s0->lrintf bridge sequence in a .o.

Ports the idea of the reference's tools/check_input_bridge.py (same
check, own code): disassemble the object, find event_x/event_y
(aui_bridge_x/y here), and fail if any instruction between the
AMotionEvent_getX/Y call and the lrintf call writes s0/d0/q0/v0, or
if there is any third call in between. A PASS here means the compiled
code is bridge-clean; it says nothing about what the device's dynamic
linker does to s0 during lazy PLT resolution -- that is what the
runtime harness measures, and what the device already answered.

Usage: check_bridge.py <object.o>
"""
import re
import subprocess
import sys

CALL_RE = re.compile(r"R_AARCH64_CALL26\s+(\S+)")
INSN_RE = re.compile(r"^\s*[0-9a-f]+:\s+(?:[0-9a-f]{8}\s+)?(\S.*)$")
FUNC_RE = re.compile(r"^[0-9a-f]+ <([^>]+)>:\s*$")


def objdump(path):
    for tool in ("aarch64-linux-gnu-objdump", "llvm-objdump", "objdump"):
        try:
            out = subprocess.run([tool, "-dr", path], stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, text=True,
                                 check=True).stdout
            return out
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    sys.exit("no objdump found")


def clobbers_s0(insn):
    for tok in re.split(r"[^A-Za-z0-9]+", insn):
        if tok in ("s0", "d0", "q0", "v0"):
            return True
    return False


def main():
    disasm = objdump(sys.argv[1])
    funcs = {}
    cur = None
    for line in disasm.splitlines():
        m = FUNC_RE.match(line)
        if m:
            cur = m.group(1)
            funcs[cur] = []
        elif cur is not None:
            funcs[cur].append(line)
    failed = 0
    for name, want in (("aui_bridge_x", "AMotionEvent_getX"),
                       ("aui_bridge_y", "AMotionEvent_getY")):
        lines = funcs.get(name)
        if lines is None:
            print(f"{name}: function not found -- FAIL")
            failed += 1
            continue
        calls = []
        insns = []
        for line in lines:
            m = CALL_RE.search(line)
            if m:
                calls.append((len(insns) - 1, m.group(1)))
                continue
            m = INSN_RE.match(line)
            if m:
                insns.append(m.group(1).strip())
        if len(calls) != 2 or calls[0][1] != want or calls[1][1] != "lrintf":
            print(f"{name}: calls={calls} -- FAIL (expected get + lrintf)")
            failed += 1
            continue
        between = insns[calls[0][0] + 1:calls[1][0] + 1]
        bad = [i for i in between if clobbers_s0(i)]
        if bad:
            print(f"{name}: s0 clobbered between calls: {bad} -- FAIL")
            failed += 1
        else:
            print(f"{name}: get -> lrintf adjacent, {len(between)} insn(s) "
                  f"between, none writes s0/d0/q0/v0 -- PASS")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
