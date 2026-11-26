#!/bin/sh
# scratch-p5-order-run.sh — P 顺序探针构建+运行脚本（与 scratch-p5-run.sh 同构，另编 early/aux/late 三文件）。
# 用法：tests/cn/scratch-p5-order-run.sh <probe-dir> [out-file]
#   probe-dir：tests/cn/scratch-p5-*/（内含 driver.ast）。
#   构建产物全在 mktemp 的 OUT 下；只读执行修复树 ./aster，不改修复树、
#   不动 APK 产物、不跑全量门禁。退出码 = 探针驱动的退出码。
#   构建日志（stderr 含警告即失败，见下）留在 OUT/build.log。
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
[ -f /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc ] || { echo "VM lacks NotoSansCJK font" >&2; exit 2; }
OUT=$(mktemp -d /tmp/p5-run.XXXXXX)
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
for spec in "early.ast:early" "aux.ast:aux" "late.ast:late"; do
    src=${spec%%:*}; base=${spec#*:}
    "$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$PROBE/$src" -o "$OBJ/$base.o" >"$OBJ/$base.log" 2>&1 \
        || { cat "$OBJ/$base.log" >&2; fail "build-cn-obj $src"; }
    if grep -qi "warning" "$OBJ/$base.log"; then cat "$OBJ/$base.log" >&2; fail "warnings in $src build"; fi
done
"$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$PROBE/driver.ast" -o "$OBJ/driver.o" >"$OBJ/driver.log" 2>&1 \
    || { cat "$OBJ/driver.log" >&2; fail "build-cn-obj driver.ast"; }
if grep -qi "warning" "$OBJ/driver.log"; then cat "$OBJ/driver.log" >&2; fail "warnings in driver build"; fi
# shellcheck disable=SC2086
"$ASTER" link-obj "$OBJ/driver.o" "$OBJ/early.o" "$OBJ/aux.o" "$OBJ/late.o" "$OBJ/aui_core.o" "$OBJ/aui_tables.o" "$OBJ/aui_font.o" "$OBJ/aui_drawprim.o" "$OBJ/aui_log.o" "$OBJ/aui_raster.o" "$OBJ/aui_build.o" "$OBJ/aui_layout.o" "$OBJ/aui_paint.o" "$OBJ/aui_gesture.o" "$OBJ/aui_frame.o" "$OBJ/aui_input.o" "$OBJ/aui_host.o" "$OBJ/aui_api.o" "$OBJ/aui_png.o" "$OBJ/font_runtime.o" \
    "$OBJ/truetype.o" "$OBJ/text.o" "$OBJ/embeds.o" "$OBJ/std.o" \
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
