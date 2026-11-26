#!/bin/sh
# run.sh — 回归探针：跑驱动、与 baseline.snapshot 逐字节比对。
# 用法：tests/cn/scratch-d2a-noregress/run.sh
# 退出 0 = 快照逐字节一致；非 0 = 不一致或探针失败。
set -u
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=$(mktemp /tmp/d2a-noregress.out.XXXXXX)
"$DIR/../scratch-d2a-run.sh" "$DIR" "$OUT" || { echo "FAIL: probe run failed" >&2; exit 1; }
if cmp -s "$OUT" "$DIR/baseline.snapshot"; then
    echo "noregress: snapshot byte-identical to baseline"
    exit 0
else
    echo "FAIL: snapshot differs from baseline" >&2
    diff "$DIR/baseline.snapshot" "$OUT" >&2
    exit 1
fi
