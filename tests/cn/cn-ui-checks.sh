#!/bin/sh
# tests/cn/cn-ui-checks.sh — 双语 AsterUI 新线 Phase 1：C 轨 headless 门禁。
#
# 沿用 ~/workspace/projects/AsterUI/tests/ui-checks.sh 的 27 节结构精神，
# 但只含 Phase 1 C 轨针对性的 7 节；不跑全量门禁（全量只在凌晨一点跑）。
#
#   [1/7] 工具链：修复树 ./aster v0.23.82-dev + qemu-aarch64 + 稳定密钥指纹
#   [2/7] 稳定密钥签名探针：scratch 中文 APK 用稳定密钥签，verify-apk 通过，
#         证书指纹与预期一致（证明出包通路，不产生交付物）
#   [3/7] 回收探针 headless：reclaim_frame / reclaim_cb / reclaim_cb_cn，
#         build-obj / build-cn-obj + link-obj（LIB8）+ qemu，退出 0
#   [4/7] Gallery Counter 页 headless 渲染 + 快照比对（中/英文）
#   [5/7] Gallery Counter 页点按 +1 headless（中/英文）
#   [6/7] Gallery 中文字体：中文显示正常、无方框占位
#   [7/7] 出包：中/英文 Gallery 各一 APK，稳定密钥签，verify-apk 通过，附大小/SHA
#
# [4/7]–[7/7] 以 B 轨交付的 Gallery APP 为准。2026-11-23 12:27 用户改方向：
# Counter 不再单独成 APP，全部融合到 Gallery 一个 APP（多页面/多标签/
# 多窗口按真实示例做）；HuxerUI testing 思路在 Phase 1 落地。
# 接线目标是 Gallery APP（examples/gallery-{zh,en}/，B 轨第二轮交付物，
# aster.proj 自称“Gallery APP”，包名 zh galleryzh / en gallery；
# 与 examples/templates/gallery-{zh,en}/ 的模板形态是两份不同文件：
# APP 的 aster.proj 相对路径是 ../../src/…、包名分语言，模板是 ../../../src/…、
# zh 包名与 en 相同；门禁以 APP 为准，不以模板为准）。
# 注：本轮开始时 APP 目录尚不存在（只有模板），B 轨在本轮进行中新建；
# C 轨先按模板落点接线跑通一轮，APP 目录出现后改指 APP 并重跑（见 phase1-impl2-c.md）。
# 在新范围确认前，本脚本 [4/7]–[7/7] 仍按“Counter 页”定义（交付物是
# Gallery APP 内的计数器页，不再是独立 Counter APK）；B 轨按新范围交付后，
# 把下面 GALLERY_* 变量改成实际路径即可进门禁，[7/7] 出包目标改为 Gallery APP。
#   GALLERY_ZH_COUNTER / GALLERY_EN_COUNTER：Gallery Counter 页源码
#    （examples/gallery-{zh,en}/src/page_counter.ast）
#   GALLERY_ZH_TEST / GALLERY_EN_TEST：headless 驱动
#    （examples/gallery-{zh,en}/tests/headless.ast，渲染到内存、
#     派发点按、退出码作断言；快照基线由 B 轨随测试一并交付）
#   GALLERY_ZH_PROJ / GALLERY_EN_PROJ：APP 工程标记（aster.proj，[7/7] 出包用）
# 交付物缺失时对应节 SKIP（写明原因，不折进通过数）；RUN 的节失败则整脚本 exit 1。
#
# 稳定密钥：复用编译器仓库根的稳定密钥（ui-checks.sh 所称 "repo-root stable
# key ... used only for delivered packages"），不新建、不每编换一把：
#   STABLE_KEY_DIR 默认 ~/workspace/projects/Aster
#   密钥文件 <dir>/.aster/debug.key.pem（0600），证书 <dir>/.aster/debug.crt.pem
#   SHA-256 指纹见 EXPECTED_FP（只记指纹，不记密钥内容）。
# 出包与探针都用 ASTER_KEY_DIR=$STABLE_KEY_DIR 指向它；套件本身绝不用它
# （套件用临时 key，见 ui-checks.sh 约 1386 行注释）。
#
# 用法：ASTER=/path/to/aster tests/cn/cn-ui-checks.sh
#   ASTER 默认 ~/workspace/projects/Aster/aster。
#   除 [7/7] 在树内跑 aster build 出包（与 build.sh 同款行为）外，
#   其余产物全在 mktemp 的 OUT 下；不改修复树。
# 2026-11-23 B 轨恢复轮：[4/7]–[7/7] 已接线（驱动补快照输出 +
# 真实点按 + 基线 tests/cn/baseline/gallery-{zh,en}.snapshot），
# 详见 ~/workspace/asterui-cn-s1s2/phase1-resume-b.md。
set -u
FW=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ASTER=${ASTER:-$HOME/workspace/projects/Aster/aster}
QEMU=${QEMU:-qemu-aarch64}
STABLE_KEY_DIR=${STABLE_KEY_DIR:-$HOME/workspace/projects/Aster}
EXPECTED_FP="0B:DB:E4:E7:9C:93:A0:02:E7:82:BB:81:09:6A:58:E8:B8:20:85:73:44:72:82:0C:3D:13:4F:95:B6:D6:F1:11"
# B 轨交付契约（见头注释；Gallery APP 落点以 B 轨实际交付为准）。
GALLERY_ZH_DIR="$FW/examples/gallery-zh"
GALLERY_EN_DIR="$FW/examples/gallery-en"
GALLERY_ZH_PROJ="$GALLERY_ZH_DIR/aster.proj"
GALLERY_EN_PROJ="$GALLERY_EN_DIR/aster.proj"
GALLERY_ZH_COUNTER="$GALLERY_ZH_DIR/src/page_counter.ast"
GALLERY_EN_COUNTER="$GALLERY_EN_DIR/src/page_counter.ast"
GALLERY_ZH_TEST="$GALLERY_ZH_DIR/tests/headless.ast"
GALLERY_EN_TEST="$GALLERY_EN_DIR/tests/headless.ast"

OUT=$(mktemp -d /tmp/cn-ui-checks.XXXXXX)
trap 'rm -rf "$OUT"' EXIT HUP INT TERM
mkdir -p "$OUT/obj" "$OUT/run" "$OUT/keyprobe"

NRUN=0; NPASS=0; NSKIP=0; NFAIL=0
pass() { NPASS=$((NPASS+1)); NRUN=$((NRUN+1)); printf '  PASS: %s\n' "$1"; }
fail() { NFAIL=$((NFAIL+1)); NRUN=$((NRUN+1)); printf '  FAIL: %s\n' "$1"; }
skip() { NSKIP=$((NSKIP+1)); printf '  SKIP: %s（%s）\n' "$1" "$2"; }

cert_fp() { # $1 = apk -> SHA-256 fingerprint of CERT.RSA (or empty)
    rm -rf "$OUT/certx"; mkdir -p "$OUT/certx"
    (cd "$OUT/certx" && unzip -o -q "$1" META-INF/CERT.RSA 2>/dev/null) || return 1
    openssl pkcs7 -inform DER -in "$OUT/certx/META-INF/CERT.RSA" -print_certs \
        -outform PEM -out "$OUT/certx/cert.pem" 2>/dev/null || return 1
    openssl x509 -in "$OUT/certx/cert.pem" -noout -fingerprint -sha256 2>/dev/null \
        | sed 's/^.*=//'
}

printf '%s\n' '[1/7] 工具链：aster + qemu + 稳定密钥指纹'
[ -x "$ASTER" ] || { echo "FAIL: no aster at $ASTER" >&2; exit 2; }
VER=$("$ASTER" --version 2>&1 | head -1)
case "$VER" in *"v0.23.82-dev"*) pass "aster $VER";; *)
    fail "aster version not v0.23.82-dev: $VER";; esac
command -v "$QEMU" >/dev/null 2>&1 \
    && pass "qemu-aarch64 $($QEMU --version | head -1)" \
    || fail "qemu-aarch64 not in PATH"
[ -f "$STABLE_KEY_DIR/.aster/debug.crt.pem" ] || fail "stable key cert missing: $STABLE_KEY_DIR/.aster/debug.crt.pem"
FP=$(openssl x509 -in "$STABLE_KEY_DIR/.aster/debug.crt.pem" -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//')
if [ "$FP" = "$EXPECTED_FP" ]; then
    pass "stable key fingerprint $FP (CN=Aster Dev Signing Key, valid to 2049-12-31)"
else
    fail "stable key fingerprint mismatch: got $FP, want $EXPECTED_FP"
fi

printf '%s\n' '[2/7] 稳定密钥签名探针（scratch 中文 APK，不产生交付物）'
KP="$OUT/keyprobe/zhcounter"; mkdir -p "$KP/src"
printf 'kind apk\npackage com.example.%s\nlabel %s\nsrc/main.ast\nsrc/counter.ast\n' \
    'keyprobe' '计数器' > "$KP/aster.proj"
cat > "$KP/src/counter.ast" <<'SRC'
变量 计数: 整数 = 41
方法 增加(步长: 整数): 整数
    计数 = 计数 + 步长
    返回 计数
结束 方法
SRC
cat > "$KP/src/main.ast" <<'SRC'
方法 ANativeActivity_onCreate(活动: 指针, 保存状态: 指针, 保存大小: 整数): 整数
    返回 增加(1)
结束 方法
SRC
if (cd "$KP" && ASTER_KEY_DIR="$STABLE_KEY_DIR" "$ASTER" build >"$OUT/keyprobe/build.log" 2>&1) \
    && [ -f "$KP/build/zhcounter.apk" ]; then
    if "$ASTER" verify-apk "$KP/build/zhcounter.apk" >"$OUT/keyprobe/verify.log" 2>&1; then
        APFP=$(cert_fp "$KP/build/zhcounter.apk")
        if [ "$APFP" = "$EXPECTED_FP" ]; then
            pass "scratch zh APK signed with stable key + verify-apk ok ($(stat -c%s "$KP/build/zhcounter.apk") B)"
        else
            fail "scratch APK cert fingerprint mismatch: got $APFP, want $EXPECTED_FP (log: $OUT/keyprobe/build.log)"
        fi
    else
        fail "verify-apk failed on scratch APK (log: $OUT/keyprobe/verify.log)"
    fi
else
    fail "scratch zh APK build failed (log: $OUT/keyprobe/build.log)"
fi

printf '%s\n' '[3/7] 回收探针 headless（LIB8 + qemu，退出 0）'
[ -f /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc ] \
    || fail "VM lacks /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc (frame probe needs it)"
OBJ="$OUT/obj"
for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
            "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
            "assets/embeds.ast:embeds" "src/aster_std.ast:std" "src/aui_spec.ast:aui_spec" "src/textfield.ast:textfield" "tests/fake_ndk.ast:fake_ndk"; do
    src=${spec%%:*}; base=${spec#*:}
    # P4 step 15: build-cn-obj --project (not build-obj): split framework
    # files need the project context for struct definitions (AuiNode etc.
    # live in aui_core.ast); standalone build-obj fails with
    # "unknown struct type in ptr<AuiNode>". Same shape as build.sh [3/3]
    # and build_gallery_headless below; fake_ndk is not a project member
    # but build-cn-obj accepts it (proven by build.sh [3/3]).
    "$ASTER" build-cn-obj --project "$GALLERY_EN_PROJ" --language en "$FW/$src" -o "$OBJ/$base.o" >"$OBJ/$base.log" 2>&1 \
        || { echo "FAIL: build-cn-obj $src" >&2; cat "$OBJ/$base.log" >&2; exit 1; }
done
LIB8="$OBJ/aui_core.o $OBJ/aui_tables.o $OBJ/aui_font.o $OBJ/aui_drawprim.o $OBJ/aui_log.o $OBJ/aui_raster.o $OBJ/aui_build.o $OBJ/aui_layout.o $OBJ/aui_paint.o $OBJ/aui_gesture.o $OBJ/aui_frame.o $OBJ/aui_input.o $OBJ/aui_host.o $OBJ/aui_api.o $OBJ/aui_png.o $OBJ/font_runtime.o $OBJ/truetype.o $OBJ/text.o $OBJ/embeds.o $OBJ/std.o $OBJ/aui_spec.o $OBJ/textfield.o $OBJ/fake_ndk.o"
"$ASTER" build-obj "$FW/tests/reclaim_frame_test.ast" -o "$OBJ/reclaim_frame_test.o" >"$OBJ/reclaim_frame_test.log" 2>&1 \
    || { echo "FAIL: build-obj reclaim_frame_test.ast" >&2; cat "$OBJ/reclaim_frame_test.log" >&2; exit 1; }
"$ASTER" build-obj "$FW/tests/reclaim_cb_test.ast" -o "$OBJ/reclaim_cb_test.o" >"$OBJ/reclaim_cb_test.log" 2>&1 \
    || { echo "FAIL: build-obj reclaim_cb_test.ast" >&2; cat "$OBJ/reclaim_cb_test.log" >&2; exit 1; }
"$ASTER" build-cn-obj "$FW/tests/cn/reclaim_cb_cn_test.ast" -o "$OBJ/reclaim_cb_cn_test.o" >"$OBJ/reclaim_cb_cn_test.log" 2>&1 \
    || { echo "FAIL: build-cn-obj reclaim_cb_cn_test.ast" >&2; cat "$OBJ/reclaim_cb_cn_test.log" >&2; exit 1; }
for t in reclaim_frame_test reclaim_cb_test reclaim_cb_cn_test; do
    # shellcheck disable=SC2086
    "$ASTER" link-obj "$OBJ/$t.o" $LIB8 -o "$OUT/run/$t" >"$OUT/run/$t.link.log" 2>&1 \
        || { echo "FAIL: link-obj $t" >&2; cat "$OUT/run/$t.link.log" >&2; exit 1; }
    if "$QEMU" "$OUT/run/$t" >"$OUT/run/$t.out.log" 2>&1; then
        pass "$t headless qemu exit 0"
    else
        fail "$t headless qemu exit $? (log: $OUT/run/$t.out.log)"
    fi
done

printf '%s\n' '[4/7] Gallery Counter 页 headless 渲染 + 快照比对'
# build_gallery_headless <lang> <dir>：按 examples/gallery-<lang>/build.sh
# [3/3] 的配方，用 build-cn-obj 编 29 个对象（框架 --language en，
# 应用 + 驱动 --language <lang>）再 link-obj；产物在 $OUT/run。
# 驱动 stdout 与 tests/cn/baseline/gallery-<lang>.snapshot 用
# snapshot_diff.py 做字段级比对；同一二进制跑两次，stdout 须逐字节一致。
build_gallery_headless() {
    _lang=$1; _dir=$2
    _gobj="$OUT/obj/gallery-$_lang"; mkdir -p "$_gobj"
    for spec in "src/aui_core.ast:aui_core" "src/aui_tables.ast:aui_tables" "src/aui_font.ast:aui_font" "src/aui_drawprim.ast:aui_drawprim" "src/aui_log.ast:aui_log" "src/aui_raster.ast:aui_raster" "src/aui_build.ast:aui_build" "src/aui_layout.ast:aui_layout" "src/aui_paint.ast:aui_paint" "src/aui_gesture.ast:aui_gesture" "src/aui_frame.ast:aui_frame" "src/aui_input.ast:aui_input" "src/aui_host.ast:aui_host" "src/aui_api.ast:aui_api" "src/aui_png.ast:aui_png" "src/font_runtime.ast:font_runtime" \
                "src/render/truetype.ast:truetype" "src/render/text.ast:text" \
                "assets/embeds.ast:embeds" "src/aster_std.ast:std" \
                "src/aui_spec.ast:aui_spec" "src/select.ast:select" "src/textfield.ast:textfield" \
                "tests/fake_ndk.ast:fake_ndk"; do
        _src=${spec%%:*}; _b=${spec#*:}
        "$ASTER" build-cn-obj --project "$_dir/aster.proj" --language en "$FW/$_src" -o "$_gobj/$_b.o" >"$_gobj/$_b.log" 2>&1 || return 1
    done
    for f in app page_counter page_input page_nav; do
        "$ASTER" build-cn-obj --project "$_dir/aster.proj" --language "$_lang" "$_dir/src/$f.ast" -o "$_gobj/$f.o" >"$_gobj/$f.log" 2>&1 || return 1
    done
    "$ASTER" build-cn-obj --project "$_dir/aster.proj" --language "$_lang" "$_dir/tests/headless.ast" -o "$_gobj/headless.o" >"$_gobj/headless.log" 2>&1 || return 1
    # shellcheck disable=SC2086
    "$ASTER" link-obj "$_gobj/headless.o" "$_gobj/app.o" "$_gobj/page_counter.o" \
        "$_gobj/page_input.o" "$_gobj/page_nav.o" "$_gobj/select.o" "$_gobj/textfield.o" "$_gobj/aui_core.o" "$_gobj/aui_tables.o" "$_gobj/aui_font.o" "$_gobj/aui_drawprim.o" "$_gobj/aui_log.o" "$_gobj/aui_raster.o" "$_gobj/aui_build.o" "$_gobj/aui_layout.o" "$_gobj/aui_paint.o" "$_gobj/aui_gesture.o" "$_gobj/aui_frame.o" "$_gobj/aui_input.o" "$_gobj/aui_host.o" "$_gobj/aui_api.o" "$_gobj/aui_png.o" \
        "$_gobj/font_runtime.o" "$_gobj/truetype.o" "$_gobj/text.o" "$_gobj/embeds.o" \
        "$_gobj/std.o" "$_gobj/aui_spec.o" "$_gobj/fake_ndk.o" -o "$OUT/run/gallery-$_lang-headless" >"$_gobj/link.log" 2>&1 || return 1
    return 0
}
for lang in zh en; do
    if [ "$lang" = zh ]; then src=$GALLERY_ZH_COUNTER; test=$GALLERY_ZH_TEST; dir=$GALLERY_ZH_DIR; else src=$GALLERY_EN_COUNTER; test=$GALLERY_EN_TEST; dir=$GALLERY_EN_DIR; fi
    base="$FW/tests/cn/baseline/gallery-$lang.snapshot"
    if [ ! -f "$src" ]; then
        skip "Gallery Counter $lang headless 渲染 + 快照" "B 轨未交付：$src 不存在"
    elif [ ! -f "$test" ]; then
        skip "Gallery Counter $lang headless 渲染 + 快照" "B 轨未交付 headless 驱动：$test 不存在"
    elif [ ! -f "$base" ]; then
        skip "Gallery Counter $lang headless 渲染 + 快照" "快照基线未交付：$base 不存在"
    elif ! build_gallery_headless "$lang" "$dir"; then
        fail "Gallery $lang headless 构建失败（日志：$OUT/obj/gallery-$lang/*.log）"
    else
        "$QEMU" "$OUT/run/gallery-$lang-headless" >"$OUT/run/gallery-$lang.out1" 2>"$OUT/run/gallery-$lang.err1"; rc1=$?
        if [ "$rc1" != 0 ]; then
            fail "Gallery $lang headless 退出 $rc1（日志：$OUT/run/gallery-$lang.err1）"
        else
            "$QEMU" "$OUT/run/gallery-$lang-headless" >"$OUT/run/gallery-$lang.out2" 2>"$OUT/run/gallery-$lang.err2"; rc2=$?
            if [ "$rc2" != 0 ]; then
                fail "Gallery $lang headless 第二次运行退出 $rc2"
            elif ! cmp -s "$OUT/run/gallery-$lang.out1" "$OUT/run/gallery-$lang.out2"; then
                fail "Gallery $lang headless 两次运行 stdout 不一致（确定性失败）"
            elif ! python3 "$FW/tests/cn/snapshot_diff.py" "$base" "$OUT/run/gallery-$lang.out1" >"$OUT/run/gallery-$lang.diff" 2>&1; then
                fail "Gallery $lang 快照与基线不一致（见 $OUT/run/gallery-$lang.diff）"
            else
                # B23 像素断言（snapshot_diff.py 只认 SNAPSHOT/PIXELHASH/
                # RECT/TEXT 行、忽略 PXCOUNT，故像素语义守卫只能放这里用 awk 做；
                # 只断言 TEXT 存在不够——空白时 TEXT 节点全在，见诊断 §2.3）：
                # input 段 PXCOUNT content 行第 5 列（other）> 0，且 input 段
                # RECT 1000 的高字段（第 6 列）> 0，否则 fail。
                # out1 已与 out2 cmp 一致，取 out1 为准。
                px_other=$(awk '/^SNAPSHOT input/{s=1} /^SNAPSHOT /&&$2!="input"{s=0} s==1 && $1=="PXCOUNT" && $2=="content"{print $5}' "$OUT/run/gallery-$lang.out1")
                rect1000_h=$(awk '/^SNAPSHOT input/{s=1} /^SNAPSHOT /&&$2!="input"{s=0} s==1 && $1=="RECT" && $2==1000{print $6}' "$OUT/run/gallery-$lang.out1")
                if [ -z "$px_other" ] || [ -z "$rect1000_h" ]; then
                    fail "Gallery $lang 输入页像素断言：input 段缺 PXCOUNT content 或 RECT 1000 行"
                elif [ "$px_other" -le 0 ]; then
                    fail "Gallery $lang 输入页像素断言：内容区非背景像素为 0（PXCOUNT content other=$px_other，空白页）"
                elif [ "$rect1000_h" -le 0 ]; then
                    fail "Gallery $lang 输入页像素断言：RECT 1000 高为 0（scroll 节点退化，空白页）"
                else
                    pass "Gallery $lang headless 渲染 + 快照比对（6 段 + 6 PIXELHASH，两次运行逐字节一致；input 内容像素 $px_other > 0，RECT 1000 高 $rect1000_h > 0）"
                fi
            fi
        fi
    fi
done

printf '%s\n' '[5/7] Gallery Counter 页点按 +1 headless'
# 驱动内已用 fake_post_motion + aui_on_input 真实点按按钮 105（退出 6
# 即点按未加一）；这里再从快照独立核对：counter0 的 TEXT 104 须为 0，
# counter1 的 TEXT 104 须为 1。直接调 gallery_add_one() 冒充点按的
# 旧驱动形态已被 B18 修掉。
for lang in zh en; do
    bin="$OUT/run/gallery-$lang-headless"
    if [ ! -x "$bin" ]; then
        skip "Gallery Counter $lang 点按 +1" "[4/7] 未建成 headless 二进制"
    else
        "$QEMU" "$bin" >"$OUT/run/gallery-$lang.tap.out" 2>"$OUT/run/gallery-$lang.tap.err"; rc=$?
        if [ "$rc" != 0 ]; then
            fail "Gallery Counter $lang 点按 +1：驱动退出 $rc（6=真实点按未加一）"
        else
            tapv=$(awk '/^SNAPSHOT counter0/{s=0} /^SNAPSHOT counter1/{s=1} s==0 && /^TEXT 104 /{v0=$6} s==1 && /^TEXT 104 /{v1=$6} END{print v0 ":" v1}' "$OUT/run/gallery-$lang.tap.out")
            if [ "$tapv" = "0:1" ]; then
                pass "Gallery Counter $lang 点按 +1：真实点按按钮 105，计数 0→1（快照 TEXT 104）"
            else
                fail "Gallery Counter $lang 点按 +1：快照计数不是 0→1（得 $tapv）"
            fi
        fi
    fi
done

printf '%s\n' '[6/7] Gallery 中文字体：中文显示正常、无方框占位'
# 实质检查在中文驱动内：全部三页渲染完后读 aui_rt_missing()，缺字
# （渲染时无字形即画方框占位，缺字计数 +1）须为 0，否则驱动退出 10。
# 这里再核对跑的确实是中文驱动（快照含中文 TEXT 行）。
bin="$OUT/run/gallery-zh-headless"
if [ ! -x "$bin" ]; then
    skip "Gallery zh 中文字体无方框" "[4/7] 未建成 zh headless 二进制"
else
    "$QEMU" "$bin" >"$OUT/run/gallery-zh.font.out" 2>"$OUT/run/gallery-zh.font.err"; rc=$?
    if [ "$rc" != 0 ]; then
        fail "Gallery zh 中文字体：驱动退出 $rc（10=渲染后缺字数非 0，即有方框占位）"
    elif ! grep -q "计数器" "$OUT/run/gallery-zh.font.out"; then
        fail "Gallery zh 中文字体：快照无中文 TEXT 行（跑的不是中文驱动？）"
    else
        pass "Gallery zh 中文字体：渲染后缺字数 0，无方框占位（驱动内 aui_rt_missing 断言 + 中文快照在位）"
    fi
fi

printf '%s\n' '[7/7] 出包：中/英文 Gallery APK（稳定密钥签，verify-apk，大小/SHA）'
for lang in zh en; do
    if [ "$lang" = zh ]; then proj=$GALLERY_ZH_PROJ; dir=$GALLERY_ZH_DIR; apk="$dir/build/gallery-zh.apk"; else proj=$GALLERY_EN_PROJ; dir=$GALLERY_EN_DIR; apk="$dir/build/gallery-en.apk"; fi
    if [ ! -f "$proj" ]; then
        skip "Gallery $lang 出包（稳定密钥）" "B 轨未交付：$proj 不存在，不硬出包"
    elif (cd "$dir" && ASTER_KEY_DIR="$STABLE_KEY_DIR" "$ASTER" build >"$OUT/run/gallery-$lang.pkg.log" 2>&1) && [ -f "$apk" ]; then
        if "$ASTER" verify-apk "$apk" >"$OUT/run/gallery-$lang.verify.log" 2>&1; then
            APFP=$(cert_fp "$apk")
            if [ "$APFP" = "$EXPECTED_FP" ]; then
                pass "Gallery $lang 出包：稳定密钥签 + verify-apk ok ($(stat -c%s "$apk") B, SHA-256 $(sha256sum "$apk" | awk '{print $1}'))"
            else
                fail "Gallery $lang 出包：证书指纹不符：得 $APFP，要 $EXPECTED_FP"
            fi
        else
            fail "Gallery $lang 出包：verify-apk 失败（见 $OUT/run/gallery-$lang.verify.log）"
        fi
    else
        fail "Gallery $lang 出包：aster build 失败（见 $OUT/run/gallery-$lang.pkg.log）"
    fi
done

printf '%s\n' "cn-ui-checks: ran $NRUN, pass $NPASS, fail $NFAIL, skip $NSKIP"
[ "$NFAIL" = 0 ] || exit 1
