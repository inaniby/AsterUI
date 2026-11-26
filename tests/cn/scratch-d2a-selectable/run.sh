#!/bin/sh
# run.sh — aui_selectable 探针：退出 0 = 通过。
set -u
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$DIR/../scratch-d2a-run.sh" "$DIR" || exit 1
echo "selectable: PASS"
exit 0
