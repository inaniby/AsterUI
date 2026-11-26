#!/bin/sh
# scratch-p5-spec1-run.sh — P5 step-1 smoke runner (aui_spec.ast after aster_std).
# Builds framework + aui_spec + driver from the probe project, links, runs.
# Usage: tests/cn/scratch-p5-spec1-run.sh [out-file]
set -u
OUTFILE=${1:-}
FW=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PROBE="$FW/tests/cn/scratch-p5-spec1"
ASTER=${ASTER:-$HOME/workspace/projects/Aster/aster}
QEMU=${QEMU:-qemu-aarch64}
[ -x "$ASTER" ] || { echo "no aster at $ASTER" >&2; exit 2; }
OUT=$(mktemp -d /tmp/p5-spec1.XXXXXX)
OBJ="$OUT/obj"
mkdir -p "$OBJ"
echo "build dir: $OUT" >&2
fail() { echo "FAIL: $1" >&2; echo "logs in $OUT" >&2; exit 1; }
for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
            "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
            "assets/embeds.ast:embeds" "src/aster_std.ast:std" "src/aui_spec.ast:aui_spec" \
            "tests/fake_ndk.ast:fake_ndk"; do
    src=${spec%%:*}; base=${spec#*:}
    "$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$FW/$src" -o "$OBJ/$base.o" >"$OBJ/$base.log" 2>&1 \
        || { cat "$OBJ/$base.log" >&2; fail "build-cn-obj $src"; }
    if grep -qi "warning" "$OBJ/$base.log"; then cat "$OBJ/$base.log" >&2; fail "warnings in $src build"; fi
done
"$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$PROBE/driver.ast" -o "$OBJ/driver.o" >"$OBJ/driver.log" 2>&1 \
    || { cat "$OBJ/driver.log" >&2; fail "build-cn-obj driver.ast"; }
if grep -qi "warning" "$OBJ/driver.log"; then cat "$OBJ/driver.log" >&2; fail "warnings in driver build"; fi
# shellcheck disable=SC2086
"$ASTER" link-obj "$OBJ/driver.o" "$OBJ/aui_spec.o" "$OBJ/aui_core.o" "$OBJ/aui_tables.o" "$OBJ/aui_font.o" "$OBJ/aui_drawprim.o" "$OBJ/aui_log.o" "$OBJ/aui_raster.o" "$OBJ/aui_build.o" "$OBJ/aui_layout.o" "$OBJ/aui_paint.o" "$OBJ/aui_gesture.o" "$OBJ/aui_frame.o" "$OBJ/aui_input.o" "$OBJ/aui_host.o" "$OBJ/aui_api.o" "$OBJ/aui_png.o" "$OBJ/font_runtime.o" \
    "$OBJ/truetype.o" "$OBJ/text.o" "$OBJ/embeds.o" "$OBJ/std.o" \
    "$OBJ/fake_ndk.o" -o "$OUT/run" >"$OUT/link.log" 2>&1 \
    || { cat "$OUT/link.log" >&2; fail "link-obj"; }
if [ -n "$OUTFILE" ]; then
    "$QEMU" "$OUT/run" >"$OUTFILE" 2>"$OUT/qemu.err"
else
    "$QEMU" "$OUT/run" 2>"$OUT/qemu.err"
fi
rc=$?
echo "probe exit $rc (build dir $OUT)" >&2
exit $rc
