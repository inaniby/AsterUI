#!/bin/sh
# scratch-p5-vec4a-run.sh — P-VEC v4a 最小构建+运行脚本。
# 只编 stdlib + vecuser.ast + driver.ast（不编框架 21 文件），链接后 qemu 跑。
# 用法：tests/cn/scratch-p5-vec4a-run.sh <probe-dir> [out-file]
#   构建产物全在 mktemp 的 OUT 下；只读执行修复树 ./aster，不改修复树、
#   不动 APK 产物、不跑全量门禁。退出码 = 探针驱动的退出码。
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
[ -f "$PROBE/vecuser.ast" ] || { echo "no vecuser.ast in $PROBE" >&2; exit 2; }
OUT=$(mktemp -d /tmp/p5-run.XXXXXX)
OBJ="$OUT/obj"
mkdir -p "$OBJ"
echo "build dir: $OUT" >&2
fail() { echo "FAIL: $1" >&2; echo "logs in $OUT" >&2; exit 1; }
for spec in "src/aster_std.ast:std" "vecuser.ast:vecuser"; do
    src=${spec%%:*}; base=${spec#*:}
    case "$src" in
        src/*) path="$FW/$src" ;;
        *) path="$PROBE/$src" ;;
    esac
    "$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$path" -o "$OBJ/$base.o" >"$OBJ/$base.log" 2>&1 \
        || { cat "$OBJ/$base.log" >&2; fail "build-cn-obj $src"; }
    if grep -qi "warning" "$OBJ/$base.log"; then cat "$OBJ/$base.log" >&2; fail "warnings in $src build"; fi
done
"$ASTER" build-cn-obj --project "$PROBE/aster.proj" --language en "$PROBE/driver.ast" -o "$OBJ/driver.o" >"$OBJ/driver.log" 2>&1 \
    || { cat "$OBJ/driver.log" >&2; fail "build-cn-obj driver.ast"; }
if grep -qi "warning" "$OBJ/driver.log"; then cat "$OBJ/driver.log" >&2; fail "warnings in driver build"; fi
# shellcheck disable=SC2086
"$ASTER" link-obj "$OBJ/driver.o" "$OBJ/vecuser.o" "$OBJ/std.o" -o "$OUT/run" >"$OUT/link.log" 2>&1 \
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
