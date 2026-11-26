#!/bin/sh
# run.sh — aui_size 探针：退出 0 = 通过。
set -u
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$DIR/../scratch-d2a-run.sh" "$DIR" || exit 1
echo "size: PASS"
exit 0
