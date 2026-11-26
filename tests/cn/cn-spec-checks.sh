#!/bin/sh
# tests/cn/cn-spec-checks.sh — ViewSpec (D-2b, P5) 套件。
#
#   [1/3] 编译探针：aui_spec.ast / select.ast / 16 拆分框架文件 /
#         aster_std.ast 各以 --project 构建，rc=0、0 警告；符号断言见下。
#         另断言 select.o 不再直接引用 aui_select/aui_option/aui_end
#         （build() 改走 spec + aui_mount 后只剩 3 个非 spec 的 aui_*
#         引用：value/reason/invalidate，另加 8 个 aui_spec_* 引用）。
#   [2/3] dump + mount + 生长 + 校验（探针驱动退出码 + stdout 比对）：
#         同一 spec 两次 dump 逐字节相同；dump 与套件内预期文本逐字节
#         相同；生长 != -1 时 mount 报 114（框架未提供 aui_grow）；
#         校验失败（种非法 110、键 0 是 111、种 26 带事件 113、无事件
#         的种 25 是 113）不发射任何节点；过期 spec 挂载报 115。
#   [3/3] 修饰/布局值挂载（同一探针二进制的渲染段 + stdout 比对）：
#         尺寸 120x40、前景色 -65536、长按选中 1 经 aui_debug_d2a 读回；
#         字号 12 在 kind 25 上不生效（text_sp 仍 -1，D2A-SCHEMA §2.5
#         的种门）；权重 1 的 select 在列里拿剩余高（RECT h > 400，
#         对照无权重 < 200）；对齐 1 的 select 在行里居中（y 大于 label，
#         对照无对齐 y 相等）；背景 token 2 经 aui_theme_color 解析后
#         的像素与命令式 aui_bg(aui_theme_color(2)) 对照逐哈希相等。
#
# 探针机理（与 cn-select-component-checks.sh 同款，勿改回）：
#   - 驱动 tests/cn/spec-probe/spec_probe.ast 必须列进它自己的
#     探针工程 tests/cn/spec-probe/aster.proj：P0-1 零声明可见只在
#     同工程文件间成立。驱动不在工程内时 g_lang_select 裸引用报
#     [A-099]；写 extern let g_lang_select: Select 又报 [A-060]。
#   - 列进工程后，驱动的 std extern 声明须与 stdlib 定义一字不差
#     （write_all/fmt_i32/fmt_i64/strlen 均为 ptr<u8> 参数），否则
#     报 [A-030]。
# [2/3] 与 [3/3] 跑同一个探针二进制；退出码归属：
# 0 = 两者皆过；12/13/14/15/16/17/18/19/40/41/42/43 = [2/3] 败、
# [3/3] 未跑（SKIP）；30/31/32/33/34/35/50 = [2/3] 过、[3/3] 败；
# 90/91 = 环境失败，两者皆败。
set -eu
FW=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ASTER_BIN=${ASTER_BIN:-$HOME/workspace/projects/Aster/aster}
if [ ! -x "$ASTER_BIN" ]; then
    echo "set ASTER_BIN to a built Aster executable" >&2
    exit 2
fi
if [ "$(uname -m)" = aarch64 ] || [ "$(uname -m)" = arm64 ] \
    || command -v qemu-aarch64 >/dev/null 2>&1; then
    CAN_RUN=1
else
    CAN_RUN=0
fi
command -v readelf >/dev/null 2>&1 || { echo "readelf not in PATH" >&2; exit 2; }

GALLERY_EN="$FW/examples/gallery-en"
PROBE_PROJ="$FW/tests/cn/spec-probe/aster.proj"
PROBE_SRC="$FW/tests/cn/spec-probe/spec_probe.ast"
OUT=$(mktemp -d /tmp/cn-spec-checks.XXXXXX)
trap 'rm -rf "$OUT"' EXIT HUP INT TERM
mkdir -p "$OUT/obj"
NFAIL=0
NSKIP=0

warn_count() { grep -ci warn "$OUT/obj"/*.log 2>/dev/null | awk -F: '{s+=$2} END{print s+0}'; }

# [1/3] 编译探针。
echo "[1/3] compile: aui_spec + select + 16 framework files + std"
for spec in "src/aui_spec.ast:aui_spec" "src/select.ast:select" "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/aster_std.ast:std"; do
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
    SYM="$OUT/obj/aui_spec.o"
    for fn in aui_mount aui_spec_dump aui_spec_new_view aui_spec_new_views aui_spec_new_head aui_spec_new_mod aui_spec_new_lay aui_spec_new_evt aui_spec_new_selparam aui_spec_new_optparam aui_spec_new_size; do
        if ! readelf -sW "$SYM" | grep -q "FUNC.*GLOBAL.* $fn\$"; then
            echo "FAIL [1/3]: $fn not a defined global FUNC in aui_spec.o"; NFAIL=$((NFAIL+1))
        fi
    done
    SSEL="$OUT/obj/select.o"
    n_und=$(readelf -sW "$SSEL" | grep -c ' UND .*aui_' || true)
    n_spec=$(readelf -sW "$SSEL" | grep -c ' UND .*aui_spec_' || true)
    if [ "$n_und" != 11 ] || [ "$n_spec" != 8 ]; then
        echo "FAIL [1/3]: select.o aui_* UND refs: total=$n_und (want 11), aui_spec_=$n_spec (want 8)"; NFAIL=$((NFAIL+1))
    fi
    for kept in aui_select_value aui_select_reason aui_invalidate; do
        if ! readelf -sW "$SSEL" | grep -q " UND .*$kept\$"; then
            echo "FAIL [1/3]: select.o lost expected $kept reference (handle_select)"; NFAIL=$((NFAIL+1))
        fi
    done
    for gone in aui_select aui_option aui_end; do
        if readelf -sW "$SSEL" | grep -q " UND .*$gone\$"; then
            echo "FAIL [1/3]: select.o still references $gone (build should go through spec)"; NFAIL=$((NFAIL+1))
        fi
    done
fi
if [ "$NFAIL" = 0 ]; then echo "PASS [1/3] compile + aui_spec/select symbols"; fi

# [2/3] + [3/3] 探针二进制：28 对象（探针工程）+ link + qemu。
if [ "$CAN_RUN" = 0 ]; then
    echo "SKIP [2/3] dump/mount/grow/validate: no qemu/aarch64 to run the probe"
    echo "SKIP [3/3] modifiers/layout: no qemu/aarch64 to run the probe"
    NSKIP=$((NSKIP+2))
elif [ "$NFAIL" != 0 ]; then
    echo "SKIP [2/3] dump/mount/grow/validate: [1/3] failed"
    echo "SKIP [3/3] modifiers/layout: [1/3] failed"
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
    if [ "$NFAIL" = 0 ]; then
        if ! "$ASTER_BIN" build-cn-obj --project "$PROBE_PROJ" --language en \
                "$PROBE_SRC" -o "$OUT/obj/spec_probe.o" >"$OUT/obj/spec_probe.log" 2>&1; then
            echo "FAIL [2/3]: build-cn-obj spec_probe"; cat "$OUT/obj/spec_probe.log" >&2; NFAIL=$((NFAIL+1))
        fi
    fi
    if [ "$NFAIL" = 0 ] && [ "$(warn_count)" != 0 ]; then
        echo "FAIL [2/3]: $(warn_count) warnings in build logs"; NFAIL=$((NFAIL+1))
    fi
    if [ "$NFAIL" = 0 ]; then
        if ! "$ASTER_BIN" link-obj "$OUT/obj/spec_probe.o" \
                "$OUT/obj/select.o" "$OUT/obj/textfield.o" "$OUT/obj/aui_spec.o" "$OUT/obj/aui_core.o" "$OUT/obj/aui_tables.o" "$OUT/obj/aui_font.o" "$OUT/obj/aui_drawprim.o" "$OUT/obj/aui_log.o" "$OUT/obj/aui_raster.o" "$OUT/obj/aui_build.o" "$OUT/obj/aui_layout.o" "$OUT/obj/aui_paint.o" "$OUT/obj/aui_gesture.o" "$OUT/obj/aui_frame.o" "$OUT/obj/aui_input.o" "$OUT/obj/aui_host.o" "$OUT/obj/aui_api.o" "$OUT/obj/aui_png.o" "$OUT/obj/font_runtime.o" \
                "$OUT/obj/truetype.o" "$OUT/obj/text.o" "$OUT/obj/embeds.o" \
                "$OUT/obj/std.o" "$OUT/obj/fake_ndk.o" \
                -o "$OUT/obj/spec_probe" >"$OUT/obj/link.log" 2>&1; then
            echo "FAIL [2/3]: link-obj"; cat "$OUT/obj/link.log" >&2; NFAIL=$((NFAIL+1))
        fi
    fi
    if [ "$NFAIL" = 0 ]; then
        rc=0
        if [ "$(uname -m)" = aarch64 ] || [ "$(uname -m)" = arm64 ]; then
            "$OUT/obj/spec_probe" >"$OUT/probe.out" 2>"$OUT/probe.err" || rc=$?
        else
            qemu-aarch64 "$OUT/obj/spec_probe" >"$OUT/probe.out" 2>"$OUT/probe.err" || rc=$?
        fi
        cp "$OUT/probe.out" "$OUT/probe.out.saved"
        case "$rc" in
            0)  echo "PASS [2/3] dump/mount/grow/validate (probe exit 0)" ;;
            12) echo "FAIL [2/3]: dump did not print 4 lines" ;;
            13) echo "FAIL [2/3]: mount of valid Select spec failed" ;;
            14|15) echo "FAIL [2/3]: node count after mount wrong (emit or no-emit-on-fail)" ;;
            16|17) echo "FAIL [2/3]: stale spec mount did not report 115" ;;
            18|19) echo "FAIL [2/3]: grow spec mount did not report 114 (框架未提供 aui_grow)" ;;
            40) echo "FAIL [2/3]: kind-0 spec mount did not report 110" ;;
            41) echo "FAIL [2/3]: key-0 spec mount did not report 111" ;;
            42) echo "FAIL [2/3]: option-with-event mount did not report 113" ;;
            43) echo "FAIL [2/3]: event-less select mount did not report 113" ;;
            30) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: d2a read-back mismatch (size/fg/text_sp/sel)" ;;
            31) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: weighted select rect height <= 400" ;;
            32) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: plain select rect height >= 200 (weight control)" ;;
            33) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: plain select d2a not all-default" ;;
            34) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: align=1 select not centered in row" ;;
            35) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: align-less select y != label y (control)" ;;
            50) echo "PASS [2/3] dump/mount/grow/validate"; echo "FAIL [3/3]: bg-token mount hash != imperative aui_theme_color(2) hash" ;;
            90) echo "FAIL [2/3]+[3/3]: font load failed" ;;
            91) echo "FAIL [2/3]+[3/3]: headless render failed" ;;
            *)  echo "FAIL [2/3]+[3/3]: probe exit $rc" ;;
        esac
        case "$rc" in
            0) ;;
            30|31|32|33|34|35|50) NFAIL=$((NFAIL+1)) ;;
            90|91) NFAIL=$((NFAIL+2)) ;;
            *) NFAIL=$((NFAIL+1)); echo "SKIP [3/3] modifiers/layout: [2/3] did not pass"; NSKIP=$((NSKIP+1)) ;;
        esac
        # stdout 比对（只在探针退出 0 时做；任一失败即 [2/3]/[3/3] 失败）。
        if [ "$rc" = 0 ]; then
            sed -n '1,4p' "$OUT/probe.out" >"$OUT/dump1.txt"
            sed -n '5,8p' "$OUT/probe.out" >"$OUT/dump2.txt"
            cat >"$OUT/expected.txt" <<'EOF'
SPEC 0 种=25 名=语言 键=130 修饰=- 布局值=- 事件=[种=2 闭包=1] 参数=[选中=0 打开=0 占位=Choose a language] 子=3
SPEC 1 种=26 名=选项0 键=131 修饰=- 布局值=- 事件=- 参数=[文本=English] 子=0
SPEC 1 种=26 名=选项1 键=132 修饰=- 布局值=- 事件=- 参数=[文本=German] 子=0
SPEC 1 种=26 名=选项2 键=133 修饰=- 布局值=- 事件=- 参数=[文本=Chinese] 子=0
EOF
            if ! cmp -s "$OUT/dump1.txt" "$OUT/dump2.txt"; then
                echo "FAIL [2/3]: same spec dumped twice differs"; NFAIL=$((NFAIL+1))
            elif ! cmp -s "$OUT/dump1.txt" "$OUT/expected.txt"; then
                echo "FAIL [2/3]: dump != expected text"; diff "$OUT/expected.txt" "$OUT/dump1.txt" >&2; NFAIL=$((NFAIL+1))
            else
                echo "PASS [2/3] dump: twice identical + matches expected text"
            fi
            if ! grep -q '生长=1' "$OUT/probe.out"; then
                echo "FAIL [2/3]: grow dump line missing 生长=1"; NFAIL=$((NFAIL+1))
            fi
            h20=$(awk '$1=="HASH20"{print $2}' "$OUT/probe.out")
            h21=$(awk '$1=="HASH21"{print $2}' "$OUT/probe.out")
            if [ -z "$h20" ] || [ -z "$h21" ]; then
                echo "FAIL [3/3]: HASH20/HASH21 lines missing"; NFAIL=$((NFAIL+1))
            elif [ "$h20" != "$h21" ]; then
                echo "FAIL [3/3]: bg-token mount hash ($h20) != imperative hash ($h21)"; NFAIL=$((NFAIL+1))
            else
                echo "PASS [3/3] modifiers/layout: d2a + rects + bg hash ($h20)"
            fi
            echo "--- probe stdout (D2A/RECT/HASH lines):"
            grep -E '^(D2A10|RECT1[01]|Y1[23]|HASH2[01]) ' "$OUT/probe.out" || true
        fi
        # 保留一份探针输出供复核（OUT 为 mktemp，trap 会删；拷到调用方可见处由调用方做）。
        cp "$OUT/probe.out" /tmp/cn-spec-checks-probe.out 2>/dev/null || true
    fi
fi

if [ "$NFAIL" = 0 ]; then
    echo "PASS: cn-spec checks ([1/3] compile + [2/3] dump/mount/grow/validate + [3/3] modifiers/layout)"
    exit 0
else
    echo "cn-spec checks: $NFAIL failed, $NSKIP skipped (logs in $OUT)"
    exit 1
fi
