#!/bin/sh
# bridge-check.sh -- W3 bridge-measurement runner (cold-PLT case).
#
# Builds the two probe .so inputs (reference s0->lrintf bridge, verbatim,
# and the kept f32 route) with the reference link conditions (explicit
# libm DT_NEEDED; the reference build.sh sets no BIND_NOW anywhere),
# then runs the C harness in three binding modes, each a fresh process
# so the first coordinate call is the cold first-ever call:
#   (a) RTLD_LAZY              -- cold-PLT lazy dlopen (device failure mode)
#   (b) RTLD_NOW               -- eager binding (closest analogue of the
#                                 reference's stated link conditions)
#   (b2) RTLD_LAZY + LD_BIND_NOW=1 -- eager binding via the environment
# The gate is the KEPT f32 route: it must return true coordinates in all
# three modes. The bridge result is reported, not gated: qemu + glibc
# cannot discriminate (M1.2a proved the old bridge passes here under
# both modes while failing on the device), so a bridge PASS here proves
# nothing about Android and a bridge FAIL would be new evidence.
# Also runs check_bridge.py (disassembly: no s0 clobber between the
# getX/Y call and the lrintf call in the compiled bridge code).
#
# Usage: sh stdlib/asterui/tests/bridge-check.sh
#   ASTER, QEMU, GUESTCC honoured; OUT defaults to /tmp/aui-adopt-bridge.
# Exit 0 only when the f32 route passes in all three modes and the
# disassembly check passes.
set -e
ASTER=${ASTER:-/home/hatch/workspace/projects/Aster-env/aster}
QEMU=${QEMU:-qemu-aarch64}
GUESTCC=${GUESTCC:-aarch64-linux-gnu-gcc}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# ROOT is the repo root only when this file lives at
# stdlib/asterui/tests/; the probes have no includes, so any cwd works.
TESTS=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/tmp/aui-adopt-bridge}
mkdir -p "$OUT"

echo "== bridge probe objects"
"$ASTER" build-obj --pic "$TESTS/bridge_probe.ast" -o "$OUT/bridge_probe.o"
"$ASTER" build-obj --pic "$TESTS/f32_probe.ast" -o "$OUT/f32_probe.o"
echo "== link-so (reference conditions: explicit libm DT_NEEDED, no BIND_NOW)"
"$ASTER" link-so "$OUT/bridge_probe.o" "$OUT/f32_probe.o" \
    --soname libprobe.so \
    --needed libfakeandroid.so --needed libm.so --needed libc.so \
    -o "$OUT/libprobe.so"
echo "== fake libandroid + harness (AArch64 host C)"
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -shared -fPIC \
    -Wl,-soname,libfakeandroid.so -o "$OUT/libfakeandroid.so" "$TESTS/fake_android.c"
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror \
    -o "$OUT/bridge_harness" "$TESTS/bridge_harness.c" -ldl -lm
# Guest libc/libm aliases: the .so asks for bare libm.so/libc.so (the
# Android sonames); under qemu those are linker scripts, so point the
# names at the real AArch64 .so.6 files (same trick as tests/guest-libc-alias.sh).
for c in /usr/aarch64-linux-gnu/lib/libc.so.6 /lib/aarch64-linux-gnu/libc.so.6 /usr/lib/aarch64-linux-gnu/libc.so.6; do
    if [ -e "$c" ]; then ln -sf "$c" "$OUT/libc.so"; break; fi
done
for c in /usr/aarch64-linux-gnu/lib/libm.so.6 /lib/aarch64-linux-gnu/libm.so.6 /usr/lib/aarch64-linux-gnu/libm.so.6; do
    if [ -e "$c" ]; then ln -sf "$c" "$OUT/libm.so"; break; fi
done

echo "== disassembly check (no s0 clobber in the compiled bridge)"
python3 "$TESTS/check_bridge.py" "$OUT/bridge_probe.o"

echo "== (a) RTLD_LAZY cold-PLT"
LD_LIBRARY_PATH="$OUT" "$QEMU" -L /usr/aarch64-linux-gnu "$OUT/bridge_harness" "$OUT/libprobe.so" lazy
echo "== (b) RTLD_NOW eager"
LD_LIBRARY_PATH="$OUT" "$QEMU" -L /usr/aarch64-linux-gnu "$OUT/bridge_harness" "$OUT/libprobe.so" now
echo "== (b2) RTLD_LAZY + LD_BIND_NOW=1"
LD_BIND_NOW=1 LD_LIBRARY_PATH="$OUT" "$QEMU" -L /usr/aarch64-linux-gnu "$OUT/bridge_harness" "$OUT/libprobe.so" lazy
echo "PASS: bridge-check (f32 route true in all binding modes)"
