#!/usr/bin/env python3
"""snapshot_diff.py — Phase 1 C 轨：规范快照字段级 Diff（套件侧脚本）。

把现有 `diff -u` 行比对换成字段级 Diff + 变化摘要，不改测试输出格式。
测试照常把 SNAPSHOT 段 / PIXELHASH 行打到 stdout；门禁抓 stdout 后调本脚本
与 tests/baseline/*.snapshot（+.pixels 行）比对。

输入格式（沿用 ui-checks.sh 现有约定）：
  SNAPSHOT <name>
  RECT <key> <x> <y> <w> <h> <color>
  TEXT <key> <x> <y> <len> <text...>
  PIXELHASH <name> <hash>

用法：
  snapshot_diff.py <baseline> <actual> [--label NAME]
  baseline 与 actual 可以是：
    - 单段基线文件（如 tests/baseline/counter-zh.snapshot），或
    - 含多段 SNAPSHOT 的整份测试 stdout（确定性复核 G-SNAP-2 时，
      baseline=第一次运行输出，actual=第二次运行输出）。
  只读：本脚本永不改写基线。基线由 B 轨随测试交付，失配时人工核对后更新。

比对规则：
  - 段：按 SNAPSHOT 名对齐；缺段 / 多段各报一行。
  - 行：按 key 对齐（RECT/TEXT 行的第 2 个字段）；同 key 逐字段比对，
    报 `FIELD <段>/<key>: <字段> 基线=X 实际=Y`；只在一边出现的 key
    报 ADDED / REMOVED；key 顺序变化报 ORDER（一行摘要，不逐行展开）。
  - PIXELHASH：只比 hash 全等；失配报摘要行（不 dump 像素）。
  - 其它行（如 PASS 行、日志）忽略，不参与比对。

退出码：0 完全一致；1 有差异；2 用法/文件错误。
输出末行永远是摘要：`SNAPSHOT-DIFF: <段数> sections, <n> field diffs,
<a> added, <r> removed, <p> pixelhash diffs, <o> order diffs`。
"""

import re
import sys

SNAP_RE = re.compile(r"^SNAPSHOT\s+(\S+)\s*$")
PIXEL_RE = re.compile(r"^PIXELHASH\s+(\S+)\s+(\S+)\s*$")
# RECT key x y w h color / TEXT key x y len text...
ROW_RE = re.compile(r"^(RECT|TEXT)\s+(\S+)\s+(.*?)\s*$")


def parse(text):
    """-> (sections: {name: [(kind, key, fields)]}, pixels: {name: hash})"""
    sections = {}
    pixels = {}
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        m = SNAP_RE.match(line)
        if m:
            current = m.group(1)
            sections.setdefault(current, [])
            continue
        m = PIXEL_RE.match(line)
        if m:
            pixels[m.group(1)] = m.group(2)
            continue
        m = ROW_RE.match(line)
        if m and current is not None:
            kind, key, rest = m.group(1), m.group(2), m.group(3)
            sections[current].append((kind, key, rest.split()))
    return sections, pixels


def diff_sections(baseline, actual, label):
    diffs = []
    field_diffs = added = removed = order_diffs = 0
    for name in sorted(set(baseline) | set(actual)):
        if name not in baseline:
            diffs.append("EXTRA-SECTION %s: only in actual (%d rows)"
                         % (name, len(actual[name])))
            continue
        if name not in actual:
            diffs.append("MISSING-SECTION %s: only in baseline (%d rows)"
                         % (name, len(baseline[name])))
            continue
        # Key rows by (kind, key): RECT and TEXT share node ids — the same
        # key number is legitimately both a RECT (bounds) and a TEXT (label).
        brows = {(kind, k): f for kind, k, f in baseline[name]}
        arows = {(kind, k): f for kind, k, f in actual[name]}
        bkeys = [(kind, k) for kind, k, _ in baseline[name]]
        akeys = [(kind, k) for kind, k, _ in actual[name]]
        if bkeys != akeys:
            order_diffs += 1
            diffs.append("ORDER %s: baseline order %s actual order %s"
                         % (name,
                            ",".join("%s:%s" % kk for kk in bkeys),
                            ",".join("%s:%s" % kk for kk in akeys)))
        for (kind, key) in sorted(set(brows) | set(arows)):
            if (kind, key) not in brows:
                added += 1
                diffs.append("ADDED %s/%s %s: %s"
                             % (name, kind, key, " ".join(arows[(kind, key)])))
                continue
            if (kind, key) not in arows:
                removed += 1
                diffs.append("REMOVED %s/%s %s: %s"
                             % (name, kind, key,
                                " ".join(brows[(kind, key)])))
                continue
            bf = brows[(kind, key)]
            af = arows[(kind, key)]
            n = max(len(bf), len(af))
            for i in range(n):
                bv = bf[i] if i < len(bf) else "<missing>"
                av = af[i] if i < len(af) else "<missing>"
                if bv != av:
                    field_diffs += 1
                    diffs.append("FIELD %s/%s %s: field[%d] baseline=%s actual=%s"
                                 % (name, kind, key, i, bv, av))
    return diffs, field_diffs, added, removed, order_diffs


def main(argv):
    if len(argv) < 3:
        print("usage: snapshot_diff.py <baseline> <actual> [--label NAME]",
              file=sys.stderr)
        return 2
    baseline_path, actual_path = argv[1], argv[2]
    label = ""
    if "--label" in argv:
        i = argv.index("--label")
        if i + 1 < len(argv):
            label = argv[i + 1]
    try:
        with open(baseline_path, encoding="utf-8") as f:
            bsec, bpix = parse(f.read())
        with open(actual_path, encoding="utf-8") as f:
            asec, apix = parse(f.read())
    except OSError as e:
        print("snapshot_diff: cannot read input: %s" % e, file=sys.stderr)
        return 2
    diffs, field_diffs, added, removed, order_diffs = diff_sections(
        bsec, asec, label)
    pix_diffs = 0
    for name in sorted(set(bpix) | set(apix)):
        if name not in bpix:
            diffs.append("EXTRA-PIXELHASH %s: only in actual" % name)
            pix_diffs += 1
        elif name not in apix:
            diffs.append("MISSING-PIXELHASH %s: only in baseline" % name)
            pix_diffs += 1
        elif bpix[name] != apix[name]:
            pix_diffs += 1
            diffs.append("PIXELHASH %s: differs (baseline %s actual %s)"
                         % (name, bpix[name][:8], apix[name][:8]))
    prefix = ("[%s] " % label) if label else ""
    for d in diffs:
        print(prefix + d)
    nsec = len(set(bsec) | set(asec))
    print("%sSNAPSHOT-DIFF: %d sections, %d field diffs, %d added, "
          "%d removed, %d pixelhash diffs, %d order diffs"
          % (prefix, nsec, field_diffs, added, removed, pix_diffs,
             order_diffs))
    return 1 if (diffs or pix_diffs) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
