#!/bin/sh
# tests/cn/cn-textfield-checks.sh — TextField 类试点套件（P6）。
#
#   [1/3] 编译探针：textfield.ast / aui_spec.ast / select.ast / 16 拆分
#         框架文件 / aster_std.ast 各以 --project 构建，rc=0、0 警告；
#         符号断言见下。任一 TU 带 --project 构建即 P3 §6 的 B26 对照
#         （alloc 错的回归钉子）。
#         符号断言：g_text_field（OBJECT 全局）在 textfield.o 内；
#         __aster_cn_new_class_546578744669656c64（546578744669656c64 =
#         "TextField" 的 hex，P3 恢复轮 §5 的教训：工厂名是 hex 不是
#         明文）在 textfield.o 内已定义全局函数；
#         aui_spec_new_textparam 在 aui_spec.o 内已定义全局函数；
#         textfield.o 的 aui_* UND 引用仅 2 个（aui_text_value、
#         aui_spec_new_textparam），不得直接引用 aui_text_field
#         （build 走 spec + aui_mount）。
#   [2/3] dump + mount 等价 + 校验（探针驱动退出码 + stdout 比对）：
#         同一 spec 两次 dump 逐字节相同；dump 与套件内预期文本逐字节
#         相同（en 行 + zh 行）；mount 与命令式对照逐项相等（节点数、
#         RECT、文本池槽指针、PIXELHASH，见驱动退出码 13/14/15/16/17）；
#         校验失败不发射（事件非空 113、参数为空 112、子非空 112、
#         过期 115）。
#   [3/3] 渲染观测 + 受控值读回 + 聚焦（同一探针二进制的后段 + stdout
#         比对）：aui_text_append(110, …) 写入后 value() 读回逐字节
#         相同；aui_text_clear(110) 后 value() 为空串；aui_focus(110)
#         后 aui_focus_get() == 110 且 value 仍可读（焦点不影响文本池）。
#         headless 下无真实按键注入，打字用框架 aui_text_append 模拟
#         （tests/cjk_test.ast:114-115 已有先例）；真实键盘打字留给
#         真机复验。
#
# 探针机理（与 cn-spec-checks.sh 同款，勿改回）：
#   - 驱动 tests/cn/textfield-probe/textfield_probe.ast 必须列进它自己
#     的探针工程 tests/cn/textfield-probe/aster.proj：P0-1 零声明可见只在
#     同工程文件间成立。驱动不在工程内时 g_text_field 裸引用报
#     [A-099]；写 extern let g_text_field: TextField 又报 [A-060]。
#   - 列进工程后，驱动的 std extern 声明须与 stdlib 定义一字不差
#     （write_all/fmt_i32/fmt_i64/strlen 均为 ptr<u8> 参数），否则
#     报 [A-030]。
# [2/3] 与 [3/3] 跑同一个探针二进制；退出码归属：
# 0 = 两者皆过；11/12/13/14/15/16/17/20/21/22/23/24/32 = [2/3] 败、
# [3/3] 未跑（SKIP）；30/31 = [2/3] 过、[3/3] 败；
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
PROBE_PROJ="$FW/tests/cn/textfield-probe/aster.proj"
PROBE_SRC="$FW/tests/cn/textfield-probe/textfield_probe.ast"
OUT=$(mktemp -d /tmp/cn-textfield-checks.XXXXXX)
trap 'rm -rf "$OUT"' EXIT HUP INT TERM
mkdir -p "$OUT/obj"
NFAIL=0
NSKIP=0

warn_count() { grep -ci warn "$OUT/obj"/*.log 2>/dev/null | awk -F: '{s+=$2} END{print s+0}'; }

# [1/3] 编译探针（B26 钉子：全部带 --project 构建）。
echo "[1/3] compile: textfield + aui_spec + select + 16 framework files + std"
for spec in "src/textfield.ast:textfield" "src/aui_spec.ast:aui_spec" "src/select.ast:select" "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/aster_std.ast:std"; do
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
    if ! readelf -sW "$OUT/obj/aui_spec.o" | grep -q "FUNC.*GLOBAL.* aui_spec_new_textparam\$"; then
        echo "FAIL [1/3]: aui_spec_new_textparam not a defined global FUNC in aui_spec.o"; NFAIL=$((NFAIL+1))
    fi
    if ! readelf -sW "$OUT/obj/textfield.o" | grep -q "OBJECT.*GLOBAL.* g_text_field\$"; then
        echo "FAIL [1/3]: g_text_field not a defined global OBJECT in textfield.o"; NFAIL=$((NFAIL+1))
    fi
    if ! readelf -sW "$OUT/obj/textfield.o" | grep -q "FUNC.*GLOBAL.* __aster_cn_new_class_546578744669656c64\$"; then
        echo "FAIL [1/3]: __aster_cn_new_class_546578744669656c64 not a defined global FUNC in textfield.o"; NFAIL=$((NFAIL+1))
    fi
    TF="$OUT/obj/textfield.o"
    n_und=$(readelf -sW "$TF" | grep -c ' UND .*aui_' || true)
    if [ "$n_und" != 2 ]; then
        echo "FAIL [1/3]: textfield.o aui_* UND refs: total=$n_und (want 2)"; NFAIL=$((NFAIL+1))
    fi
    for kept in aui_text_value aui_spec_new_textparam; do
        if ! readelf -sW "$TF" | grep -q " UND .*$kept\$"; then
            echo "FAIL [1/3]: textfield.o lost expected $kept reference"; NFAIL=$((NFAIL+1))
        fi
    done
    if readelf -sW "$TF" | grep -q " UND .*aui_text_field\$"; then
        echo "FAIL [1/3]: textfield.o still references aui_text_field (build should go through spec)"; NFAIL=$((NFAIL+1))
    fi
fi
if [ "$NFAIL" = 0 ]; then echo "PASS [1/3] compile + textfield/aui_spec symbols (B26 nail: --project builds)"; fi

# [2/3] + [3/3] 探针二进制：24 对象（探针工程）+ link + qemu。
if [ "$CAN_RUN" = 0 ]; then
    echo "SKIP [2/3] dump/mount/validate: no qemu/aarch64 to run the probe"
    echo "SKIP [3/3] render/value/focus: no qemu/aarch64 to run the probe"
    NSKIP=$((NSKIP+2))
elif [ "$NFAIL" != 0 ]; then
    echo "SKIP [2/3] dump/mount/validate: [1/3] failed"
    echo "SKIP [3/3] render/value/focus: [1/3] failed"
    NSKIP=$((NSKIP+2))
else
    for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
                "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
                "assets/embeds.ast:embeds" "src/aster_std.ast:std" \
                "src/aui_spec.ast:aui_spec" "src/textfield.ast:textfield" "tests/fake_ndk.ast:fake_ndk"; do
        src=${spec%%:*}; base=${spec#*:}
        if ! "$ASTER_BIN" build-cn-obj --project "$PROBE_PROJ" --language en \
                "$FW/$src" -o "$OUT/obj/$base.o" >"$OUT/obj/$base.log" 2>&1; then
            echo "FAIL [2/3]: build-cn-obj $src"; cat "$OUT/obj/$base.log" >&2; NFAIL=$((NFAIL+1))
        fi
    done
    if [ "$NFAIL" = 0 ]; then
        if ! "$ASTER_BIN" build-cn-obj --project "$PROBE_PROJ" --language en \
                "$PROBE_SRC" -o "$OUT/obj/textfield_probe.o" >"$OUT/obj/textfield_probe.log" 2>&1; then
            echo "FAIL [2/3]: build-cn-obj textfield_probe"; cat "$OUT/obj/textfield_probe.log" >&2; NFAIL=$((NFAIL+1))
        fi
    fi
    if [ "$NFAIL" = 0 ] && [ "$(warn_count)" != 0 ]; then
        echo "FAIL [2/3]: $(warn_count) warnings in build logs"; NFAIL=$((NFAIL+1))
    fi
    if [ "$NFAIL" = 0 ]; then
        if ! "$ASTER_BIN" link-obj "$OUT/obj/textfield_probe.o" \
                "$OUT/obj/textfield.o" "$OUT/obj/aui_spec.o" "$OUT/obj/aui_core.o" "$OUT/obj/aui_tables.o" "$OUT/obj/aui_font.o" "$OUT/obj/aui_drawprim.o" "$OUT/obj/aui_log.o" "$OUT/obj/aui_raster.o" "$OUT/obj/aui_build.o" "$OUT/obj/aui_layout.o" "$OUT/obj/aui_paint.o" "$OUT/obj/aui_gesture.o" "$OUT/obj/aui_frame.o" "$OUT/obj/aui_input.o" "$OUT/obj/aui_host.o" "$OUT/obj/aui_api.o" "$OUT/obj/aui_png.o" "$OUT/obj/font_runtime.o" \
                "$OUT/obj/truetype.o" "$OUT/obj/text.o" "$OUT/obj/embeds.o" \
                "$OUT/obj/std.o" "$OUT/obj/fake_ndk.o" \
                -o "$OUT/obj/textfield_probe" >"$OUT/obj/link.log" 2>&1; then
            echo "FAIL [2/3]: link-obj"; cat "$OUT/obj/link.log" >&2; NFAIL=$((NFAIL+1))
        fi
    fi
    if [ "$NFAIL" = 0 ]; then
        rc=0
        if [ "$(uname -m)" = aarch64 ] || [ "$(uname -m)" = arm64 ]; then
            "$OUT/obj/textfield_probe" >"$OUT/probe.out" 2>"$OUT/probe.err" || rc=$?
        else
            qemu-aarch64 "$OUT/obj/textfield_probe" >"$OUT/probe.out" 2>"$OUT/probe.err" || rc=$?
        fi
        cp "$OUT/probe.out" "$OUT/probe.out.saved"
        case "$rc" in
            0)  echo "PASS [2/3] dump/mount/validate (probe exit 0)" ;;
            11) echo "FAIL [2/3]: dump did not print 1 line" ;;
            12) echo "FAIL [2/3]: mount of valid TextField spec failed" ;;
            13) echo "FAIL [2/3]: node delta after mount != 1" ;;
            14) echo "FAIL [2/3]: node count / rect readback mismatch between render modes" ;;
            15) echo "FAIL [2/3]: mount rect != imperative rect" ;;
            16) echo "FAIL [2/3]: text-slot ptr mismatch between render modes" ;;
            17) echo "FAIL [2/3]: mount pixelhash != imperative pixelhash" ;;
            20) echo "FAIL [2/3]: event-bearing kind-10 spec mount did not report 113" ;;
            21) echo "FAIL [2/3]: param-less kind-10 spec mount did not report 112" ;;
            22) echo "FAIL [2/3]: child-bearing kind-10 spec mount did not report 112" ;;
            23) echo "FAIL [2/3]: node count changed on failed mounts" ;;
            24) echo "FAIL [2/3]: stale spec mount did not report 115" ;;
            32) echo "FAIL [2/3]: zh dump did not print 1 line" ;;
            30) echo "PASS [2/3] dump/mount/validate"; echo "FAIL [3/3]: value() read-back mismatch" ;;
            31) echo "PASS [2/3] dump/mount/validate"; echo "FAIL [3/3]: focus mismatch (aui_focus_get() != 110 or value unreadable)" ;;
            90) echo "FAIL [2/3]+[3/3]: font load failed" ;;
            91) echo "FAIL [2/3]+[3/3]: headless render failed" ;;
            *)  echo "FAIL [2/3]+[3/3]: probe exit $rc" ;;
        esac
        case "$rc" in
            0) ;;
            30|31) NFAIL=$((NFAIL+1)) ;;
            90|91) NFAIL=$((NFAIL+2)) ;;
            *) NFAIL=$((NFAIL+1)); echo "SKIP [3/3] render/value/focus: [2/3] did not pass"; NSKIP=$((NSKIP+1)) ;;
        esac
        # stdout 比对（只在探针退出 0 时做；任一失败即 [2/3]/[3/3] 失败）。
        if [ "$rc" = 0 ]; then
            sed -n '1p' "$OUT/probe.out" >"$OUT/dump1.txt"
            sed -n '2p' "$OUT/probe.out" >"$OUT/dump2.txt"
            grep -F '提示=点按输入…' "$OUT/probe.out" >"$OUT/dump_zh.txt" || true
            cat >"$OUT/expected_en.txt" <<'EOF'
SPEC 0 种=10 名=文本框 键=110 修饰=- 布局值=- 事件=- 参数=[提示=Tap to type...] 子=0
EOF
            cat >"$OUT/expected_zh.txt" <<'EOF'
SPEC 0 种=10 名=文本框 键=110 修饰=- 布局值=- 事件=- 参数=[提示=点按输入…] 子=0
EOF
            if ! cmp -s "$OUT/dump1.txt" "$OUT/dump2.txt"; then
                echo "FAIL [2/3]: same spec dumped twice differs"; NFAIL=$((NFAIL+1))
            elif ! cmp -s "$OUT/dump1.txt" "$OUT/expected_en.txt"; then
                echo "FAIL [2/3]: en dump != expected text"; diff "$OUT/expected_en.txt" "$OUT/dump1.txt" >&2; NFAIL=$((NFAIL+1))
            elif ! cmp -s "$OUT/dump_zh.txt" "$OUT/expected_zh.txt"; then
                echo "FAIL [2/3]: zh dump != expected text"; diff "$OUT/expected_zh.txt" "$OUT/dump_zh.txt" >&2; NFAIL=$((NFAIL+1))
            else
                echo "PASS [2/3] dump: twice identical + matches expected text (en + zh)"
            fi
            r0=$(awk '$1=="RECT0"{print $2, $3, $4, $5}' "$OUT/probe.out")
            r1=$(awk '$1=="RECT1"{print $2, $3, $4, $5}' "$OUT/probe.out")
            h0=$(awk '$1=="HASH0"{print $2}' "$OUT/probe.out")
            h1=$(awk '$1=="HASH1"{print $2}' "$OUT/probe.out")
            if [ "$r0" != "0 84 480 104" ] || [ "$r1" != "0 84 480 104" ]; then
                echo "FAIL [2/3]: RECT0/RECT1 != 0 84 480 104 ($r0 / $r1)"; NFAIL=$((NFAIL+1))
            elif [ -z "$h0" ] || [ "$h0" != "$h1" ]; then
                echo "FAIL [2/3]: HASH0 ($h0) != HASH1 ($h1)"; NFAIL=$((NFAIL+1))
            elif ! grep -q '^VALUE AB$' "$OUT/probe.out"; then
                echo "FAIL [3/3]: VALUE AB line missing"; NFAIL=$((NFAIL+1))
            elif ! grep -q '^TEXTFIELD PROBE OK$' "$OUT/probe.out"; then
                echo "FAIL [3/3]: TEXTFIELD PROBE OK line missing"; NFAIL=$((NFAIL+1))
            else
                echo "PASS [2/3] mount equivalence: RECT 0 84 480 104 + HASH $h0"
                echo "PASS [3/3] render/value/focus: VALUE AB + focus 110 + value readable"
            fi
            echo "--- probe stdout:"
            cat "$OUT/probe.out"
        fi
        # 保留一份探针输出供复核（OUT 为 mktemp，trap 会删；拷到调用方可见处由调用方做）。
        cp "$OUT/probe.out" /tmp/cn-textfield-checks-probe.out 2>/dev/null || true
    fi
fi

if [ "$NFAIL" = 0 ]; then
    echo "PASS: cn-textfield checks ([1/3] compile + [2/3] dump/mount/validate + [3/3] render/value/focus)"
    exit 0
else
    echo "cn-textfield checks: $NFAIL failed, $NSKIP skipped (logs in $OUT)"
    exit 1
fi
