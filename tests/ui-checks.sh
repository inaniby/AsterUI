#!/bin/sh
# AsterUI M0 headless checks: Counter + nested scopes under qemu.
# M1.1 adds the SafeArea / file-logging case [8/8] (safearea_test) and
# the Android harness gains the inset/density/log-file group [6/8].
#
# Layers:
#   [1] build the framework objects + Counter test with the prebuilt
#       v0.23.79-dev compiler (zero compiler changes: ../Aster-env/aster,
#       falling back to aster-fixed) and link with the stdlib object.
#   [2] run under qemu-aarch64, require exit 0 and "PASS: counter" on
#       stderr (the program asserts scope run counts and the equal-write
#       no-op internally).
#   [3] diff stdout byte-for-byte against the frozen display-list
#       snapshot asterui/tests/baseline/counter.snapshot.
#   [4] mutation check: copy the framework, break one reconciliation
#       rule (dirty-gated recomposition: every scope re-runs every
#       frame), rebuild, and require the test to FAIL. The snapshot is
#       unchanged by this mutation -- the scope-run-count assertions are
#       what catch it -- so this layer asserts on the exit code.
#
# The headless link set is the full M2 tree (runtime/log/layers,
# assets/embeds, theme, widgets, gallery app): every module the
# headless tests link. The Android .so links the same set minus
# headless.o (it never links headless.o).
#
# M2 adds the gallery cases [9/18] + [10/18] (headless gallery +
# gallery APK) and the reclamation case [11/18] (200 NavStack
# push/pop cycles, pool watermark bounded). M1.2a adds the
# touch-coordinate case [12/18] (cold-PLT lazy-dlopen harness rerun).
# M1.2c adds the density case [13/18] (dp scaling at 320 dpi:
# Counter + Gallery rects double, pixels differ, 48dp slop).
# M1.2a addendum: input-type swap fix -- the harness is 10/10 (new
# group [10]: type-2 motion counts, type-1 key logs, no tap).
#
# M3 adds [14/18] overlay (menu equal widths, translucent scrim,
# modal priority), [15/18] ScrollView, [16/18] string pool (flat
# long run), [17/18] CJK bitmap font (56 hand-drawn glyphs), and
# [18/19] the IME probe (.so + harness + APK). M3.1 also wires the
# Scroll tab into the Gallery (5th tab, keys 700..741); the tabs
# snapshot and hash move for that one added button only.
#
# M4.2 adds [20/20] (MOVE-stub negative control for the gallery
# harness drag assertions). M4.1 adds [21/21] (runtime TrueType
# rasterizer: TTC/CFF + glyf, headless test + frozen hashes, and
# the APK-content proof that no font file ships in any APK).
#
# Not registered in tests/ci.sh yet: the full 152-suite gate is running
# in parallel, and ci.sh registration is a follow-up once it finishes.
set -eu
cd "$(dirname "$0")/.."
OUT=${OUT:-tmp-ui-checks}
# nb_run() cds into a per-test cwd and then uses $OUT-relative paths;
# keep OUT absolute (same convention as HABS below) so those resolve.
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
mkdir -p "$OUT"; trap 'rm -rf "$OUT"' EXIT HUP INT TERM

if [ -x ../Aster-env/aster ]; then ASTER=../Aster-env/aster;
elif [ -x ../Aster-env/aster-fixed ]; then ASTER=../Aster-env/aster-fixed;
else echo 'FAIL: no prebuilt aster in ../Aster-env' >&2; exit 1; fi
QEMU=${QEMU:-qemu-aarch64}
command -v "$QEMU" >/dev/null 2>&1 || { echo "FAIL: $QEMU not in PATH" >&2; exit 1; }

build_tree() {
    # $1 = asterui tree root (relative), $2 = output dir for objects
    src=$1; out=$2; mkdir -p "$out"
    for f in view/node render/layout render/scene render/text render/truetype render/raster runtime/runtime runtime/log runtime/layers assets/embeds theme/theme theme/strings widgets/input widgets/select widgets/nav widgets/scroll backend/headless apps/counter apps/gallery apps/gallery_scroll_tab; do
        "$ASTER" build-obj "$src/$f.ast" -o "$out/$(basename "$f").o" >"$out/$(basename "$f").build" 2>&1 \
            || { echo "FAIL: build-obj $src/$f.ast" >&2; cat "$out/$(basename "$f").build" >&2; exit 1; }
    done
    "$ASTER" build-obj "$src/tests/counter_test.ast" -o "$out/counter_test.o" >"$out/counter_test.build" 2>&1 \
        || { echo "FAIL: build-obj counter_test.ast" >&2; cat "$out/counter_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/pixel_test.ast" -o "$out/pixel_test.o" >"$out/pixel_test.build" 2>&1 \
        || { echo "FAIL: build-obj pixel_test.ast" >&2; cat "$out/pixel_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/safearea_test.ast" -o "$out/safearea_test.o" >"$out/safearea_test.build" 2>&1 \
        || { echo "FAIL: build-obj safearea_test.ast" >&2; cat "$out/safearea_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/gallery_test.ast" -o "$out/gallery_test.o" >"$out/gallery_test.build" 2>&1 \
        || { echo "FAIL: build-obj gallery_test.ast" >&2; cat "$out/gallery_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/gallery_pixel_test.ast" -o "$out/gallery_pixel_test.o" >"$out/gallery_pixel_test.build" 2>&1 \
        || { echo "FAIL: build-obj gallery_pixel_test.ast" >&2; cat "$out/gallery_pixel_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/reclaim_test.ast" -o "$out/reclaim_test.o" >"$out/reclaim_test.build" 2>&1 \
        || { echo "FAIL: build-obj reclaim_test.ast" >&2; cat "$out/reclaim_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/density_test.ast" -o "$out/density_test.o" >"$out/density_test.build" 2>&1 \
        || { echo "FAIL: build-obj density_test.ast" >&2; cat "$out/density_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/overlay_test.ast" -o "$out/overlay_test.o" >"$out/overlay_test.build" 2>&1 \
        || { echo "FAIL: build-obj overlay_test.ast" >&2; cat "$out/overlay_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/scroll_test.ast" -o "$out/scroll_test.o" >"$out/scroll_test.build" 2>&1 \
        || { echo "FAIL: build-obj scroll_test.ast" >&2; cat "$out/scroll_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/string_pool_test.ast" -o "$out/string_pool_test.o" >"$out/string_pool_test.build" 2>&1 \
        || { echo "FAIL: build-obj string_pool_test.ast" >&2; cat "$out/string_pool_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/cjk_test.ast" -o "$out/cjk_test.o" >"$out/cjk_test.build" 2>&1 \
        || { echo "FAIL: build-obj cjk_test.ast" >&2; cat "$out/cjk_test.build" >&2; exit 1; }
    "$ASTER" build-obj "$src/tests/truetype_test.ast" -o "$out/truetype_test.o" >"$out/truetype_test.build" 2>&1 \
        || { echo "FAIL: build-obj truetype_test.ast" >&2; cat "$out/truetype_test.build" >&2; exit 1; }
    "$ASTER" build-obj stdlib/aster_std.ast -o "$out/std.o" >"$out/std.build" 2>&1 \
        || { echo "FAIL: build-obj stdlib" >&2; cat "$out/std.build" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/embeds.o" "$out/headless.o" "$out/counter.o" "$out/counter_test.o" "$out/std.o" \
        -o "$out/counter_test" >"$out/counter_test.link" 2>&1 \
        || { echo "FAIL: link-obj counter_test" >&2; cat "$out/counter_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/embeds.o" "$out/headless.o" "$out/counter.o" "$out/pixel_test.o" "$out/std.o" \
        -o "$out/pixel_test" >"$out/pixel_test.link" 2>&1 \
        || { echo "FAIL: link-obj pixel_test" >&2; cat "$out/pixel_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/embeds.o" "$out/headless.o" "$out/counter.o" "$out/safearea_test.o" "$out/std.o" \
        -o "$out/safearea_test" >"$out/safearea_test.link" 2>&1 \
        || { echo "FAIL: link-obj safearea_test" >&2; cat "$out/safearea_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/gallery.o" "$out/gallery_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/gallery_test" >"$out/gallery_test.link" 2>&1 \
        || { echo "FAIL: link-obj gallery_test" >&2; cat "$out/gallery_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/gallery.o" "$out/gallery_pixel_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/gallery_pixel_test" >"$out/gallery_pixel_test.link" 2>&1 \
        || { echo "FAIL: link-obj gallery_pixel_test" >&2; cat "$out/gallery_pixel_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/gallery.o" "$out/reclaim_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/reclaim_test" >"$out/reclaim_test.link" 2>&1 \
        || { echo "FAIL: link-obj reclaim_test" >&2; cat "$out/reclaim_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/counter.o" "$out/gallery.o" "$out/density_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/density_test" >"$out/density_test.link" 2>&1 \
        || { echo "FAIL: link-obj density_test" >&2; cat "$out/density_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/gallery.o" "$out/overlay_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/overlay_test" >"$out/overlay_test.link" 2>&1 \
        || { echo "FAIL: link-obj overlay_test" >&2; cat "$out/overlay_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/scroll_test.o" "$out/std.o" \
        -o "$out/scroll_test" >"$out/scroll_test.link" 2>&1 \
        || { echo "FAIL: link-obj scroll_test" >&2; cat "$out/scroll_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/counter.o" "$out/gallery.o" "$out/string_pool_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/string_pool_test" >"$out/string_pool_test.link" 2>&1 \
        || { echo "FAIL: link-obj string_pool_test" >&2; cat "$out/string_pool_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/gallery.o" "$out/cjk_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/cjk_test" >"$out/cjk_test.link" 2>&1 \
        || { echo "FAIL: link-obj cjk_test" >&2; cat "$out/cjk_test.link" >&2; exit 1; }
    "$ASTER" link-obj "$out/node.o" "$out/layout.o" "$out/scene.o" "$out/text.o" "$out/truetype.o" "$out/raster.o" "$out/runtime.o" \
        "$out/log.o" "$out/layers.o" "$out/theme.o" "$out/strings.o" "$out/input.o" "$out/select.o" "$out/nav.o" \
        "$out/embeds.o" "$out/headless.o" "$out/counter.o" "$out/gallery.o" "$out/truetype_test.o" "$out/scroll.o" "$out/gallery_scroll_tab.o" "$out/std.o" \
        -o "$out/truetype_test" >"$out/truetype_test.link" 2>&1 \
        || { echo "FAIL: link-obj truetype_test" >&2; cat "$out/truetype_test.link" >&2; exit 1; }
}

printf '%s\n' '[1/4] Build AsterUI M0 + Counter test'
build_tree asterui "$OUT/obj"
echo 'PASS: build'

printf '%s\n' '[2/4] Run under qemu, require exit 0 + PASS'
"$QEMU" "$OUT/obj/counter_test" >"$OUT/counter.out" 2>"$OUT/counter.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: counter_test exited $rc" >&2; cat "$OUT/counter.err" >&2; exit 1; }
grep -qF 'PASS: counter' "$OUT/counter.err" \
    || { echo 'FAIL: PASS line missing from stderr' >&2; cat "$OUT/counter.err" >&2; exit 1; }
echo 'PASS: run + internal assertions'

printf '%s\n' '[3/4] Snapshot diff against frozen baseline'
diff -u asterui/tests/baseline/counter.snapshot "$OUT/counter.out" \
    || { echo 'FAIL: snapshot differs from frozen baseline' >&2; exit 1; }
echo 'PASS: snapshot byte-identical'

printf '%s\n' '[4/4] Mutation check: break dirty-gated recomposition'
cp -r asterui "$OUT/mut-asterui"
# The copied tree keeps its relative includes, so stdlib must exist at the
# same relative place: symlink the repo stdlib beside the copied tree.
ln -sfn "$PWD/stdlib" "$OUT/stdlib"
sed -i 's/if (sc\.dirty == 0) {/if (0 == 1) {/' "$OUT/mut-asterui/runtime/runtime.ast"
grep -qF 'if (0 == 1) {' "$OUT/mut-asterui/runtime/runtime.ast" \
    || { echo 'FAIL: mutation did not apply' >&2; exit 1; }
build_tree "$OUT/mut-asterui" "$OUT/mut-obj"
set +e
"$QEMU" "$OUT/mut-obj/counter_test" >"$OUT/mut.out" 2>"$OUT/mut.err"
mrc=$?
set -e
[ "$mrc" != 0 ] || { echo 'FAIL: mutated build still passed (suite cannot catch broken recomposition)' >&2; exit 1; }
grep -qF 'FAIL:' "$OUT/mut.err" \
    || { echo 'FAIL: mutated run failed without a FAIL diagnostic' >&2; cat "$OUT/mut.err" >&2; exit 1; }
echo "PASS: mutation caught (mutated exit $mrc)"

printf '%s\n' '[5/8] Pixel snapshot + damage rects (M1, headless)'
"$QEMU" "$OUT/obj/pixel_test" >"$OUT/pixel.out" 2>"$OUT/pixel.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: pixel_test exited $rc" >&2; cat "$OUT/pixel.err" >&2; exit 1; }
grep -qF 'PASS: pixel' "$OUT/pixel.err" \
    || { echo 'FAIL: PASS line missing from pixel stderr' >&2; cat "$OUT/pixel.err" >&2; exit 1; }
grep '^PIXELHASH' "$OUT/pixel.out" >"$OUT/pixel.hash"
grep '^PIXELHASH' asterui/tests/baseline/counter.pixels >"$OUT/pixel.want"
diff -u "$OUT/pixel.want" "$OUT/pixel.hash" \
    || { echo 'FAIL: pixel hash differs from frozen baseline' >&2; exit 1; }
grep -qF 'DAMAGE 0 0 400 300' "$OUT/pixel.out" \
    || { echo 'FAIL: first-frame damage is not the full viewport' >&2; exit 1; }
grep -qF 'DAMAGE 8 8 64 16' "$OUT/pixel.out" \
    || { echo 'FAIL: count-change damage is not the label rect' >&2; exit 1; }
"$QEMU" "$OUT/obj/pixel_test" >"$OUT/pixel.out2" 2>"$OUT/pixel.err2"
diff -u "$OUT/pixel.out" "$OUT/pixel.out2" \
    || { echo 'FAIL: pixel test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: pixel snapshot + damage'

printf '%s\n' '[6/8] Android backend: Counter .so + device-free harness (M1 + M1.1 insets/log)'
# NOTE: multi-input build-so used to fail on v0.23.79-dev
# ("duplicate struct declaration: Buf"); P1-4 fixed that in the
# current src by clearing the type tables per top-level Parser, and
# tests/e2e-pie-so.sh pins the fix. The .so is still linked
# explicitly here from per-file build-obj --pic objects (deterministic
# object list, explicit --needed DT_NEEDED), and runtime/layers.o is
# linked because android_present calls ui_layers_frame /
# ui_toast_tick when layers are set up (M2 hooks 5-6); theme.o comes
# with it because the layer backgrounds read ui_theme_surface().
# widgets/scroll.o is linked because on_looper_input calls the
# ScrollView drag injectors (M4.2) even for apps with no ScrollView
# (the injectors answer 0 when nothing captured the touch).
HOUT="$OUT/android"; mkdir -p "$HOUT/obj" "$HOUT/bin"
for f in view/node render/layout render/scene render/text render/truetype render/raster runtime/runtime runtime/log runtime/layers assets/embeds theme/theme widgets/scroll apps/counter backend/android; do
    "$ASTER" build-obj --pic "asterui/$f.ast" -o "$HOUT/obj/$(basename "$f").o" >"$HOUT/obj/$(basename "$f").build" 2>&1 \
        || { echo "FAIL: build-obj asterui/$f.ast (android)" >&2; cat "$HOUT/obj/$(basename "$f").build" >&2; exit 1; }
done
"$ASTER" build-obj --pic asterui/examples/counter/main.ast -o "$HOUT/obj/main.o" >"$HOUT/obj/main.build" 2>&1 \
    || { echo 'FAIL: build-obj counter main.ast' >&2; cat "$HOUT/obj/main.build" >&2; exit 1; }
"$ASTER" build-obj --pic stdlib/aster_std.ast -o "$HOUT/obj/std.o" >"$HOUT/obj/std.build" 2>&1 \
    || { echo 'FAIL: build-obj stdlib (android)' >&2; cat "$HOUT/obj/std.build" >&2; exit 1; }
"$ASTER" link-so --soname libcounter.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so \
    "$HOUT/obj/node.o" "$HOUT/obj/layout.o" "$HOUT/obj/scene.o" "$HOUT/obj/text.o" "$HOUT/obj/truetype.o" "$HOUT/obj/raster.o" \
    "$HOUT/obj/runtime.o" "$HOUT/obj/log.o" "$HOUT/obj/layers.o" "$HOUT/obj/theme.o" "$HOUT/obj/embeds.o" "$HOUT/obj/scroll.o" "$HOUT/obj/counter.o" "$HOUT/obj/android.o" "$HOUT/obj/main.o" \
    "$HOUT/obj/std.o" -o "$HOUT/libcounter.so" >"$HOUT/link.log" 2>&1 \
    || { echo 'FAIL: link-so libcounter.so' >&2; cat "$HOUT/link.log" >&2; exit 1; }
NM=$(command -v aarch64-linux-gnu-nm || command -v nm)
for sym in ANativeActivity_onCreate asterui_counter asterui_frames asterui_paused asterui_dpi asterui_inset_top asterui_log_lines asterui_density_q8 asterui_dp48 ui_raster_render; do
    "$NM" -D --defined-only "$HOUT/libcounter.so" 2>/dev/null | awk '{print $NF}' | sed 's/@@.*$//' | grep -qx "$sym" \
        || { echo "FAIL: libcounter.so does not export $sym" >&2; exit 1; }
done
GUESTCC=${HOSTCC:-aarch64-linux-gnu-gcc}
SKIP_HARNESS=0
machine=$("$GUESTCC" -dumpmachine 2>/dev/null || echo unknown)
case "$machine" in
    aarch64*|arm64*) ;;
    *) if [ "$(uname -m)" != aarch64 ] && [ "$(uname -m)" != arm64 ]; then
           printf '%s\n' "SKIP: android harness needs an AArch64 HOSTCC (got $GUESTCC -> $machine); APK case still runs"
           SKIP_HARNESS=1
       fi ;;
esac
if [ "$SKIP_HARNESS" = 0 ]; then
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -shared -fPIC -DUI_STUB_LOG_ONLY \
    -Wl,-soname,liblog.so -o "$HOUT/bin/liblog.so" tests/ui-android-stub.c \
    || { echo 'FAIL: cannot build liblog stub' >&2; exit 1; }
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -shared -fPIC \
    -Wl,-soname,libandroid.so -o "$HOUT/bin/libandroid.so" tests/ui-android-stub.c \
    || { echo 'FAIL: cannot build libandroid stub' >&2; exit 1; }
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -o "$HOUT/bin/ui-android-harness" \
    tests/ui-android-harness.c -ldl \
    || { echo 'FAIL: cannot build ui-android-harness' >&2; exit 1; }
. tests/guest-libc-alias.sh
provide_guest_libc_alias "$HOUT/bin"
provide_guest_libm_alias "$HOUT/bin"
cp "$HOUT/libcounter.so" "$HOUT/bin/libcounter.so"
HABS=$(cd "$HOUT" && pwd)
LD_LIBRARY_PATH="$HABS/bin" sh tests/run-aarch64.sh "$HABS/bin/ui-android-harness" "$HABS/bin/libcounter.so" --expect-text-pixels >"$HOUT/harness.out" 2>"$HOUT/harness.err" \
    || { echo 'FAIL: ui-android-harness exited non-zero' >&2; cat "$HOUT/harness.out" "$HOUT/harness.err" >&2; exit 1; }
grep -qF 'PASS: ui-android-harness (10/10)' "$HOUT/harness.out" \
    || { echo 'FAIL: harness did not report 10/10' >&2; cat "$HOUT/harness.out" "$HOUT/harness.err" >&2; exit 1; }
echo 'PASS: android .so + harness (10/10)'
fi

printf '%s\n' '[7/8] Android backend: Counter APK build + verify (M1.1 hotfix)'
KEY="$HOUT/keys"; mkdir -p "$KEY"
"$ASTER" build-apk "$HOUT/libcounter.so" -o "$HOUT/counter.apk" \
    --package com.example.asterui.counter --libname counter --abi arm64-v8a \
    --label "AsterUI Counter" --min-sdk 24 --target-sdk 34 \
    --version-code 6 --version-name "1.5" --keystore-dir "$KEY" >"$HOUT/apk.log" 2>&1 \
    || { echo 'FAIL: build-apk counter' >&2; cat "$HOUT/apk.log" >&2; exit 1; }
"$ASTER" verify-apk "$HOUT/counter.apk" >"$HOUT/verify.log" 2>&1 \
    || { echo 'FAIL: verify-apk counter' >&2; cat "$HOUT/verify.log" >&2; exit 1; }
unzip -l "$HOUT/counter.apk" | grep -qF 'lib/arm64-v8a/libcounter.so' \
    || { echo 'FAIL: APK has no lib/arm64-v8a/libcounter.so' >&2; exit 1; }
python3 - "$HOUT/counter.apk" "$HOUT/libcounter.so" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
a = z.read('lib/arm64-v8a/libcounter.so')
b = open(sys.argv[2], 'rb').read()
sys.exit(0 if a == b else 1)
PY
[ "$?" = 0 ] || { echo 'FAIL: packaged .so differs from build output' >&2; exit 1; }
echo 'PASS: counter APK builds, verifies, packages libcounter.so'

printf '%s\n' '[8/8] SafeArea insets + file logging + log viewer (M1.1, headless)'
# The test writes safearea-test.log in the working directory (no
# argv/env access in stdlib, so the path is fixed in the test); remove
# it before each run so the viewer sees exactly one run's lines.
rm -f safearea-test.log
"$QEMU" "$OUT/obj/safearea_test" >"$OUT/safe.out" 2>"$OUT/safe.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: safearea_test exited $rc" >&2; cat "$OUT/safe.err" >&2; exit 1; }
grep -qF 'PASS: safearea' "$OUT/safe.err" \
    || { echo 'FAIL: PASS line missing from safearea stderr' >&2; cat "$OUT/safe.err" >&2; exit 1; }
diff -u asterui/tests/baseline/safearea.snapshot "$OUT/safe.out" \
    || { echo 'FAIL: safearea snapshot differs from frozen baseline' >&2; exit 1; }
grep -qF 'safearea: app start' safearea-test.log \
    || { echo 'FAIL: log file has no app start line' >&2; exit 1; }
grep -qF 'tap 52 112 hit 1' safearea-test.log \
    || { echo 'FAIL: log file has no inset tap line' >&2; exit 1; }
grep -qF 'count 1' safearea-test.log \
    || { echo 'FAIL: log file has no count line' >&2; exit 1; }
grep -qF '[150] I AsterUI: line 49' safearea-test.log \
    || { echo 'FAIL: log file has no line 49' >&2; exit 1; }
rm -f safearea-test.log
"$QEMU" "$OUT/obj/safearea_test" >"$OUT/safe.out2" 2>"$OUT/safe.err2"
diff -u "$OUT/safe.out" "$OUT/safe.out2" \
    || { echo 'FAIL: safearea test is not deterministic across runs' >&2; exit 1; }
rm -f safearea-test.log
echo 'PASS: safearea insets + logging + viewer'

printf '%s\n' '[9/18] Gallery: v1 components headless (M2)'
"$QEMU" "$OUT/obj/gallery_test" >"$OUT/gallery.out" 2>"$OUT/gallery.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: gallery_test exited $rc" >&2; cat "$OUT/gallery.err" >&2; exit 1; }
grep -qF 'PASS: gallery' "$OUT/gallery.err" \
    || { echo 'FAIL: PASS line missing from gallery stderr' >&2; cat "$OUT/gallery.err" >&2; exit 1; }
python3 - "$OUT/gallery.out" "$OUT" <<'PY'
import re, sys
out = open(sys.argv[1], 'rb').read().decode('utf-8')
parts = re.split(r'^SNAPSHOT (\w+)\n', out, flags=re.M)
assert len(parts) == 19, 'expected 9 snapshots, got %d' % ((len(parts) - 1) // 2)
for i in range(1, len(parts), 2):
    name = parts[i]
    assert parts[i+1].endswith('END %s\n' % name), 'bad END for %s' % name
    open('%s/gallery_%s.snapshot' % (sys.argv[2], name), 'w').write('SNAPSHOT %s\n' % name + parts[i+1])
PY
for s in topbar textfield select tabs navstack dialog menu toast theme; do
    diff -u "asterui/tests/baseline/gallery_$s.snapshot" "$OUT/gallery_$s.snapshot" \
        || { echo "FAIL: gallery snapshot $s differs" >&2; exit 1; }
done
"$QEMU" "$OUT/obj/gallery_test" >"$OUT/gallery.out2" 2>"$OUT/gallery.err2"
[ "$?" = 0 ] || { echo 'FAIL: gallery_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/gallery.out" "$OUT/gallery.out2" \
    || { echo 'FAIL: gallery test is not deterministic across runs' >&2; exit 1; }
"$QEMU" "$OUT/obj/gallery_pixel_test" >"$OUT/gallery_pixel.out" 2>"$OUT/gallery_pixel.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: gallery_pixel_test exited $rc" >&2; cat "$OUT/gallery_pixel.err" >&2; exit 1; }
grep -qF 'PASS: gallery-pixel' "$OUT/gallery_pixel.err" \
    || { echo 'FAIL: PASS line missing from gallery-pixel stderr' >&2; exit 1; }
grep '^PIXELHASH' "$OUT/gallery_pixel.out" >"$OUT/gallery_pixel.hash"
diff -u asterui/tests/baseline/gallery.pixels "$OUT/gallery_pixel.hash" \
    || { echo 'FAIL: gallery pixel hashes differ from frozen baseline' >&2; exit 1; }
"$QEMU" "$OUT/obj/gallery_pixel_test" >"$OUT/gallery_pixel.out2" 2>/dev/null
diff -u "$OUT/gallery_pixel.out" "$OUT/gallery_pixel.out2" \
    || { echo 'FAIL: gallery pixel test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: gallery headless (9 snapshots + 11 pixel hashes)'

printf '%s\n' '[10/18] Gallery APK build + verify (M2)'
GOUT="$OUT/gallery-android"; mkdir -p "$GOUT/obj"
for f in assets/embeds view/node render/layout render/scene render/text render/truetype render/raster runtime/runtime runtime/log runtime/layers theme/theme theme/strings widgets/input widgets/select widgets/nav widgets/scroll backend/android apps/gallery apps/gallery_scroll_tab; do
    "$ASTER" build-obj --pic "asterui/$f.ast" -o "$GOUT/obj/$(basename "$f").o" >"$GOUT/obj/$(basename "$f").build" 2>&1 \
        || { echo "FAIL: build-obj asterui/$f.ast (gallery android)" >&2; cat "$GOUT/obj/$(basename "$f").build" >&2; exit 1; }
done
"$ASTER" build-obj --pic asterui/examples/gallery/main.ast -o "$GOUT/obj/main.o" >"$GOUT/obj/main.build" 2>&1 \
    || { echo 'FAIL: build-obj gallery main.ast' >&2; cat "$GOUT/obj/main.build" >&2; exit 1; }
"$ASTER" build-obj --pic stdlib/aster_std.ast -o "$GOUT/obj/std.o" >"$GOUT/obj/std.build" 2>&1 \
    || { echo 'FAIL: build-obj stdlib (gallery android)' >&2; cat "$GOUT/obj/std.build" >&2; exit 1; }
"$ASTER" link-so --soname libgallery.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so \
    "$GOUT/obj/embeds.o" "$GOUT/obj/node.o" "$GOUT/obj/layout.o" "$GOUT/obj/scene.o" "$GOUT/obj/text.o" "$GOUT/obj/truetype.o" "$GOUT/obj/raster.o" \
    "$GOUT/obj/runtime.o" "$GOUT/obj/log.o" "$GOUT/obj/layers.o" "$GOUT/obj/theme.o" "$GOUT/obj/strings.o" \
    "$GOUT/obj/input.o" "$GOUT/obj/select.o" "$GOUT/obj/nav.o" "$GOUT/obj/scroll.o" "$GOUT/obj/android.o" "$GOUT/obj/gallery.o" "$GOUT/obj/gallery_scroll_tab.o" "$GOUT/obj/main.o" \
    "$GOUT/obj/std.o" -o "$GOUT/libgallery.so" >"$GOUT/link.log" 2>&1 \
    || { echo 'FAIL: link-so libgallery.so' >&2; cat "$GOUT/link.log" >&2; exit 1; }
"$ASTER" build-apk "$GOUT/libgallery.so" -o "$GOUT/gallery.apk" \
    --package com.example.asterui.gallery --libname gallery --abi arm64-v8a \
    --label "AsterUI Gallery" --min-sdk 24 --target-sdk 34 \
    --version-code 5 --version-name "1.4" --keystore-dir "$HOUT/keys" >"$GOUT/apk.log" 2>&1 \
    || { echo 'FAIL: build-apk gallery' >&2; cat "$GOUT/apk.log" >&2; exit 1; }
"$ASTER" verify-apk "$GOUT/gallery.apk" >"$GOUT/verify.log" 2>&1 \
    || { echo 'FAIL: verify-apk gallery' >&2; cat "$GOUT/verify.log" >&2; exit 1; }
unzip -l "$GOUT/gallery.apk" | grep -qF 'lib/arm64-v8a/libgallery.so' \
    || { echo 'FAIL: APK has no lib/arm64-v8a/libgallery.so' >&2; exit 1; }
echo 'PASS: gallery APK builds, verifies, packages libgallery.so'

printf '%s\n' '[11/18] Retained-tree reclamation: 200 push/pop cycles (M2)'
"$QEMU" "$OUT/obj/reclaim_test" >"$OUT/reclaim.out" 2>"$OUT/reclaim.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: reclaim_test exited $rc" >&2; cat "$OUT/reclaim.err" >&2; exit 1; }
grep -qF 'PASS: reclaim' "$OUT/reclaim.err" \
    || { echo 'FAIL: PASS line missing from reclaim stderr' >&2; cat "$OUT/reclaim.err" >&2; exit 1; }
grep -qF 'overflow 0' "$OUT/reclaim.out" \
    || { echo 'FAIL: retained pool overflowed' >&2; cat "$OUT/reclaim.out" >&2; exit 1; }
"$QEMU" "$OUT/obj/reclaim_test" >"$OUT/reclaim.out2" 2>"$OUT/reclaim.err2"
[ "$?" = 0 ] || { echo 'FAIL: reclaim_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/reclaim.out" "$OUT/reclaim.out2" \
    || { echo 'FAIL: reclaim test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: reclamation watermark bounded (200 push/pop cycles)'

printf '%s\n' '[12/18] Touch coordinates, cold PLT: harness rerun with lazy dlopen (M1.2a)'
# The [6/8] harness run dlopens with RTLD_NOW, which binds every PLT
# slot eagerly at load -- the step qemu used to mask the zero-arg
# bridge bug. This rerun dlopens the SAME libcounter.so with
# RTLD_LAZY (--lazy-dlopen), so the first-ever AMotionEvent_getX /
# lrintf calls resolve their PLT slots lazily on the cold first tap,
# as on Android. It requires the same 10/10, including the [8] group:
# cold first tap at the button centre counts 0->1, fractional tap
# (156.6,216.6) logs "tap down 157 217 hit 1" and counts again, and the
# window-corner tap logs its true coordinates, never 0,0.
HABS=$(cd "$HOUT" && pwd)
LD_LIBRARY_PATH="$HABS/bin" sh tests/run-aarch64.sh "$HABS/bin/ui-android-harness" "$HABS/bin/libcounter.so" --expect-text-pixels --lazy-dlopen >"$HOUT/harness-lazy.out" 2>"$HOUT/harness-lazy.err" \
    || { echo 'FAIL: ui-android-harness --lazy-dlopen exited non-zero' >&2; cat "$HOUT/harness-lazy.out" "$HOUT/harness-lazy.err" >&2; exit 1; }
grep -qF 'PASS: ui-android-harness (10/10)' "$HOUT/harness-lazy.out" \
    || { echo 'FAIL: lazy-dlopen harness did not report 10/10' >&2; cat "$HOUT/harness-lazy.out" "$HOUT/harness-lazy.err" >&2; exit 1; }
grep -qF 'PASS: android-harness touch coordinates (fractional centre 156.6,216.6 -> 157,217 counts, corner 299,10 + off-button 16,380 log true coords, counter=2, frames=6)' "$HOUT/harness-lazy.out" \
    || { echo 'FAIL: lazy-dlopen harness has no touch-coordinates PASS line' >&2; cat "$HOUT/harness-lazy.out" "$HOUT/harness-lazy.err" >&2; exit 1; }
echo 'PASS: touch coordinates under lazy dlopen (cold PLT, 10/10)'

printf '%s\n' '[13/18] Density-aware dp scaling: Counter + Gallery at 320 dpi (M1.2c)'
"$QEMU" "$OUT/obj/density_test" >"$OUT/density.out" 2>"$OUT/density.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: density_test exited $rc" >&2; cat "$OUT/density.err" >&2; exit 1; }
grep -qF 'PASS: density' "$OUT/density.err" \
    || { echo 'FAIL: PASS line missing from density stderr' >&2; cat "$OUT/density.err" >&2; exit 1; }
diff -u asterui/tests/baseline/density.snapshot "$OUT/density.out" \
    || { echo 'FAIL: density snapshot differs from frozen baseline' >&2; exit 1; }
"$QEMU" "$OUT/obj/density_test" >"$OUT/density.out2" 2>"$OUT/density.err2"
[ "$?" = 0 ] || { echo 'FAIL: density_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/density.out" "$OUT/density.out2" \
    || { echo 'FAIL: density test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: density scaling (160 vs 320 dpi rects + pixels + 48dp slop)'

printf '%s\n' '[14/18] Menu/dialog overlay: equal widths, translucent scrim, modal priority (M3.1)'
"$QEMU" "$OUT/obj/overlay_test" >"$OUT/overlay.out" 2>"$OUT/overlay.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: overlay_test exited $rc" >&2; cat "$OUT/overlay.err" >&2; exit 1; }
grep -qF 'PASS: overlay' "$OUT/overlay.err" \
    || { echo 'FAIL: PASS line missing from overlay stderr' >&2; cat "$OUT/overlay.err" >&2; exit 1; }
diff -u asterui/tests/baseline/overlay.snapshot "$OUT/overlay.out" \
    || { echo 'FAIL: overlay snapshot differs from frozen baseline' >&2; exit 1; }
"$QEMU" "$OUT/obj/overlay_test" >"$OUT/overlay.out2" 2>"$OUT/overlay.err2"
[ "$?" = 0 ] || { echo 'FAIL: overlay_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/overlay.out" "$OUT/overlay.out2" \
    || { echo 'FAIL: overlay test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: overlay widths + scrim pixels + modal priority'

printf '%s\n' '[15/18] ScrollView: offset/clamp/clip/retained (M3.3)'
"$QEMU" "$OUT/obj/scroll_test" >"$OUT/scroll.out" 2>"$OUT/scroll.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: scroll_test exited $rc" >&2; cat "$OUT/scroll.err" >&2; exit 1; }
grep -qF 'PASS: scroll' "$OUT/scroll.err" \
    || { echo 'FAIL: PASS line missing from scroll stderr' >&2; cat "$OUT/scroll.err" >&2; exit 1; }
diff -u asterui/tests/baseline/scroll.snapshot "$OUT/scroll.out" \
    || { echo 'FAIL: scroll snapshot differs from frozen baseline' >&2; exit 1; }
"$QEMU" "$OUT/obj/scroll_test" >"$OUT/scroll.out2" 2>"$OUT/scroll.err2"
[ "$?" = 0 ] || { echo 'FAIL: scroll_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/scroll.out" "$OUT/scroll.out2" \
    || { echo 'FAIL: scroll test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: scroll offset + clamp + clip + retained'

printf '%s\n' '[16/18] String interning / small-string pool: flat long run (M3.5)'
"$QEMU" "$OUT/obj/string_pool_test" >"$OUT/string_pool.out" 2>"$OUT/string_pool.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: string_pool_test exited $rc" >&2; cat "$OUT/string_pool.err" >&2; exit 1; }
grep -qF 'PASS: string-pool' "$OUT/string_pool.err" \
    || { echo 'FAIL: PASS line missing from string-pool stderr' >&2; cat "$OUT/string_pool.err" >&2; exit 1; }
grep -qF 'POOL counter growth 0' "$OUT/string_pool.out" \
    || { echo 'FAIL: counter growth is not flat' >&2; exit 1; }
grep -qF 'POOL textfield growth 0' "$OUT/string_pool.out" \
    || { echo 'FAIL: textfield growth is not flat' >&2; exit 1; }
grep -qF 'POOL tabs growth 0' "$OUT/string_pool.out" \
    || { echo 'FAIL: tabs growth is not flat' >&2; exit 1; }
grep -qF 'POOL overflow 3' "$OUT/string_pool.out" \
    || { echo 'FAIL: pool overflow moved' >&2; exit 1; }
"$QEMU" "$OUT/obj/string_pool_test" >"$OUT/string_pool.out2" 2>"$OUT/string_pool.err2"
[ "$?" = 0 ] || { echo 'FAIL: string_pool_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/string_pool.out" "$OUT/string_pool.out2" \
    || { echo 'FAIL: string pool test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: string pool flat (1000 taps + 500 edits + 400 switches, 0 bytes)'

printf '%s\n' '[17/18] CJK bitmap font: 56 hand-drawn glyphs headless (M3.2)'
"$QEMU" "$OUT/obj/cjk_test" >"$OUT/cjk.out" 2>"$OUT/cjk.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: cjk_test exited $rc" >&2; cat "$OUT/cjk.err" >&2; exit 1; }
grep -qF 'PASS: cjk' "$OUT/cjk.err" \
    || { echo 'FAIL: PASS line missing from cjk stderr' >&2; cat "$OUT/cjk.err" >&2; exit 1; }
python3 - "$OUT/cjk.out" "$OUT" <<'PY'
import re, sys
out = open(sys.argv[1], 'rb').read().decode('utf-8')
assert len(re.findall(r'^SNAPSHOT ', out, flags=re.M)) == 1, 'expected 1 snapshot section'
m = re.search(r'(?ms)^SNAPSHOT gallery_zh\n.*?^END gallery_zh\n', out)
assert m, 'no gallery_zh section in cjk output'
open('%s/cjk_gallery_zh.snapshot' % sys.argv[2], 'w').write(m.group(0))
PY
diff -u asterui/tests/baseline/cjk_gallery_zh.snapshot "$OUT/cjk_gallery_zh.snapshot" \
    || { echo 'FAIL: cjk gallery_zh snapshot differs' >&2; exit 1; }
grep '^PIXELHASH' "$OUT/cjk.out" >"$OUT/cjk.hash"
grep '^PIXELHASH' asterui/tests/baseline/cjk.pixels >"$OUT/cjk.want"
diff -u "$OUT/cjk.want" "$OUT/cjk.hash" \
    || { echo 'FAIL: cjk pixel hashes differ from frozen baseline' >&2; exit 1; }
grep -qF 'CJKSTATS 3929 144 107 32 11' "$OUT/cjk.out" \
    || { echo 'FAIL: cjk cache/missing counters differ' >&2; exit 1; }
"$QEMU" "$OUT/obj/cjk_test" >"$OUT/cjk.out2" 2>"$OUT/cjk.err2"
[ "$?" = 0 ] || { echo 'FAIL: cjk_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/cjk.out" "$OUT/cjk.out2" \
    || { echo 'FAIL: cjk test is not deterministic across runs' >&2; exit 1; }
echo 'PASS: CJK font headless (56 glyphs, gallery zh, pixel hashes)'

printf '%s\n' '[18/19] IME probe: key logging + keyboard request + APK (M3.4, M4.3 SafeArea + focus)'
POUT="$OUT/ime-probe"; mkdir -p "$POUT/obj"
"$ASTER" build-obj --pic asterui/examples/ime-probe/main.ast -o "$POUT/obj/main.o" >"$POUT/obj/main.build" 2>&1 \
    || { echo 'FAIL: build-obj ime-probe main.ast' >&2; cat "$POUT/obj/main.build" >&2; exit 1; }
"$ASTER" build-obj --pic stdlib/aster_std.ast -o "$POUT/obj/std.o" >"$POUT/obj/std.build" 2>&1 \
    || { echo 'FAIL: build-obj stdlib (ime-probe)' >&2; cat "$POUT/obj/std.build" >&2; exit 1; }
"$ASTER" link-so --soname libimeprobe.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so \
    "$POUT/obj/main.o" "$POUT/obj/std.o" -o "$POUT/libimeprobe.so" >"$POUT/link.log" 2>&1 \
    || { echo 'FAIL: link-so libimeprobe.so' >&2; cat "$POUT/link.log" >&2; exit 1; }
for sym in ANativeActivity_onCreate ime_probe_keys ime_probe_text ime_probe_show ime_probe_hide; do
    "$NM" -D --defined-only "$POUT/libimeprobe.so" 2>/dev/null | awk '{print $NF}' | sed 's/@@.*$//' | grep -qx "$sym" \
        || { echo "FAIL: libimeprobe.so does not export $sym" >&2; exit 1; }
done
if [ "$SKIP_HARNESS" = 0 ]; then
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -o "$HOUT/bin/ui-ime-harness" \
    tests/ui-ime-harness.c -ldl \
    || { echo 'FAIL: cannot build ui-ime-harness' >&2; exit 1; }
cp "$POUT/libimeprobe.so" "$HOUT/bin/libimeprobe.so"
HABS=$(cd "$HOUT" && pwd)
LD_LIBRARY_PATH="$HABS/bin" sh tests/run-aarch64.sh "$HABS/bin/ui-ime-harness" "$HABS/bin/libimeprobe.so" >"$POUT/harness.out" 2>"$POUT/harness.err" \
    || { echo 'FAIL: ui-ime-harness exited non-zero' >&2; cat "$POUT/harness.out" "$POUT/harness.err" >&2; exit 1; }
grep -qF 'PASS: ui-ime-harness (9/9)' "$POUT/harness.out" \
    || { echo 'FAIL: harness did not report 9/9' >&2; cat "$POUT/harness.out" "$POUT/harness.err" >&2; exit 1; }
echo 'PASS: ime probe .so + harness (9/9)'
fi
"$ASTER" build-apk "$POUT/libimeprobe.so" -o "$POUT/ime-probe.apk" \
    --package com.example.asterui.imeprobe --libname imeprobe --abi arm64-v8a \
    --label "AsterUI IME Probe" --min-sdk 24 --target-sdk 34 \
    --version-code 2 --version-name "1.1" --keystore-dir "$HOUT/keys" >"$POUT/apk.log" 2>&1 \
    || { echo 'FAIL: build-apk ime-probe' >&2; cat "$POUT/apk.log" >&2; exit 1; }
"$ASTER" verify-apk "$POUT/ime-probe.apk" >"$POUT/verify.log" 2>&1 \
    || { echo 'FAIL: verify-apk ime-probe' >&2; cat "$POUT/verify.log" >&2; exit 1; }
unzip -l "$POUT/ime-probe.apk" | grep -qF 'lib/arm64-v8a/libimeprobe.so' \
    || { echo 'FAIL: APK has no lib/arm64-v8a/libimeprobe.so' >&2; exit 1; }
echo 'PASS: ime probe APK builds, verifies, packages libimeprobe.so'

printf '%s\n' '[19/19] Android layer tap routing: dialog/menu/scrim via DOWN+UP key record (M3.1b) + ScrollView drag/width (M4.2)'
# The Gallery .so is the [10/18] build ($GOUT/libgallery.so); the stub
# libs + guest libc/libm aliases are the [6/18] $HOUT/bin. New symbols
# the gallery harness resolves (dialog/menu state + results, layer key
# geometry, scroll taps) are checked first so a stale .so fails here, not inside
# the harness's dlsym.
for sym in asterui_dialog_open asterui_menu_open asterui_dialog_result asterui_menu_result asterui_scroll_taps asterui_layer_key_x asterui_layer_key_y asterui_layer_key_w asterui_layer_key_h; do
    "$NM" -D --defined-only "$GOUT/libgallery.so" 2>/dev/null | awk '{print $NF}' | sed 's/@@.*$//' | grep -qx "$sym" \
        || { echo "FAIL: libgallery.so does not export $sym" >&2; exit 1; }
done
cp "$GOUT/libgallery.so" "$HOUT/bin/libgallery.so"
"$GUESTCC" -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -o "$HOUT/bin/ui-android-gallery-harness" \
    tests/ui-android-gallery-harness.c -ldl \
    || { echo 'FAIL: cannot build ui-android-gallery-harness' >&2; exit 1; }
HABS=$(cd "$HOUT" && pwd)
LD_LIBRARY_PATH="$HABS/bin" sh tests/run-aarch64.sh "$HABS/bin/ui-android-gallery-harness" "$HABS/bin/libgallery.so" >"$HOUT/gallery-harness.out" 2>"$HOUT/gallery-harness.err" \
    || { echo 'FAIL: ui-android-gallery-harness exited non-zero' >&2; cat "$HOUT/gallery-harness.out" "$HOUT/gallery-harness.err" >&2; exit 1; }
grep -qF 'PASS: ui-android-gallery-harness (17/17)' "$HOUT/gallery-harness.out" \
    || { echo 'FAIL: gallery harness did not report 17/17' >&2; cat "$HOUT/gallery-harness.out" "$HOUT/gallery-harness.err" >&2; exit 1; }
LD_LIBRARY_PATH="$HABS/bin" sh tests/run-aarch64.sh "$HABS/bin/ui-android-gallery-harness" "$HABS/bin/libgallery.so" --lazy-dlopen >"$HOUT/gallery-harness-lazy.out" 2>"$HOUT/gallery-harness-lazy.err" \
    || { echo 'FAIL: ui-android-gallery-harness --lazy-dlopen exited non-zero' >&2; cat "$HOUT/gallery-harness-lazy.out" "$HOUT/gallery-harness-lazy.err" >&2; exit 1; }
grep -qF 'PASS: ui-android-gallery-harness (17/17)' "$HOUT/gallery-harness-lazy.out" \
    || { echo 'FAIL: lazy-dlopen gallery harness did not report 17/17' >&2; cat "$HOUT/gallery-harness-lazy.out" "$HOUT/gallery-harness-lazy.err" >&2; exit 1; }
echo 'PASS: gallery layer taps (dialog OK/Cancel, scrim, menu pick, tap-outside, modal block, drag-off, padding, 12/12 x2) + scroll drag/width (Scroll tab full width, drag scrolls + thumb travels, drag to bottom + list button counts 1, slop tap, drag-off, modal drags, 17/17 x2)'

printf '%s\n' '[20/20] Negative control: gallery harness must FAIL with MOVE stubbed out (M4.2)'
# The [19/19] harness must fail on the old code, where the Android
# backend ignored MOVE -- otherwise its drag assertions prove
# nothing. Build a second libgallery.so from a copy of the tree
# with only the MOVE call stubbed out (ui_scroll_touch_move -> 0,
# so no MOVE ever becomes a drag) and require the harness to exit
# non-zero WITHOUT the 17/17 PASS line. The width fix stays in
# place in this build, so the failure isolates the MOVE wiring.
MOUT="$OUT/mut-scroll"; mkdir -p "$MOUT/obj" "$MOUT/bin"
cp -r asterui "$MOUT/mut-asterui"
# The copied tree keeps its relative includes, so stdlib must exist at
# the same relative place: the tree is at $MOUT/mut-asterui, so its
# ../stdlib is $MOUT/stdlib (NOT $OUT/stdlib as in [4/4], whose
# tree sits directly under $OUT).
ln -sfn "$PWD/stdlib" "$MOUT/stdlib"
sed -i 's/ui_scroll_touch_move(g_android_rt, x, y)/0/' "$MOUT/mut-asterui/backend/android.ast"
grep -qF 'let mv: i32 = 0;' "$MOUT/mut-asterui/backend/android.ast" \
    || { echo 'FAIL: MOVE-stub mutation did not apply' >&2; exit 1; }
grep -qF 'ui_scroll_touch_move(g_android_rt, x, y)' "$MOUT/mut-asterui/backend/android.ast" \
    && { echo 'FAIL: MOVE-stub mutation left a MOVE call behind' >&2; exit 1; }
for f in assets/embeds view/node render/layout render/scene render/text render/truetype render/raster runtime/runtime runtime/log runtime/layers theme/theme theme/strings widgets/input widgets/select widgets/nav widgets/scroll backend/android apps/gallery apps/gallery_scroll_tab; do
    "$ASTER" build-obj --pic "$MOUT/mut-asterui/$f.ast" -o "$MOUT/obj/$(basename "$f").o" >"$MOUT/obj/$(basename "$f").build" 2>&1 \
        || { echo "FAIL: build-obj mut-asterui/$f.ast (MOVE-stub)" >&2; cat "$MOUT/obj/$(basename "$f").build" >&2; exit 1; }
done
"$ASTER" build-obj --pic "$MOUT/mut-asterui/examples/gallery/main.ast" -o "$MOUT/obj/main.o" >"$MOUT/obj/main.build" 2>&1 \
    || { echo 'FAIL: build-obj mut gallery main.ast' >&2; cat "$MOUT/obj/main.build" >&2; exit 1; }
"$ASTER" build-obj --pic stdlib/aster_std.ast -o "$MOUT/obj/std.o" >"$MOUT/obj/std.build" 2>&1 \
    || { echo 'FAIL: build-obj stdlib (MOVE-stub)' >&2; cat "$MOUT/obj/std.build" >&2; exit 1; }
"$ASTER" link-so --soname libgallery.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so \
    "$MOUT/obj/embeds.o" "$MOUT/obj/node.o" "$MOUT/obj/layout.o" "$MOUT/obj/scene.o" "$MOUT/obj/text.o" "$MOUT/obj/truetype.o" "$MOUT/obj/raster.o" \
    "$MOUT/obj/runtime.o" "$MOUT/obj/log.o" "$MOUT/obj/layers.o" "$MOUT/obj/theme.o" "$MOUT/obj/strings.o" \
    "$MOUT/obj/input.o" "$MOUT/obj/select.o" "$MOUT/obj/nav.o" "$MOUT/obj/scroll.o" "$MOUT/obj/android.o" "$MOUT/obj/gallery.o" "$MOUT/obj/gallery_scroll_tab.o" "$MOUT/obj/main.o" \
    "$MOUT/obj/std.o" -o "$MOUT/libgallery.so" >"$MOUT/link.log" 2>&1 \
    || { echo 'FAIL: link-so libgallery.so (MOVE-stub)' >&2; cat "$MOUT/link.log" >&2; exit 1; }
cp "$MOUT/libgallery.so" "$HOUT/bin/libgallery-mut.so"
set +e
LD_LIBRARY_PATH="$HABS/bin" sh tests/run-aarch64.sh "$HABS/bin/ui-android-gallery-harness" "$HABS/bin/libgallery-mut.so" >"$MOUT/harness.out" 2>"$MOUT/harness.err"
mrc=$?
set -e
[ "$mrc" != 0 ] || { echo 'FAIL: harness PASSED against the MOVE-stubbed .so (drag assertions prove nothing)' >&2; exit 1; }
grep -qF 'PASS: ui-android-gallery-harness (17/17)' "$MOUT/harness.out" \
    && { echo 'FAIL: harness printed 17/17 against the MOVE-stubbed .so' >&2; exit 1; }
grep -qF 'Row 0 did not shift up by exactly 100 after drag' "$MOUT/harness.err" \
    || { echo 'FAIL: MOVE-stubbed run failed without the drag-shift diagnostic' >&2; cat "$MOUT/harness.out" "$MOUT/harness.err" >&2; exit 1; }
echo "PASS: MOVE-stub negative control caught (harness exit $mrc, no 17/17)"

printf '%s\n' '[21/21] Runtime TrueType rasterizer: TTC/CFF + glyf headless (M4.1) + no font files in any APK'
"$QEMU" "$OUT/obj/truetype_test" >"$OUT/truetype.out" 2>"$OUT/truetype.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: truetype_test exited $rc" >&2; cat "$OUT/truetype.err" >&2; exit 1; }
grep -qF 'PASS: truetype' "$OUT/truetype.err" \
    || { echo 'FAIL: PASS line missing from truetype stderr' >&2; cat "$OUT/truetype.err" >&2; exit 1; }
grep '^PIXELHASH' "$OUT/truetype.out" >"$OUT/truetype.hash"
grep '^PIXELHASH' asterui/tests/baseline/truetype.pixels >"$OUT/truetype.want"
diff -u "$OUT/truetype.want" "$OUT/truetype.hash" \
    || { echo 'FAIL: truetype pixel hashes differ from frozen baseline' >&2; exit 1; }
grep -qF 'TTSTATS 1 41 9 32 1' "$OUT/truetype.out" \
    || { echo 'FAIL: truetype cache/missing counters differ' >&2; exit 1; }
"$QEMU" "$OUT/obj/truetype_test" >"$OUT/truetype.out2" 2>"$OUT/truetype.err2"
[ "$?" = 0 ] || { echo 'FAIL: truetype_test rerun exited non-zero' >&2; exit 1; }
diff -u "$OUT/truetype.out" "$OUT/truetype.out2" \
    || { echo 'FAIL: truetype test is not deterministic across runs' >&2; exit 1; }
# APK-content proof (the negative): the APKs ship NO font files --
# no .ttf/.ttc/.otf, and no CJK .auf atlas (the hand-drawn glyph
# table stays as code data, not a shipped file). The Counter and
# Gallery APKs are the [7/8] / [10/18] builds above; the IME probe
# APK is [18/19]. A grep hit (exit 0) means a font file is present.
for apk in "$HOUT/counter.apk" "$GOUT/gallery.apk" "$POUT/ime-probe.apk"; do
    [ -f "$apk" ] || { echo "FAIL: APK missing for font-content proof: $apk" >&2; exit 1; }
    if unzip -l "$apk" | grep -Ei '\.(ttf|ttc|otf|auf)$'; then
        echo "FAIL: $apk ships a font/atlas file (see above)" >&2; exit 1;
    fi
done
# W4 adds the adopted-base cases [22/27]..[27/27] (stdlib/asterui,
# v1.48.6 reference as landed, runtime-font adapter). The old 21 cases
# above still run first and must stay green; the new-base cases run
# after them and use their own object dir ($OUT/newbase). Link recipe
# for headless executables (W3): test.o + aui_impl.o + font_runtime.o
# + truetype.o + text.o + embeds.o + std.o + fake_ndk.o. APK recipe
# (W1/W2): per-file build-obj --pic + link-so --page-size 16384 +
# build-apk --min-sdk 24 --target-sdk 35. Nothing here is registered
# in tests/ci.sh (that step is still a follow-up).

nb_run() {
    # $1 = name, rest = link-obj inputs. Links to $NOUT/run/$1, runs
    # under qemu in a fresh cwd (some tests write log files there),
    # requires exit 0.
    _name=$1; shift
    "$ASTER" link-obj "$@" -o "$NOUT/run/$_name" >"$NOUT/run/$_name.link.log" 2>&1 \
        || { echo "FAIL: link-obj $_name" >&2; cat "$NOUT/run/$_name.link.log" >&2; exit 1; }
    rm -rf "$NOUT/run/cwd-$_name"; mkdir -p "$NOUT/run/cwd-$_name"
    set +e
    (cd "$NOUT/run/cwd-$_name" && timeout 20 "$QEMU" "$NOUT/run/$_name" >"$NOUT/run/$_name.out" 2>"$NOUT/run/$_name.err")
    _rc=$?
    set -e
    [ "$_rc" = 0 ] || { echo "FAIL: $_name exited $_rc" >&2; cat "$NOUT/run/$_name.err" >&2; exit 1; }
}

printf '%s\n' '[22/27] New base: every landed example + test compiles (build-obj --pic)'
NOUT="$OUT/newbase"; mkdir -p "$NOUT/obj" "$NOUT/run"
npass=0; nfail=0
for f in stdlib/asterui/examples/*.ast stdlib/asterui/tests/*.ast stdlib/asterui/aui_impl.ast stdlib/asterui/font_runtime.ast; do
    base=$(basename "$f" .ast)
    if "$ASTER" build-obj --pic "$f" -o "$NOUT/obj/$base.pic.o" >"$NOUT/obj/$base.pic.log" 2>&1; then
        npass=$((npass+1))
    else
        nfail=$((nfail+1)); echo "FAIL: build-obj --pic $f" >&2; cat "$NOUT/obj/$base.pic.log" >&2
    fi
done
[ "$nfail" = 0 ] || { echo "FAIL: new-base compile gate: $nfail files failed (of $((npass+nfail)))" >&2; exit 1; }
echo "PASS: new-base compile gate ($npass files, 0 failures; 78 includes rewritten, 77 dead @embed .auf lines neutralised in W4)"
# Non-PIC objects for the headless links below (the --pic objects above
# are reused for the APK links in [27/27]).
for f in stdlib/asterui/tests/*.ast stdlib/asterui/examples/*.ast stdlib/asterui/aui_impl.ast stdlib/asterui/font_runtime.ast asterui/render/truetype.ast asterui/render/text.ast asterui/assets/embeds.ast; do
    base=$(basename "$f" .ast)
    "$ASTER" build-obj "$f" -o "$NOUT/obj/$base.o" >"$NOUT/obj/$base.log" 2>&1 \
        || { echo "FAIL: build-obj $f" >&2; cat "$NOUT/obj/$base.log" >&2; exit 1; }
done
# stdlib lands as std.o (LIB8 uses that name, not aster_std.o).
"$ASTER" build-obj stdlib/aster_std.ast -o "$NOUT/obj/std.o" >"$NOUT/obj/std.log" 2>&1 \
    || { echo 'FAIL: build-obj stdlib/aster_std.ast' >&2; cat "$NOUT/obj/std.log" >&2; exit 1; }
LIB8="$NOUT/obj/aui_impl.o $NOUT/obj/font_runtime.o $NOUT/obj/truetype.o $NOUT/obj/text.o $NOUT/obj/embeds.o $NOUT/obj/std.o $NOUT/obj/fake_ndk.o"

printf '%s\n' '[23/27] New base headless: font adapter + gallery smoke + nav watchdog'
"$ASTER" link-obj "$NOUT/obj/font_adapter_test.o" "$NOUT/obj/font_runtime.o" "$NOUT/obj/truetype.o" \
    "$NOUT/obj/text.o" "$NOUT/obj/embeds.o" "$NOUT/obj/std.o" \
    -o "$NOUT/run/font_adapter_test" >"$NOUT/run/font_adapter_test.link.log" 2>&1 \
    || { echo 'FAIL: link-obj font_adapter_test' >&2; cat "$NOUT/run/font_adapter_test.link.log" >&2; exit 1; }
# Section F fixture (font fix 2026-11-14): the Android 15+ variable
# TTC name, symlinked to the VM TTC, so the test can prove
# renamed-file discovery. Removed after the determinism diff.
SCANFIX=/tmp/aui-fontscan-test
rm -rf "$SCANFIX"; mkdir -p "$SCANFIX"
[ -f /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc ] \
    || { echo 'FAIL: VM lacks /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc (font test needs it)' >&2; exit 1; }
ln -s /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc "$SCANFIX/NotoSansCJK-wght-400-900.ttf.ttc"
# Section J fixture (custom fonts, v2.5): symlinks to the four
# HYZhengYuan reference weights + two truncations of Regular, so
# the test can prove custom-font loading, weight reading and
# corrupt-file fallback. The reference fonts are commercial
# (Hanyi/ZTE): they are NEVER copied into the repo or any APK,
# only symlinked from the working copy for this headless test.
# Removed after the gallery smoke test (which uses it too).
HYZYFIX=/tmp/aui-hyzy-test
rm -rf "$HYZYFIX"; mkdir -p "$HYZYFIX"
HYZYDIR=../../font-reference/hyzhengyuan/fonts
for w in Light Regular Medium Bold; do
    [ -f "$HYZYDIR/HYZhengYuan-$w.ttf" ] \
        || { echo "FAIL: VM lacks $HYZYDIR/HYZhengYuan-$w.ttf (custom-font test needs it)" >&2; exit 1; }
    ln -s "$(pwd)/$HYZYDIR/HYZhengYuan-$w.ttf" "$HYZYFIX/HYZhengYuan-$w.ttf"
done
head -c 8 "$HYZYDIR/HYZhengYuan-Regular.ttf" >"$HYZYFIX/hyzy_trunc8.ttf"
head -c 1024 "$HYZYDIR/HYZhengYuan-Regular.ttf" >"$HYZYFIX/hyzy_trunc1024.ttf"
# Section K fixture (long paths, v2.5.1): two folders whose paths
# mirror the device (72-char folder, 96-char Regular file) and a
# longer one (96-char folder, 120-char Regular file), with
# symlinks to the reference weights. The fonts are symlinked,
# never copied. Lengths are asserted: a typo must fail loudly
# here, not silently test a shorter path.
LONG72="$HYZYFIX/long-folder-name-for-path-capacity-test-0123456789abc"
LONG120="$HYZYFIX/long-folder-name-for-path-capacity-test-0123456789abcdefghijklmnopqrstuvwxyz0"
[ ${#LONG72} -eq 72 ] || { echo "FAIL: LONG72 folder is ${#LONG72} chars, not 72" >&2; exit 1; }
[ ${#LONG120} -eq 96 ] || { echo "FAIL: LONG120 folder is ${#LONG120} chars, not 96" >&2; exit 1; }
mkdir -p "$LONG72" "$LONG120"
for w in Light Regular Medium Bold; do
    ln -s "$(pwd)/$HYZYDIR/HYZhengYuan-$w.ttf" "$LONG72/HYZhengYuan-$w.ttf"
done
ln -s "$(pwd)/$HYZYDIR/HYZhengYuan-Regular.ttf" "$LONG120/HYZhengYuan-Regular.ttf"
"$QEMU" "$NOUT/run/font_adapter_test" >"$NOUT/run/font_adapter.out" 2>"$NOUT/run/font_adapter.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: font_adapter_test exited $rc" >&2; cat "$NOUT/run/font_adapter.err" >&2; exit 1; }
grep -qF 'PASS: font_adapter' "$NOUT/run/font_adapter.err" \
    || { echo 'FAIL: PASS line missing from font_adapter stderr' >&2; cat "$NOUT/run/font_adapter.err" >&2; exit 1; }
grep -v '^#' stdlib/asterui/tests/baseline/font_adapter.pixels >"$NOUT/run/font_adapter.want"
diff -u "$NOUT/run/font_adapter.want" "$NOUT/run/font_adapter.out" \
    || { echo 'FAIL: font adapter output differs from frozen baseline' >&2; exit 1; }
"$QEMU" "$NOUT/run/font_adapter_test" >"$NOUT/run/font_adapter.out2" 2>/dev/null
diff -u "$NOUT/run/font_adapter.out" "$NOUT/run/font_adapter.out2" \
    || { echo 'FAIL: font adapter test is not deterministic across runs' >&2; exit 1; }
rm -rf "$SCANFIX"
nb_run gallery_smoke_test "$NOUT/obj/gallery_smoke_test.o" "$NOUT/obj/ui_gallery.o" $LIB8
rm -rf "$HYZYFIX"
nb_run nav_watchdog_test "$NOUT/obj/nav_watchdog_test.o" "$NOUT/obj/ui_nav.o" $LIB8
# v0.23.81-dev (H-3/C-1): font_runtime_test used to be unlinkable — its
# run-time global initializers live in aui_impl.o, not in the object that
# holds _start. The link must now succeed and the initializers must run
# (g_aui_nodes/cmds/page_cmds point at the pools). Run twice, require
# exit 0, PASS on stderr, byte-identical stdout, and rt_frame_tt ==
# rt_frame_tt2 on the PIXELHASH lines.
"$ASTER" link-obj "$NOUT/obj/font_runtime_test.o" $LIB8 \
    -o "$NOUT/run/font_runtime_test" >"$NOUT/run/font_runtime_test.link.log" 2>&1 \
    || { echo 'FAIL: link-obj font_runtime_test (H-3/C-1)' >&2; cat "$NOUT/run/font_runtime_test.link.log" >&2; exit 1; }
"$QEMU" "$NOUT/run/font_runtime_test" >"$NOUT/run/font_runtime.out" 2>"$NOUT/run/font_runtime.err"
rc=$?
[ "$rc" = 0 ] || { echo "FAIL: font_runtime_test exited $rc" >&2; cat "$NOUT/run/font_runtime.err" >&2; exit 1; }
grep -qF 'PASS: font_runtime' "$NOUT/run/font_runtime.err" \
    || { echo 'FAIL: PASS line missing from font_runtime stderr' >&2; cat "$NOUT/run/font_runtime.err" >&2; exit 1; }
"$QEMU" "$NOUT/run/font_runtime_test" >"$NOUT/run/font_runtime.out2" 2>/dev/null
diff -u "$NOUT/run/font_runtime.out" "$NOUT/run/font_runtime.out2" \
    || { echo 'FAIL: font_runtime test is not deterministic across runs' >&2; exit 1; }
# v2.5.2 (C-1 promoted): the PIXELHASH/RTADV/RTFB stdout is now frozen
# in stdlib/asterui/tests/baseline/font_runtime.pixels (frozen 2026-11-15
# from the same recipe, run twice byte-identical). C-1 used to block
# freezing (see ADOPTION-NOTES.md §3b).
grep -v '^#' stdlib/asterui/tests/baseline/font_runtime.pixels >"$NOUT/run/font_runtime.want"
diff -u "$NOUT/run/font_runtime.want" "$NOUT/run/font_runtime.out" \
    || { echo 'FAIL: font_runtime output differs from frozen baseline' >&2; exit 1; }
_tt=$(grep '^PIXELHASH rt_frame_tt ' "$NOUT/run/font_runtime.out" | awk '{print $3}')
_tt2=$(grep '^PIXELHASH rt_frame_tt2 ' "$NOUT/run/font_runtime.out" | awk '{print $3}')
[ -n "$_tt" ] && [ "$_tt" = "$_tt2" ] \
    || { echo "FAIL: rt_frame_tt ($_tt) != rt_frame_tt2 ($_tt2)" >&2; exit 1; }
echo 'PASS: font adapter (frozen hashes, deterministic; custom fonts J: 4 weights, missing/corrupt fallback, switch determinism) + gallery smoke (6 tabs, dialog/menu, drag 120, nav, focus, Fonts load/restore) + nav watchdog + font_runtime (H-3/C-1, linked + deterministic, rt_frame_tt == rt_frame_tt2)'

printf '%s\n' '[24/27] New base headless: 31 reference harnesses + 42 promoted C-1 tests that link and pass'
# The other 16 harnesses used to link but fail geometry/pixel assertions
# written against the old .auf fonts and the pre-W3 SafeArea rule (see
# ADOPTION-NOTES.md W4). They were re-baselined 2026-11-14 (v2.5 font +
# SafeArea values; anim/time roots made scrollable, anim root given
# aui_weight(1); see ADOPTION-NOTES.md "Re-baselining 2026-11-14") and
# now pass headless under qemu with the TrueType font loaded, so they
# are promoted into the green set here. combo_harness is green only
# after the W4 rename of the reference helper starts_with ->
# combo_starts_with (it collided with stdlib at link time when std.o
# is present).
# v2.5.2 (H-3/C-1): three of the 42 C-1 tests already run green and
# are promoted here. The other 39 link (C-1 fixed) but fail on
# geometry/pixel expectations written against the old reference
# layout (pre-W3 SafeArea floor, .auf font metrics) -- same class
# as the 16 harnesses re-baselined 2026-11-14. They are link-gated
# in [26/27] and tracked as pending re-baseline in
# ADOPTION-NOTES.md W4; promoting them to nb_run here before the
# re-baseline would just go red (verified 2026-11-15: 39/42 exit
# 2-9 on stale expectations, e.g. anim_test rc=2, card shifted down
# by the SafeArea floor).
# 2026-11-15 re-baseline: all 39 re-baselined (each new expectation
# probe-verified against the VM TrueType face, never the fallback
# metrics; sheet_test and cjk_test needed more than new numbers --
# see ADOPTION-NOTES.md C-1 promotion status) and promoted below,
# so [24/27] now runs all 42 C-1 tests green. The [26/27] link gate
# still runs them a second time and tallies the count.
while read -r h ex; do
    nb_run "$h" "$NOUT/obj/$h.o" "$NOUT/obj/$ex.o" $LIB8
done <<'MAP'
android_harness ui_hello
list_harness ui_list
form_harness ui_form
nav_harness ui_nav
nav_transition_harness ui_nav
pager_harness ui_pager
dialog_harness ui_dialog
tooltip_harness ui_tooltip
date_picker_harness ui_date
refresh_harness ui_refresh
chip_harness ui_chip
progress_circle_harness ui_progress_circle
popup_harness ui_popup
ripple_harness ui_ripple
combo_harness ui_combo
system_harness ui_system
anim_harness ui_anim
select_harness ui_select
time_harness ui_time
tree_harness ui_tree
toast_harness ui_toast
menu_harness ui_menu
icon_harness ui_icon
layout_harness ui_layout
sheet_harness ui_sheet
top_bar_harness ui_top_bar
nav_bar_harness ui_nav_bar
nav_pane_harness ui_nav_pane
vlist_harness ui_vlist
vgrid_harness ui_vgrid
hlist_harness ui_hlist
MAP
# v0.23.81-dev (H-4/C-2): png_test used to be BLOCKED in [26/27] on
# duplicate __aster_embed_0 (its own PNG embeds vs embeds.o); the
# per-file @embed symbols fixed it, so it links and runs here now.
nb_run png_test "$NOUT/obj/png_test.o" $LIB8
nb_run nav_test "$NOUT/obj/nav_test.o" $LIB8
nb_run font_runtime_test "$NOUT/obj/font_runtime_test.o" $LIB8
nb_run probe1_harness "$NOUT/obj/probe1_harness.o" "$NOUT/obj/probe1_red.o" "$NOUT/obj/android_stubs.o" "$NOUT/obj/std.o"
# 2026-11-15 re-baseline: the other 39 C-1 tests, promoted from the
# [26/27] link gate (each runs green twice here and in the gate).
nb_run anim_test "$NOUT/obj/anim_test.o" $LIB8
nb_run chip_test "$NOUT/obj/chip_test.o" $LIB8
nb_run cjk_test "$NOUT/obj/cjk_test.o" $LIB8
nb_run combo_test "$NOUT/obj/combo_test.o" $LIB8
nb_run controls_test "$NOUT/obj/controls_test.o" $LIB8
nb_run date_picker_test "$NOUT/obj/date_picker_test.o" $LIB8
nb_run dialog_test "$NOUT/obj/dialog_test.o" $LIB8
nb_run dropdown_test "$NOUT/obj/dropdown_test.o" $LIB8
nb_run fling_test "$NOUT/obj/fling_test.o" $LIB8
nb_run font24_test "$NOUT/obj/font24_test.o" $LIB8
nb_run font48_test "$NOUT/obj/font48_test.o" $LIB8
nb_run headless_test "$NOUT/obj/headless_test.o" $LIB8
nb_run hlist_test "$NOUT/obj/hlist_test.o" $LIB8
nb_run icon_test "$NOUT/obj/icon_test.o" $LIB8
nb_run layout_test "$NOUT/obj/layout_test.o" $LIB8
nb_run menu_test "$NOUT/obj/menu_test.o" $LIB8
nb_run nav_bar_test "$NOUT/obj/nav_bar_test.o" $LIB8
nb_run nav_pane_test "$NOUT/obj/nav_pane_test.o" $LIB8
nb_run nav_transition_test "$NOUT/obj/nav_transition_test.o" $LIB8
nb_run pager_test "$NOUT/obj/pager_test.o" $LIB8
nb_run popup_test "$NOUT/obj/popup_test.o" $LIB8
nb_run progress_circle_test "$NOUT/obj/progress_circle_test.o" $LIB8
nb_run refresh_test "$NOUT/obj/refresh_test.o" $LIB8
nb_run ripple_test "$NOUT/obj/ripple_test.o" $LIB8
nb_run scroll_test "$NOUT/obj/scroll_test.o" $LIB8
nb_run segmented_test "$NOUT/obj/segmented_test.o" $LIB8
nb_run select_test "$NOUT/obj/select_test.o" $LIB8
nb_run shape_aa_test "$NOUT/obj/shape_aa_test.o" $LIB8
nb_run sheet_test "$NOUT/obj/sheet_test.o" $LIB8
nb_run system_test "$NOUT/obj/system_test.o" $LIB8
nb_run tabs_test "$NOUT/obj/tabs_test.o" $LIB8
nb_run text_test "$NOUT/obj/text_test.o" $LIB8
nb_run time_picker_test "$NOUT/obj/time_picker_test.o" $LIB8
nb_run toast_test "$NOUT/obj/toast_test.o" $LIB8
nb_run tooltip_test "$NOUT/obj/tooltip_test.o" $LIB8
nb_run top_bar_test "$NOUT/obj/top_bar_test.o" $LIB8
nb_run tree_test "$NOUT/obj/tree_test.o" $LIB8
nb_run vgrid_test "$NOUT/obj/vgrid_test.o" $LIB8
nb_run vlist_test "$NOUT/obj/vlist_test.o" $LIB8
echo 'PASS: 31 reference harnesses (15 original + 16 re-baselined 2026-11-14: system/anim/select/time/tree/toast/menu/icon/layout/sheet/top_bar/nav_bar/nav_pane/vlist/vgrid/hlist) + png_test (C-2 fixed) + 42 C-1 tests promoted (3 in v2.5.2: nav, font_runtime, probe1_harness; 39 re-baselined 2026-11-15; 15 scale-2 tests unified to scale 1 2026-11-15, 0 left at scale 2)'

printf '%s\n' '[25/27] New base: W3 log/dp/routing tests + bridge-check'
nb_run w3_dp_scale_test "$NOUT/obj/w3_dp_scale_test.o" $LIB8
nb_run w3_log_test "$NOUT/obj/w3_log_test.o" $LIB8
nb_run w3_routing_test "$NOUT/obj/w3_routing_test.o" $LIB8
ASTER="$ASTER" OUT="$NOUT/bridge" sh stdlib/asterui/tests/bridge-check.sh >"$NOUT/bridge.log" 2>&1 \
    || { echo 'FAIL: bridge-check.sh' >&2; cat "$NOUT/bridge.log" >&2; exit 1; }
grep -qF 'PASS: bridge-check (f32 route true in all binding modes)' "$NOUT/bridge.log" \
    || { echo 'FAIL: bridge-check PASS line missing' >&2; cat "$NOUT/bridge.log" >&2; exit 1; }
echo 'PASS: W3 log/dp/routing (exit 0) + bridge-check (f32 route true in all binding modes)'

printf '%s\n' '[26/27] C-1 link gate: 42 links must succeed (all 42 also run green in [24/27] since the 2026-11-15 re-baseline)'
# v2.5.2: C-1 was fixed on the compiler side (H-3, v0.23.81-dev: the
# linker synthesizes an entry stub when the _start object has no
# run-time global initializer of its own). The old ratchet -- which
# required these links to FAIL -- is retired: this section now
# requires them to SUCCEED, so a linker regression goes red here.
# All 42 also run green (promoted to [24/27] 2026-11-15 after the
# re-baseline; see the [24/27] comment and ADOPTION-NOTES.md W4).
# Their exit codes are tallied here, not failed on, so a runtime
# regression shows up as a falling count instead of a red suite --
# but [24/27] already fails hard on any nonzero exit.
nlink=0; nrun=0
for t in anim_test chip_test cjk_test combo_test controls_test date_picker_test dialog_test dropdown_test fling_test font24_test font48_test headless_test hlist_test icon_test layout_test menu_test nav_bar_test nav_pane_test nav_test nav_transition_test pager_test popup_test progress_circle_test refresh_test ripple_test scroll_test segmented_test select_test shape_aa_test sheet_test system_test tabs_test text_test time_picker_test toast_test tooltip_test top_bar_test tree_test vgrid_test vlist_test font_runtime_test; do
    "$ASTER" link-obj "$NOUT/obj/$t.o" $LIB8 -o "$NOUT/run/$t.gate" >"$NOUT/run/$t.gate.log" 2>&1 \
        || { echo "FAIL: $t link failed -- C-1 regressed?" >&2; cat "$NOUT/run/$t.gate.log" >&2; exit 1; }
    nlink=$((nlink+1))
    set +e
    rm -rf "$NOUT/run/cwd-gate-$t"; mkdir -p "$NOUT/run/cwd-gate-$t"
    (cd "$NOUT/run/cwd-gate-$t" && timeout 20 "$QEMU" "$NOUT/run/$t.gate" >"$NOUT/run/$t.gate.out" 2>"$NOUT/run/$t.gate.err")
    _rc=$?
    set -e
    echo "$t gate rc=$_rc"
    [ "$_rc" = 0 ] && nrun=$((nrun+1))
done
"$ASTER" link-obj "$NOUT/obj/probe1_harness.o" "$NOUT/obj/probe1_red.o" "$NOUT/obj/android_stubs.o" "$NOUT/obj/std.o" -o "$NOUT/run/probe1_harness.gate" >"$NOUT/run/probe1_harness.gate.log" 2>&1 \
    || { echo 'FAIL: probe1_harness link failed -- C-1 regressed?' >&2; cat "$NOUT/run/probe1_harness.gate.log" >&2; exit 1; }
nlink=$((nlink+1))
set +e
rm -rf "$NOUT/run/cwd-gate-probe1_harness"; mkdir -p "$NOUT/run/cwd-gate-probe1_harness"
(cd "$NOUT/run/cwd-gate-probe1_harness" && timeout 20 "$QEMU" "$NOUT/run/probe1_harness.gate" >"$NOUT/run/probe1_harness.gate.out" 2>"$NOUT/run/probe1_harness.gate.err")
_rc=$?
set -e
echo "probe1_harness gate rc=$_rc"
[ "$_rc" = 0 ] && nrun=$((nrun+1))
echo "PASS: C-1 link gate ($nlink/42 link; $nrun/42 run green; re-baseline complete 2026-11-15, see ADOPTION-NOTES.md W4)"

printf '%s\n' '[27/27] New base APKs: Counter (ui_hello) + Gallery (ui_gallery) + IME probe, target-sdk 35, 16K page'
APKOUT="$NOUT/apk"; mkdir -p "$APKOUT/obj" "$APKOUT/keys"
for f in render/truetype render/text assets/embeds; do
    "$ASTER" build-obj --pic "asterui/$f.ast" -o "$APKOUT/obj/$(basename "$f").pic.o" >"$APKOUT/obj/$(basename "$f").pic.log" 2>&1 \
        || { echo "FAIL: build-obj --pic asterui/$f.ast (apk)" >&2; cat "$APKOUT/obj/$(basename "$f").pic.log" >&2; exit 1; }
done
"$ASTER" build-obj --pic stdlib/aster_std.ast -o "$APKOUT/obj/std.pic.o" >"$APKOUT/obj/std.pic.log" 2>&1 \
    || { echo 'FAIL: build-obj --pic stdlib (apk)' >&2; cat "$APKOUT/obj/std.pic.log" >&2; exit 1; }
"$ASTER" build-obj --pic asterui/examples/ime-probe/main.ast -o "$APKOUT/obj/ime_main.pic.o" >"$APKOUT/obj/ime_main.pic.log" 2>&1 \
    || { echo 'FAIL: build-obj --pic ime-probe main.ast' >&2; cat "$APKOUT/obj/ime_main.pic.log" >&2; exit 1; }
APKLIB="$NOUT/obj/aui_impl.pic.o $NOUT/obj/font_runtime.pic.o $APKOUT/obj/truetype.pic.o $APKOUT/obj/text.pic.o $APKOUT/obj/embeds.pic.o $APKOUT/obj/std.pic.o"
"$ASTER" link-so --soname libcounter.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so --page-size 16384 \
    $APKLIB "$NOUT/obj/ui_hello.pic.o" -o "$APKOUT/libcounter.so" >"$APKOUT/counter.link.log" 2>&1 \
    || { echo 'FAIL: link-so libcounter.so (new base)' >&2; cat "$APKOUT/counter.link.log" >&2; exit 1; }
"$ASTER" link-so --soname libgallery.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so --page-size 16384 \
    $APKLIB "$NOUT/obj/ui_gallery.pic.o" -o "$APKOUT/libgallery.so" >"$APKOUT/gallery.link.log" 2>&1 \
    || { echo 'FAIL: link-so libgallery.so (new base)' >&2; cat "$APKOUT/gallery.link.log" >&2; exit 1; }
"$ASTER" link-so --soname libimeprobe.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so --page-size 16384 \
    "$APKOUT/obj/ime_main.pic.o" "$APKOUT/obj/std.pic.o" -o "$APKOUT/libimeprobe.so" >"$APKOUT/ime.link.log" 2>&1 \
    || { echo 'FAIL: link-so libimeprobe.so (new base)' >&2; cat "$APKOUT/ime.link.log" >&2; exit 1; }
"$NM" -D --defined-only "$APKOUT/libcounter.so" 2>/dev/null | awk '{print $NF}' | sed 's/@@.*$//' | grep -qx ANativeActivity_onCreate \
    || { echo 'FAIL: libcounter.so does not export ANativeActivity_onCreate' >&2; exit 1; }
"$NM" -D --defined-only "$APKOUT/libgallery.so" 2>/dev/null | awk '{print $NF}' | sed 's/@@.*$//' | grep -qx ANativeActivity_onCreate \
    || { echo 'FAIL: libgallery.so does not export ANativeActivity_onCreate' >&2; exit 1; }
for spec in "counter:counter:com.example.asterui.counter:counter:AsterUI Counter:15:2.5.2" "gallery:gallery:com.example.asterui.gallery:gallery:AsterUI Gallery:14:2.5.2" "ime-probe:imeprobe:com.example.asterui.imeprobe:imeprobe:AsterUI IME Probe:3:2.0"; do
    apkname=${spec%%:*}; rest=${spec#*:}; soname=${rest%%:*}; rest=${rest#*:}; pkg=${rest%%:*}; rest=${rest#*:}; lib=${rest%%:*}; rest=${rest#*:}; label=${rest%%:*}; rest=${rest#*:}; code=${rest%%:*}; ver=${rest#*:}
    "$ASTER" build-apk "$APKOUT/lib$soname.so" -o "$APKOUT/$apkname.apk" \
        --package "$pkg" --libname "$lib" --abi arm64-v8a \
        --label "$label" --min-sdk 24 --target-sdk 35 --page-size 16384 \
        --version-code "$code" --version-name "$ver" --keystore-dir "$APKOUT/keys" >"$APKOUT/$apkname.apk.log" 2>&1 \
        || { echo "FAIL: build-apk $apkname (new base)" >&2; cat "$APKOUT/$apkname.apk.log" >&2; exit 1; }
    "$ASTER" verify-apk "$APKOUT/$apkname.apk" >"$APKOUT/$apkname.verify.log" 2>&1 \
        || { echo "FAIL: verify-apk $apkname (new base)" >&2; cat "$APKOUT/$apkname.verify.log" >&2; exit 1; }
    unzip -l "$APKOUT/$apkname.apk" | grep -qF "lib/arm64-v8a/lib$soname.so" \
        || { echo "FAIL: $apkname.apk has no lib/arm64-v8a/lib$soname.so" >&2; exit 1; }
    if unzip -l "$APKOUT/$apkname.apk" | grep -Ei '\.(ttf|ttc|otf|auf)$|classes\.dex$'; then
        echo "FAIL: $apkname.apk ships a font file or dex" >&2; exit 1;
    fi
    readelf -lW "$APKOUT/lib$soname.so" | grep LOAD | awk '{print $NF}' | grep -qv '^0x4000$' \
        && { echo "FAIL: lib$soname.so LOAD segments are not 16K-aligned" >&2; exit 1; }
done
echo 'PASS: new-base APKs build + verify (Counter v2.5.2/code 15, Gallery v2.5.2/code 14, IME probe v2.0/code 3; target-sdk 35, 16K page, no font files, no dex)'

echo 'PASS: ui-checks (21/21 old + 6/6 new-base)'
