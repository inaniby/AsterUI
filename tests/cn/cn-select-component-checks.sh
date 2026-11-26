#!/bin/sh
# tests/cn/cn-select-component-checks.sh — Select 类试点套件（P3 恢复轮）。
#
# 三探针（设计见 phase1-p3-select.md §6；一处设计纠正见下）：
#   [1/3] 编译探针 + B26 回归钉子：select.ast / 16 拆分框架文件 /
#         aster_std.ast 各以 --project 构建，rc=0、0 警告（修复前三者
#         全败于 B26 alloc 错）；符号断言见下。
#   [2/3] 三分支探针（headless 点按）：点触发器 130 → is_open()==1；
#         点选项 133 → value()==2 且 is_open()==0；再点触发器 →
#         is_open()==1；点外部 → is_open()==0。退出码 1/2/3/4 区分。
#   [3/3] sync 探针：sync(1) → 1；sync(2) → 2；点开后 sync(0) → 0
#         且 is_open()==1（sync 不碰 open）。退出码 11/12/13 区分。
#
# 设计纠正（§6 写错，实测为准）：类工厂符号是
# __aster_cn_new_class_53656c656374（53656c656374 = "Select" 的 hex），
# 不是 __aster_cn_new_class_Select。g_lang_select 是 8 字节指针全局（BSS）。
#
# 探针机理（两次亲测的教训，勿改回）：
#   - 驱动 tests/cn/select-probe/select_probe.ast 必须列进它自己的
#     探针工程 tests/cn/select-probe/aster.proj：P0-1 零声明可见只在
#     同工程文件间成立。驱动不在工程内时 g_lang_select 裸引用报
#     [A-099] unknown variable；写 extern let g_lang_select: Select
#     又报 [A-060]（后端不支持类类型的 extern let）。
#   - 列进工程后，驱动不得再 extern 声明 std 的 write_all/strlen：
#     它们的定义是 ptr<u8> 参数，与驱动的 ptr 声明签名不一致，报
#     [A-030]。驱动不打印，退出码即 verdict。
#   - 驱动观测类本身（g_lang_select.is_open()/value()），不是框架的
#     aui_select_value——类接线断了时框架状态仍可能正常。
# [2/3] 与 [3/3] 跑同一个探针二进制（先分支后 sync）；退出码归属：
# 0 = 两者皆过；1/2/3/4/5/92 = [2/3] 败、[3/3] 未跑（SKIP）；
# 11/12/13 = [2/3] 过、[3/3] 败；90/91 = 环境失败，两者皆败。
set -eu
FW=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ASTER_BIN=${ASTER_BIN:-$HOME/workspace/projects/Aster/aster}
if [ ! -x "$ASTER_BIN" ]; then
    echo "set ASTER_BIN to a built Aster executable" >&2
    exit 2
fi
RUNNER=${RUNNER:-$HOME/workspace/projects/Aster-cn-s1s2-fix/tests/run-aarch64.sh}
if [ "$(uname -m)" = aarch64 ] || [ "$(uname -m)" = arm64 ] \
    || command -v qemu-aarch64 >/dev/null 2>&1; then
    CAN_RUN=1
else
    CAN_RUN=0
fi
command -v readelf >/dev/null 2>&1 || { echo "readelf not in PATH" >&2; exit 2; }

GALLERY_EN="$FW/examples/gallery-en"
PROBE_PROJ="$FW/tests/cn/select-probe/aster.proj"
PROBE_SRC="$FW/tests/cn/select-probe/select_probe.ast"
OUT=$(mktemp -d /tmp/cn-select-component-checks.XXXXXX)
trap 'rm -rf "$OUT"' EXIT HUP INT TERM
mkdir -p "$OUT/obj"
NFAIL=0
NSKIP=0

warn_count() { grep -ci warn "$OUT/obj"/*.log 2>/dev/null | awk -F: '{s+=$2} END{print s+0}'; }

# [1/3] 编译探针 + B26 回归钉子。
echo "[1/3] B26 regression: class + declared alloc in one project builds"
for spec in "src/select.ast:select" "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/aster_std.ast:std" "src/aui_spec.ast:aui_spec"; do
    src=${spec%%:*}; base=${spec#*:}
    if ! "$ASTER_BIN" build-cn-obj --project "$GALLERY_EN/aster.proj" --language en \
            "$FW/$src" -o "$OUT/obj/$base.o" >"$OUT/obj/$base.log" 2>&1; then
        echo "FAIL [1/3]: build-cn-obj --project $src"; cat "$OUT/obj/$base.log" >&2; NFAIL=$((NFAIL+1))
    fi
done
if [ "$NFAIL" = 0 ] && [ "$(warn_count)" != 0 ]; then
    echo "FAIL [1/3]: $(warn_count) warnings in build logs"; NFAIL=$((NFAIL+1))
fi
if [ "$NFAIL" = 0 ]; then
    SYM="$OUT/obj/select.o"
    if ! readelf -sW "$SYM" | grep -q 'FUNC.*GLOBAL.* 1 __aster_cn_new_class_53656c656374$'; then
        echo "FAIL [1/3]: factory __aster_cn_new_class_53656c656374 not a defined global FUNC"; NFAIL=$((NFAIL+1))
    fi
    if ! readelf -sW "$SYM" | grep -q 'OBJECT.*GLOBAL.* 2 g_lang_select$'; then
        echo "FAIL [1/3]: g_lang_select not a defined global OBJECT (BSS)"; NFAIL=$((NFAIL+1))
    fi
    if ! readelf -sW "$SYM" | grep -q 'FUNC.*GLOBAL.* 1 on_select_event$'; then
        echo "FAIL [1/3]: on_select_event trampoline not a defined global FUNC"; NFAIL=$((NFAIL+1))
    fi
    n_und=$(readelf -sW "$SYM" | grep -c ' UND .*aui_' || true)
    n_spec=$(readelf -sW "$SYM" | grep -c ' UND .*aui_spec_' || true)
    n_def=$(readelf -sW "$SYM" | grep ' aui_' | grep -vc ' UND ' || true)
    # P5 迁移：build() 改走 spec + aui_mount，aui_* UND 由 6 变 11——
    # 旧 3 个（value/reason/invalidate，handle_select）+ 新 8 个
    # aui_spec_*（build 内的 spec 分配器）。aui_select/aui_option/
    # aui_end 不得再出现（细项断言见 cn-spec-checks.sh [1/3]）。
    if [ "$n_und" != 11 ] || [ "$n_spec" != 8 ] || [ "$n_def" != 0 ]; then
        echo "FAIL [1/3]: aui_* refs: UND=$n_und (want 11), aui_spec_=$n_spec (want 8), defined=$n_def (want 0)"; NFAIL=$((NFAIL+1))
    fi
fi
if [ "$NFAIL" = 0 ]; then echo "PASS [1/3] B26 regression + select symbols"; fi

# [2/3] + [3/3] 探针二进制：28 对象（探针工程）+ link + qemu。
if [ "$CAN_RUN" = 0 ]; then
    echo "SKIP [2/3] branches: no qemu/aarch64 to run the probe"
    echo "SKIP [3/3] sync: no qemu/aarch64 to run the probe"
    NSKIP=$((NSKIP+2))
elif [ "$NFAIL" != 0 ]; then
    echo "SKIP [2/3] branches: [1/3] failed"
    echo "SKIP [3/3] sync: [1/3] failed"
    NSKIP=$((NSKIP+2))
else
    for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
                "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
                "assets/embeds.ast:embeds" "src/aster_std.ast:std" \
                "src/aui_spec.ast:aui_spec" "src/select.ast:select" "src/textfield.ast:textfield" "tests/fake_ndk.ast:fake_ndk"; do
        src=${spec%%:*}; base=${spec#*:}
        if ! "$ASTER_BIN" build-cn-obj --project "$PROBE_PROJ" --language en \
                "$FW/$src" -o "$OUT/obj/$base.o" >"$OUT/obj/$base.log" 2>&1; then
            echo "FAIL [2/3]: build-cn-obj $src"; cat "$OUT/obj/$base.log" >&2; NFAIL=$((NFAIL+1))
        fi
    done
    for f in app page_counter page_input page_nav; do
        if ! "$ASTER_BIN" build-cn-obj --project "$PROBE_PROJ" --language en \
                "$GALLERY_EN/src/$f.ast" -o "$OUT/obj/$f.o" >"$OUT/obj/$f.log" 2>&1; then
            echo "FAIL [2/3]: build-cn-obj $f"; cat "$OUT/obj/$f.log" >&2; NFAIL=$((NFAIL+1))
        fi
    done
    if [ "$NFAIL" = 0 ]; then
        if ! "$ASTER_BIN" build-cn-obj --project "$PROBE_PROJ" --language en \
                "$PROBE_SRC" -o "$OUT/obj/select_probe.o" >"$OUT/obj/select_probe.log" 2>&1; then
            echo "FAIL [2/3]: build-cn-obj select_probe"; cat "$OUT/obj/select_probe.log" >&2; NFAIL=$((NFAIL+1))
        fi
    fi
    if [ "$NFAIL" = 0 ] && [ "$(warn_count)" != 0 ]; then
        echo "FAIL [2/3]: $(warn_count) warnings in build logs"; NFAIL=$((NFAIL+1))
    fi
    if [ "$NFAIL" = 0 ]; then
        if ! "$ASTER_BIN" link-obj "$OUT/obj/select_probe.o" "$OUT/obj/app.o" \
                "$OUT/obj/page_counter.o" "$OUT/obj/page_input.o" "$OUT/obj/page_nav.o" \
                "$OUT/obj/select.o" "$OUT/obj/textfield.o" "$OUT/obj/aui_core.o" "$OUT/obj/aui_tables.o" "$OUT/obj/aui_font.o" "$OUT/obj/aui_drawprim.o" "$OUT/obj/aui_log.o" "$OUT/obj/aui_raster.o" "$OUT/obj/aui_build.o" "$OUT/obj/aui_layout.o" "$OUT/obj/aui_paint.o" "$OUT/obj/aui_gesture.o" "$OUT/obj/aui_frame.o" "$OUT/obj/aui_input.o" "$OUT/obj/aui_host.o" "$OUT/obj/aui_api.o" "$OUT/obj/aui_png.o" "$OUT/obj/font_runtime.o" \
                "$OUT/obj/truetype.o" "$OUT/obj/text.o" "$OUT/obj/embeds.o" \
                "$OUT/obj/std.o" "$OUT/obj/aui_spec.o" "$OUT/obj/fake_ndk.o" \
                -o "$OUT/obj/select_probe" >"$OUT/obj/link.log" 2>&1; then
            echo "FAIL [2/3]: link-obj"; cat "$OUT/obj/link.log" >&2; NFAIL=$((NFAIL+1))
        fi
    fi
    if [ "$NFAIL" = 0 ]; then
        rc=0
        if [ "$(uname -m)" = aarch64 ] || [ "$(uname -m)" = arm64 ]; then
            "$OUT/obj/select_probe" >"$OUT/probe.out" 2>"$OUT/probe.err" || rc=$?
        else
            qemu-aarch64 "$OUT/obj/select_probe" >"$OUT/probe.out" 2>"$OUT/probe.err" || rc=$?
        fi
        case "$rc" in
            0)  echo "PASS [2/3] branches: open/select/reopen/outside-close"; echo "PASS [3/3] sync: 1/2/open+sync(0) keeps open" ;;
            1)  echo "FAIL [2/3]: step 1 tap trigger 130 did not open (is_open!=1)" ;;
            2)  echo "FAIL [2/3]: step 2 tap option 133: value!=2 or still open" ;;
            3)  echo "FAIL [2/3]: step 3 tap trigger again did not reopen" ;;
            4)  echo "FAIL [2/3]: step 4 tap outside did not close (is_open!=0)" ;;
            5)  echo "FAIL [2/3]: initial state: value!=0 or is_open!=0" ;;
            92) echo "FAIL [2/3]: tap target has no rect" ;;
            11) echo "PASS [2/3] branches"; echo "FAIL [3/3]: sync(1) did not give value 1" ;;
            12) echo "PASS [2/3] branches"; echo "FAIL [3/3]: sync(2) did not give value 2" ;;
            13) echo "PASS [2/3] branches"; echo "FAIL [3/3]: sync(0) after open: value!=0 or open lost" ;;
            90) echo "FAIL [2/3]+[3/3]: font load failed" ;;
            91) echo "FAIL [2/3]+[3/3]: headless render failed" ;;
            *)  echo "FAIL [2/3]+[3/3]: probe exit $rc" ;;
        esac
        case "$rc" in
            0) ;;
            11|12|13) NFAIL=$((NFAIL+1)) ;;
            90|91) NFAIL=$((NFAIL+2)) ;;
            *) NFAIL=$((NFAIL+1)); echo "SKIP [3/3] sync: branches did not pass"; NSKIP=$((NSKIP+1)) ;;
        esac
    fi
fi

if [ "$NFAIL" = 0 ]; then
    echo "PASS: cn-select-component checks ([1/3] compile + [2/3] branches + [3/3] sync)"
    exit 0
else
    echo "cn-select-component checks: $NFAIL failed, $NSKIP skipped (logs in $OUT)"
    exit 1
fi
