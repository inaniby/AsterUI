#!/bin/sh
# tests/cn/cn-layout-regression.sh — B23 布局回归探针（四变体 A/B/C/D）。
#
# 独立脚本，不并入 cn-ui-checks.sh 的 7 节计数（它测的是框架布局语义，
# 不是 Gallery 交付物；且 4 变体 × 构建的耗时不应拖慢每次的 [4/7]）。
# 未接入 01:00 全量门禁（用户未定，接线留给门禁 owner）。
#
# 用法：0 参数。ASTER / QEMU 环境变量与 cn-ui-checks.sh 同名。
#   ASTER 默认 ~/workspace/projects/Aster/aster。
# 退出 0 通过、非 0 失败并打印变体名与期望/实际。
#
# 方法（en only、480x880）：mktemp 副本上改 examples/gallery-en/src/
# page_input.ast（行号以运行时核对为准，见下）；每变体重编 page_input.o
# 一个对象（复用一次建好的 27 个框架+应用+驱动对象，不重编框架）+
# link-obj + qemu 各跑两次（stdout 逐字节一致才采信）。
#
# 四变体（行号指 gallery-en/src/page_input.ast 现行版；P3 试点改写
# page_input 后行号由 :70/:71/:111 移到 :49/:50/:85；P5 迁移在文件
# 头加了一行 aui_mount extern 声明，行号再 +1 为 :50/:51/:86；P6 迁移
# 在 :56 处一行改两行（+1 行），:50/:51 不动，闭合 scroll 的 aui_end()
# 由 :86 移到 :87）：
#   A 原样（scroll+weight，:50 aui_scroll(1000) + :51 aui_weight(1)）
#   B 删 :50 与 :87（去 scroll，:87 为闭合 scroll 的 aui_end()）
#   C 只删 :51（去 weight）
#   D 删 :50、:51、:87（两者都去）
#
# 断言：
#   B/C/D 的 PXCOUNT content other > 0，且三组 PIXELHASH input 全等。
#   A 的期望由 EXPECT_A_BLANK 控制：方案二（F1 remain 下传）落地后 A 与
#   C 同样恢复非空白，故 EXPECT_A_BLANK=0，断言 A 的 other > 0。
#   注意：“A 与 C 相同”指同样恢复、同样非空白，不是像素全等——A 的
#   scroll 高 708（视口剩余高）、C 的 scroll 高 916（内容高），两者
#   PIXELHASH 本就不同（F1 实测 A 35977883767843514、C -6850091010814401830），
#   故 A 不与 C 比 PIXELHASH，只断言 other > 0。
#   DRAWCALLS input 只记录、不作断言（调用数与空白无关；F1 下 A 为 41、
#   B/C/D 为 40）。驱动本身不输出 DRAWCALLS 行（基线=完整 stdout 原样，
#   须保持 197 行口径），探针用 mktemp 副本驱动临时加一行打印来记录。
#   退出码只记录：A/C 应为 0；B/D 无 scroll 节点，驱动按设计返回 9
#   （RECT 1000 不存在），不视为失败。
set -u
FW=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ASTER=${ASTER:-$HOME/workspace/projects/Aster/aster}
QEMU=${QEMU:-qemu-aarch64}
# 方案二落地后 A 不再空白：0 = 期望非空白（与 C 同样恢复），1 = 期望空白。
# 翻转条件：只有框架回到“weight 落 scroll 不支持 / F1 回滚”时才改回 1。
EXPECT_A_BLANK=0

OUT=$(mktemp -d /tmp/cn-layout-regression.XXXXXX)
trap 'rm -rf "$OUT"' EXIT HUP INT TERM
mkdir -p "$OUT/obj" "$OUT/run" "$OUT/work"
[ -x "$ASTER" ] || { echo "FAIL: no aster at $ASTER" >&2; exit 2; }
command -v "$QEMU" >/dev/null 2>&1 || { echo "FAIL: qemu-aarch64 not in PATH" >&2; exit 2; }

APP_SRC="$FW/examples/gallery-en"
# 工作副本：只改副本的 page_input.ast 与驱动副本，原树不动。
cp -a "$APP_SRC" "$OUT/work/app"
# aster.proj 的 [language] 节按相对路径列源文件（../../src/...、
# ../../assets/...、src/...），build-cn-obj 靠它加载兄弟源文件里的
# struct 定义（如 app.ast 的 App）。副本须保持同一相对布局：从
# $OUT/work/app/aster.proj 看，../../src 就是 $OUT/src（两级之上），
# 故符号链接放在 $OUT/ 下、不是 $OUT/work/ 下（放错一级会报 A-060）。
ln -s "$FW/src" "$OUT/src"
ln -s "$FW/assets" "$OUT/assets"
# 行号漂移守卫：删行前核对行内容，漂移即停、不盲删。
sed -n '50p;51p;87p' "$OUT/work/app/src/page_input.ast" > "$OUT/lines.txt"
L50=$(sed -n '50p' "$OUT/work/app/src/page_input.ast")
L51=$(sed -n '51p' "$OUT/work/app/src/page_input.ast")
L87=$(sed -n '87p' "$OUT/work/app/src/page_input.ast")
[ "$L50" = "    aui_scroll(1000);" ] || { echo "FAIL: page_input.ast:50 不是 aui_scroll(1000);（行号已漂移）：$L50" >&2; exit 2; }
[ "$L51" = "    aui_weight(1);" ] || { echo "FAIL: page_input.ast:51 不是 aui_weight(1);（行号已漂移）：$L51" >&2; exit 2; }
[ "$L87" = "    aui_end();" ] || { echo "FAIL: page_input.ast:87 不是 aui_end();（行号已漂移）：$L87" >&2; exit 2; }

# 探针驱动副本：交付驱动不输出 DRAWCALLS 行，此处临时加一行打印（仅记录）。
cp "$APP_SRC/tests/headless.ast" "$OUT/work/headless_probe.ast"
python3 - "$OUT/work/headless_probe.ast" <<'PYEOF'
import sys
p = sys.argv[1]
src = open(p).read()
old = """    let e1b: i32 = emit_input(ptr("input"));"""
new = """    let dc1: i32 = out_str(ptr("DRAWCALLS input "));
    let dc2: i32 = out_i32(n2);
    let dc3: i32 = out_nl();
    let e1b: i32 = emit_input(ptr("input"));"""
assert src.count(old) == 1, "probe driver anchor not unique"
src = src.replace(old, new, 1)
open(p, "w").write(src)
print("probe driver: DRAWCALLS print added")
PYEOF

# 一次建好 28 个对象：24 框架（en，16 拆分文件 + font_runtime/truetype/text/embeds/std/aui_spec/select/textfield/fake_ndk）+ app/page_counter/page_nav（en）+ 探针驱动。
GOBJ="$OUT/obj"; PROJ="$OUT/work/app/aster.proj"
for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
            "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
            "assets/embeds.ast:embeds" "src/aster_std.ast:std" \
            "src/aui_spec.ast:aui_spec" "src/select.ast:select" "src/textfield.ast:textfield" \
            "tests/fake_ndk.ast:fake_ndk"; do
    src=${spec%%:*}; b=${spec#*:}
    # 分源发射按“文件路径 == 工程条目路径（字符串）”判定：工程里列出的
    # 6 个框架文件须经副本布局路径（$OUT/src/...、$OUT/assets/...）传，
    # 经 $FW 绝对路径传会判为“不在工程内”而退回合并发射，链接时报
    # duplicate global symbol 'ui_tt_set_clock'（LIB8 回归）。
    # fake_ndk 不在工程条目内，无此问题，走 $FW 原路径。
    case "$src" in
        src/*|assets/*) _f="$OUT/$src" ;;
        *) _f="$FW/$src" ;;
    esac
    "$ASTER" build-cn-obj --project "$PROJ" --language en "$_f" -o "$GOBJ/$b.o" >"$GOBJ/$b.log" 2>&1 \
        || { echo "FAIL: build-cn-obj $src"; cat "$GOBJ/$b.log" >&2; exit 1; }
done
for f in app page_counter page_nav; do
    "$ASTER" build-cn-obj --project "$PROJ" --language en "$OUT/work/app/src/$f.ast" -o "$GOBJ/$f.o" >"$GOBJ/$f.log" 2>&1 \
        || { echo "FAIL: build-cn-obj $f"; cat "$GOBJ/$f.log" >&2; exit 1; }
done
"$ASTER" build-cn-obj --project "$PROJ" --language en "$OUT/work/headless_probe.ast" -o "$GOBJ/headless.o" >"$GOBJ/headless.log" 2>&1 \
    || { echo "FAIL: build-cn-obj headless_probe"; cat "$GOBJ/headless.log" >&2; exit 1; }
echo "probe: 12 shared objects built, 0 warnings: $(grep -ci warn "$GOBJ"/*.log | awk -F: '{s+=$2} END{print s+0}')"

NFAIL=0
_A_HASH=; _A_OTHER=; _A_RC=; _B_HASH=; _B_OTHER=; _B_RC=
_C_HASH=; _C_OTHER=; _C_RC=; _D_HASH=; _D_OTHER=; _D_RC=
run_variant() { # $1 = 变体名, $2.. = 要删的行号（升序传，sed 从大到小删）
    _v=$1; shift
    cp "$APP_SRC/src/page_input.ast" "$OUT/work/app/src/page_input.ast"
    for _ln in $(printf '%s\n' "$@" | sort -rn); do
        sed -i "${_ln}d" "$OUT/work/app/src/page_input.ast"
    done
    "$ASTER" build-cn-obj --project "$PROJ" --language en "$OUT/work/app/src/page_input.ast" \
        -o "$GOBJ/page_input.o" >"$GOBJ/page_input-$_v.log" 2>&1 \
        || { echo "FAIL [$_v]: build-cn-obj page_input"; cat "$GOBJ/page_input-$_v.log" >&2; NFAIL=$((NFAIL+1)); return; }
    # shellcheck disable=SC2086
    "$ASTER" link-obj "$GOBJ/headless.o" "$GOBJ/app.o" "$GOBJ/page_counter.o" \
        "$GOBJ/page_input.o" "$GOBJ/page_nav.o" "$GOBJ/select.o" "$GOBJ/textfield.o" "$GOBJ/aui_core.o" "$GOBJ/aui_tables.o" "$GOBJ/aui_font.o" "$GOBJ/aui_drawprim.o" "$GOBJ/aui_log.o" "$GOBJ/aui_raster.o" "$GOBJ/aui_build.o" "$GOBJ/aui_layout.o" "$GOBJ/aui_paint.o" "$GOBJ/aui_gesture.o" "$GOBJ/aui_frame.o" "$GOBJ/aui_input.o" "$GOBJ/aui_host.o" "$GOBJ/aui_api.o" "$GOBJ/aui_png.o" \
        "$GOBJ/font_runtime.o" "$GOBJ/truetype.o" "$GOBJ/text.o" "$GOBJ/embeds.o" \
        "$GOBJ/std.o" "$GOBJ/aui_spec.o" "$GOBJ/fake_ndk.o" -o "$OUT/run/headless-$_v" >"$GOBJ/link-$_v.log" 2>&1 \
        || { echo "FAIL [$_v]: link-obj"; cat "$GOBJ/link-$_v.log" >&2; NFAIL=$((NFAIL+1)); return; }
    "$QEMU" "$OUT/run/headless-$_v" >"$OUT/run/$_v.out1" 2>"$OUT/run/$_v.err1"; _rc1=$?
    "$QEMU" "$OUT/run/headless-$_v" >"$OUT/run/$_v.out2" 2>"$OUT/run/$_v.err2"; _rc2=$?
    if ! cmp -s "$OUT/run/$_v.out1" "$OUT/run/$_v.out2"; then
        echo "FAIL [$_v]: 两次运行 stdout 不一致（确定性失败）"; NFAIL=$((NFAIL+1)); return
    fi
    _hash=$(awk '$1=="PIXELHASH" && $2=="input"{print $3}' "$OUT/run/$_v.out1")
    _other=$(awk '/^SNAPSHOT input/{s=1} /^SNAPSHOT /&&$2!="input"{s=0} s==1 && $1=="PXCOUNT" && $2=="content"{print $5}' "$OUT/run/$_v.out1")
    _dc=$(awk '$1=="DRAWCALLS" && $2=="input"{print $3}' "$OUT/run/$_v.out1")
    _r1000=$(awk '/^SNAPSHOT input/{s=1} /^SNAPSHOT /&&$2!="input"{s=0} s==1 && $1=="RECT" && $2==1000{print $6}' "$OUT/run/$_v.out1")
    echo "  [$_v] rc=$_rc1/$_rc2 DRAWCALLS=${_dc:-?} RECT1000_h=${_r1000:-none} content_other=${_other:-?} PIXELHASH=${_hash:-?}"
    eval "_${_v}_HASH=\$_hash; _${_v}_OTHER=\$_other; _${_v}_RC=\$_rc1"
}

run_variant A
run_variant B 50 87
run_variant C 51
run_variant D 50 51 87

check_other() { # $1 变体 $2 期望：blank|nonblank
    _v=$1; _want=$2
    eval "_o=\$_${_v}_OTHER"
    if [ -z "$_o" ]; then echo "FAIL [$_v]: 取不到 PXCOUNT content other"; NFAIL=$((NFAIL+1)); return; fi
    if [ "$_want" = nonblank ] && [ "$_o" -le 0 ]; then
        echo "FAIL [$_v]: 期望非空白，实得 content other=$_o"; NFAIL=$((NFAIL+1))
    elif [ "$_want" = blank ] && [ "$_o" -gt 0 ]; then
        echo "FAIL [$_v]: 期望空白，实得 content other=$_o"; NFAIL=$((NFAIL+1))
    else
        echo "  PASS [$_v]: content other=$_o（期望 $_want）"
    fi
}
if [ "$EXPECT_A_BLANK" = 1 ]; then check_other A blank; else check_other A nonblank; fi
check_other B nonblank
check_other C nonblank
check_other D nonblank
if [ "$_B_HASH" = "$_C_HASH" ] && [ "$_C_HASH" = "$_D_HASH" ] && [ -n "$_B_HASH" ]; then
    echo "  PASS [B/C/D]: PIXELHASH input 全等（$_B_HASH）"
else
    echo "FAIL [B/C/D]: PIXELHASH input 不全等（B=$_B_HASH C=$_C_HASH D=$_D_HASH）"; NFAIL=$((NFAIL+1))
fi
if [ "$NFAIL" = 0 ]; then
    echo "cn-layout-regression: PASS（A EXPECT_A_BLANK=$EXPECT_A_BLANK，B/C/D 像素全等）"
    exit 0
else
    echo "cn-layout-regression: FAIL（$NFAIL 项）" >&2
    exit 1
fi
