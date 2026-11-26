#!/bin/sh
# scratch-p6-run.sh — P6 step-0 T-MOUNT probe runner (scratch only).
# Modelled on scratch-p5-run.sh; builds the probe-local aui_spec10.ast
# (aui_spec.ast + kind-10 branch) and textfield.ast in addition to the
# framework objects, links the probe binary, runs it under qemu.
# Usage: tests/cn/scratch-p6-run.sh <probe-dir> [out-file]
#   probe-dir: tests/cn/scratch-p6-mount/ (aster.proj + driver.ast).
#   Build products live in a mktemp dir; read-only use of the fix-tree
#   ./aster; no tree files are modified; no full CI.
set -u
PROBE=${1:-}
OUTFILE=${2:-}
[ -n "$PROBE" ] || { echo "usage: $0 <probe-dir> [out-file]" >&2; exit 2; }
FW=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PROBE=$(CDPATH= cd -- "$PROBE" && pwd)
ASTER=${ASTER:-$HOME/workspace/projects/Aster/aster}
QEMU=${QEMU:-qemu-aarch64}
[ -x "$ASTER" ] || { echo "no aster at $ASTER" >&2; exit 2; }
[ -f "$PROBE/driver.ast" ] || { echo "no driver.ast in $PROBE" >&2; exit 2; }
[ -f "$PROBE/aui_spec10.ast" ] || { echo "no aui_spec10.ast in $PROBE" >&2; exit 2; }
[ -f "$PROBE/textfield.ast" ] || { echo "no textfield.ast in $PROBE" >&2; exit 2; }
[ -f /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc ] || { echo "VM lacks NotoSansCJK font" >&2; exit 2; }
OUT=$(mktemp -d /tmp/p6-run.XXXXXX)
OBJ="$OUT/obj"
mkdir -p "$OBJ"
echo "build dir: $OUT" >&2
fail() { echo "FAIL: $1" >&2; echo "logs in $OUT" >&2; exit 1; }
for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
            "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
            "assets/embeds.ast:embeds" "src/aster_std.ast:std" \
            "tests/fake_ndk.ast:fake_ndk"; do
    src=${spec%%:*}; base=${spec#*:}
    "$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$FW/$src" -o "$OBJ/$base.o" >"$OBJ/$base.log" 2>&1 \
        || { cat "$OBJ/$base.log" >&2; fail "build-cn-obj $src"; }
    if grep -qi "warning" "$OBJ/$base.log"; then cat "$OBJ/$base.log" >&2; fail "warnings in $src build"; fi
done
for spec in "aui_spec10.ast:aui_spec10" "textfield.ast:textfield" "driver.ast:driver"; do
    src=${spec%%:*}; base=${spec#*:}
    "$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$PROBE/$src" -o "$OBJ/$base.o" >"$OBJ/$base.log" 2>&1 \
        || { cat "$OBJ/$base.log" >&2; fail "build-cn-obj $src"; }
    if grep -qi "warning" "$OBJ/$base.log"; then cat "$OBJ/$base.log" >&2; fail "warnings in $src build"; fi
done
# shellcheck disable=SC2086
"$ASTER" link-obj "$OBJ/driver.o" "$OBJ/aui_core.o" "$OBJ/aui_tables.o" "$OBJ/aui_font.o" "$OBJ/aui_drawprim.o" "$OBJ/aui_log.o" "$OBJ/aui_raster.o" "$OBJ/aui_build.o" "$OBJ/aui_layout.o" "$OBJ/aui_paint.o" "$OBJ/aui_gesture.o" "$OBJ/aui_frame.o" "$OBJ/aui_input.o" "$OBJ/aui_host.o" "$OBJ/aui_api.o" "$OBJ/aui_png.o" "$OBJ/font_runtime.o" \
    "$OBJ/truetype.o" "$OBJ/text.o" "$OBJ/embeds.o" "$OBJ/std.o" \
    "$OBJ/aui_spec10.o" "$OBJ/textfield.o" \
    "$OBJ/fake_ndk.o" -o "$OUT/run" >"$OUT/link.log" 2>&1 \
    || { cat "$OUT/link.log" >&2; fail "link-obj"; }
if [ -n "$OUTFILE" ]; then
    "$QEMU" "$OUT/run" >"$OUTFILE" 2>"$OUT/qemu.err"
else
    "$QEMU" "$OUT/run" 2>"$OUT/qemu.err"
fi
rc=$?
if [ $rc -ne 0 ]; then cat "$OUT/qemu.err" >&2; echo "probe exit $rc (build dir $OUT)" >&2; exit $rc; fi
echo "probe exit 0 (build dir $OUT)" >&2
exit 0
