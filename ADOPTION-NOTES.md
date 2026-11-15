# AsterUI v1.48.6 adoption notes

## W1 compiler verdicts (2026-11-14, worker W1)

Compiler under test: `~/workspace/projects/Aster-env/aster`
(`Aster bootstrap compiler v0.23.79-dev` + local P0/P1 fixes).
Reference: landed copy `stdlib/asterui/`; pristine copy
`~/workspace/projects/AsterUI-ref/` (patches read, never applied).
All build outputs under `/tmp/aui-adopt/`; repo untouched except this file.

Verdict scale: SATISFIED / NEEDS-REFERENCE-ADAPTATION /
BLOCKED-NEEDS-COMPILER-CHANGE.

### 0. Compilation gate — NEEDS-REFERENCE-ADAPTATION (no compiler change)

- `aui_impl.ast` (17,415 lines) compiles clean with the current compiler:
  `aster build-obj --pic stdlib/asterui/aui_impl.ast -o /tmp/aui-adopt/aui_impl.o`
  exit 0 — `emitted AArch64 ELF64 ET_REL object (104106 instructions,
  751 functions, 716 globals, PIC)`.
- `aui.ast` alone: `aster: error: cannot write an empty object` (exit 1).
  Expected and not a defect: the file is extern-only; it is meant to be
  `include`d, not compiled standalone.
- All 34 examples + all 77 tests compile in the reference layout
  (where the `.auf` font assets exist): examples 34/34 pass, tests 77/77
  pass, zero language-feature failures. The current compiler already
  supports every language feature the reference uses.
- The LANDED copy fails for two adaptation reasons (not compiler reasons):
  1. Include path. Every example/test does
     `include "../stdlib/asterui/aui.ast";`, which assumes a top-level
     `examples/` layout. Landed under `stdlib/asterui/examples/` it
     resolves to the nonexistent
     `stdlib/asterui/examples/../stdlib/asterui/aui.ast`. Verbatim:
     `aster: stdlib/asterui/examples/ui_hello.ast:6:9: error: cannot open
     included file "../stdlib/asterui/aui.ast" (looked for
     "stdlib/asterui/examples/../stdlib/asterui/aui.ast")`.
     Fix in adaptation: rewrite to `../aui.ast` (and likewise for tests).
  2. Missing font assets. With only the include fixed (in a /tmp copy of
     the landed tree), `ui_hello.ast` fails at the first `@embed`:
     `aster: examples/ui_hello.ast:22:19: error: cannot open embedded file
     "../stdlib/asterui/assets/font_latin48.auf" (looked for
     "examples/../stdlib/asterui/assets/font_latin48.auf")`.
     The second failure in the same file would be
     `font_cjk48.auf` (line 25). No `.auf` file exists in the landed copy.
     Font-asset failures belong to the font-surgery worker.

### (a) 16 KB page + target-sdk 35 — SATISFIED

Commands (reference `build.sh` steps 3 and 5, using the reference-layout
objects that compile):
```
aster link-so /tmp/aui-adopt/ref-examples/ui_hello.o /tmp/aui-adopt/aui_impl.o \
  --soname libuihello.so \
  --needed libandroid.so --needed liblog.so --needed libm.so --needed libc.so \
  --page-size 16384 -o /tmp/aui-adopt/libuihello.so
# exit 0: linked 2 AArch64 ET_REL PIC object(s) into shared object
# (760 exports, 32 PLT function imports, 26 GOT data imports, 4 DT_NEEDED, SONAME libuihello.so)
aster build-apk /tmp/aui-adopt/libuihello.so -o /tmp/aui-adopt/uihello.apk \
  --package dev.aster.uihello --label "UI Hello" --libname uihello \
  --abi arm64-v8a --min-sdk 24 --target-sdk 35 --page-size 16384 \
  --version-code 67 --version-name 1.48.6
# exit 0: built APK (NativeActivity, v1+v2 dual-signed, debug key ...)
aster verify-apk /tmp/aui-adopt/uihello.apk
# OK (v1 + v2 signatures verified)
```
Evidence:
- `readelf -lW libuihello.so`: all three LOAD segments `Align 0x4000`
  (= 16384).
- `.so` data offset inside the APK = 16384 exactly
  (`data_off%16384 == 0`, computed from the zip local header).
- Binary AXML decode of the built `AndroidManifest.xml`
  (`/tmp/aui-adopt/axml.py`): `uses-sdk {minSdkVersion: 24,
  targetSdkVersion: 35}`.
- Source: `--page-size`/`--target-sdk`/`--min-sdk` are already accepted
  by `build-apk`/`link-so` (`src/aster.cpp:16337-16338, 16373, 16491,
  16590`); `buildApk` already takes `pageSize` and aligns the `.so`
  entry to it. The 16k patch adds nothing the current compiler lacks.

### (b) configChanges 0x490 vs 0x1F90 — BLOCKED-NEEDS-COMPILER-CHANGE (one constant)

Emitted value confirmed from a real built APK (AXML decode above):
`activity {name: android.app.NativeActivity, ..., configChanges:
type0x11=0x490}`. Source agrees: `src/aster.cpp:14145` hardcodes
`"configChanges","hex","0x490"`. The patch is NOT applied.

What happens without the patch — read from the reference source
(`stdlib/asterui/aui_impl.ast`) and its design doc, plus machine evidence:
- `aui_android_attach(activity, saved, saved_size, ...)` (line 15247)
  NEVER reads `saved`/`saved_size`: the identifier `saved` occurs
  nowhere else in the file except that parameter declaration.
- `aui_cb_save` (line 15111, installed at callback slot 16 =
  onSaveInstanceState) is an empty stub: `fn aui_cb_save(a: ptr,
  out_state: ptr, out_size: ptr) -> i32 { return 0; }`. Compiled
  disassembly (`llvm-objdump-18 -d --disassemble-symbols=aui_cb_save
  aui_impl.o`) is just `mov w0, #0; ret` — it writes no state.
- Navigation (`g_aui_nav_stack[8]`, `g_aui_nav_depth`, lines 944-945),
  app state (`g_aui_state_key/val[256]`, lines 911-913), text pool and
  scroll offsets all live in process globals; `aui_cb_destroy` →
  `aui_shutdown` resets node count/root. The design doc states the
  boundary itself (docs/AsterUI-design.md, §D.12): "Activity 被系统回收
  重建后 route 回到 1（库不写 saved state）".
- No test in `tests/` exercises a restart (`grep restart|onSave|cb_save`
  in the reference tests: no hits).

Verdict on behaviour: WITHOUT the patch, rotation does NOT restart the
Activity (0x490 already covers keyboard|orientation|screenSize — the
doc §D.13 says so explicitly), but a dark/light-mode (uiMode) or
density change DOES restart it, and the restart loses all state:
**rotation is safe; dark-mode/density change restarts the app to the
home page (route 1), losing navigation, text input, scroll offset and
focus.** With the patch (0x1F90) those changes go through
`aui_cb_config` (line 15232) → `config_refresh()` + `aui_invalidate()`
and state is preserved in place. The missing piece is exactly one
constant: `0x490` → `0x1F90` at `src/aster.cpp:14145` (plus a suite
probe). Note also the doc's own caveat: v1.9 rotation/dark/density was
"qemu + 离屏验证" only — the config path has no real-device evidence
even in the reference.
No headless restart run was done: the save path is provably empty by
source + compiled disassembly + the doc's own boundary statement, so a
harness run could only re-confirm a `return 0`.

### (c) link-so funcaddr / dangling GLOB_DAT (D.6) — BLOCKED-NEEDS-COMPILER-CHANGE (link-so path only)

The reference recipe (`build-obj --pic` + `link-so`) produces a .so
that FAILS the reference's own gate:
```
python3 tools/check_so.py /tmp/aui-adopt/libuihello.so
# FAIL /tmp/aui-adopt/libuihello.so: 26 self relocations, 26 duplicate UND names, 0 bad verneed, 0 nonexistent imports
# exit 1
```
`readelf -rW libuihello.so`: 743 R_AARCH64_RELATIVE, 32 JUMP_SLOT,
**26 R_AARCH64_GLOB_DAT — all 26 name functions**, not data:
`on_add, on_dec, on_reset, on_notify, app_build, app_init, dialog_noop,
sheet_noop, aui_pump_thread, aui_on_input, aui_cb_start, aui_cb_resume,
aui_cb_save, aui_cb_pause, aui_cb_stop, aui_cb_destroy, aui_cb_focus,
aui_cb_win_created, aui_cb_win_resized, aui_cb_win_redraw,
aui_cb_win_destroyed, aui_cb_iq_created, aui_cb_iq_destroyed,
aui_cb_rect, aui_cb_config, aui_cb_lowmem`.
Each name appears twice in `.dynsym`: once as a defined FUNC with
default version (`on_add@@aster`, value 0x4000, …) and once as an
UND OBJECT with no version — the GLOB_DAT reloc points at the UND
OBJECT entry. That is exactly the D.6 shape check_so.py describes.

Root cause, by source inspection: the `funcAddrSeen` fix exists ONLY
in `buildSoFromSource` (`src/aster.cpp:15180-15195`, the single-`.ast`
`build-so` path). `linkSharedObjects` (`src/aster.cpp:12123`, the
`link-so` path) has only `defFuncs,defObjs,impF,impO` — no
`funcAddrSeen`, no `funcAddrRefs` population — and its GAT loop
(lines ~12305-12315) pushes a defined-function address reference into
`spec.importObjects`, which `writeSharedObjectDyn` (lines ~11784-11788)
emits as `R_AARCH64_GLOB_DAT` (type 1025). The reference patch hunk
matches `linkSharedObjects`, not `buildSoFromSource`.
`writeSharedObjectDyn` DOES consume `funcAddrRefs` correctly when fed
(lines 11763-11777: each gets a GOT slot with an R_AARCH64_RELATIVE
reloc, type 1027) — the writer is fine; the link-so feeder is missing
the 3-line classification.

Positive control proving the fix works where present: a single-`.ast`
`build-so` probe (`/tmp/aui-adopt/cbtest.ast`, two callbacks stored to
globals) yields **0 GLOB_DAT, 5 RELATIVE**, and under qemu-aarch64
dlopen + call returns 49 as expected:
```
aster build-so cbtest.ast --soname libcbtest.so -o cbtest.so
# emitted AArch64 ELF64 ET_DYN shared object (69 instructions, 4 exported functions, ...)
# dlopen OK; call_it() = 49 (expect 49)
```

Empirical dlopen of the reference .so under qemu-aarch64 + glibc
(minimal dlopen harness `/tmp/aui-adopt/dlopen/dlopen_test.c`, stubs
`libandroid.so`/`liblog.so` built from `tests/ui-android-stub.c` plus
5 extra NDK stubs the reference needs —
`AConfiguration_getUiModeNight`, `ANativeWindow_getWidth/Height`,
`ALooper_prepare`, `ANativeActivity_finish` — and glibc
`libc.so`/`libm.so` aliases):
```
dlopen(/tmp/aui-adopt/dlopen/libuihello.so, RTLD_NOW)
dlopen OK; dlsym ANativeActivity_onCreate: found; dlsym aui_version: found
# exit 0; RTLD_LAZY likewise exit 0
```
So glibc's loader resolves the UND OBJECT entries against the
versioned FUNC definitions in the same .so, and the D.6 failure does
NOT reproduce under qemu. It is a bionic-specific failure mode
(check_so.py docstring: BIND_NOW eager resolution fails to find the
symbol in the DT_NEEDED libs) that cannot be confirmed or refuted on
this host — but the reference's own gate refuses the .so, and the
3-line fix in `linkSharedObjects` is the precise missing piece.
(First dlopen attempt failed differently — `undefined symbol:
ANativeWindow_getWidth` — because the repo's C stub lacks that NDK
symbol; that was a stub-coverage gap, fixed by the extra stubs above,
not a reference defect.)

### (d) DT_VERNEED — SATISFIED for the Android recipe (with a residual footgun)

`readelf -dW` on the link-so .so (`libuihello.so`) and on the build-so
probe (`cbtest.so`): **no DT_VERNEED / DT_VERNEEDNUM present** — only
`DT_VERDEF`, `DT_VERDEFNUM` (2) and `DT_VERSYM`. The evaluation's claim
"ours emits no DT_VERNEED" is CONFIRMED for the recipe used.
Attribution: both .so paths go through `writeSharedObjectDyn`
(`src/aster.cpp:11555`; called from `linkSharedObjects` at 12354 and
from `buildSoFromSource` at 15237). The DT_VERNEED push at lines
11728-11729 lives there but is guarded:
```
// v0.23.77-dev (audit A-16): ... Register the tags only when
// libc.so.6 is genuinely one of the dependencies.
bool needsLibcVerneed=false;
for(const auto& n:spec.needed)if(n=="libc.so.6")needsLibcVerneed=true;
if(needsLibcVerneed){ dyn.push_back({0x6ffffffe,...}); dyn.push_back({0x6fffffff,1}); }
```
The other writer, `writeSharedObject` (line 10996, static/non-dynamic
path), never registers DT_VERNEED (comments at 11210-11221: "DT_VERNEED/
DT_VERNEEDNUM are not registered"). The `.gnu.version_r` section bytes
still exist in the .so but no dynamic tag points at them — inert, as
the patch's own comment describes.
Residual footgun (conditional is live, verified): `link-so cbtest.o
--needed libc.so.6` DOES emit `DT_VERNEED`/`DT_VERNEEDNUM`, while
`--needed libc.so` does not. The no-verneed patch would delete the
branch entirely; the current compiler is safe only as long as no recipe
passes `libc.so.6` as a needed lib. The Android recipe uses `libc.so`,
so this is not blocking adoption — but the branch is worth deleting
with the link-so funcaddr fix.

### Summary table

| Item | Verdict | Precise missing piece (if any) |
|---|---|---|
| Compilation gate (aui_impl + examples + tests) | NEEDS-REFERENCE-ADAPTATION | Landed `include "../stdlib/asterui/aui.ast"` paths assume top-level `examples/`; rewrite to `../aui.ast`. Font `.auf` `@embed`s missing — font worker's scope. No compiler language gap: 34/34 examples, 77/77 tests compile in ref layout. |
| (a) 16 KB page + target-sdk 35 | SATISFIED | — (LOAD Align 0x4000; APK `.so` data off 16384; manifest minSdk 24 / targetSdk 35; verify-apk OK) |
| (b) configChanges 0x1F90 | BLOCKED-NEEDS-COMPILER-CHANGE | One constant: `src/aster.cpp:14145`, `0x490` → `0x1F90`. Without it: rotation OK, but dark-mode/density change restarts to home page (route 1); `aui_cb_save` is an empty stub and attach ignores `saved`. |
| (c) link-so funcaddr (D.6) | BLOCKED-NEEDS-COMPILER-CHANGE | Port the `funcAddrSeen` → `spec.funcAddrRefs` classification from `buildSoFromSource` (15180-15195) into `linkSharedObjects` (~12305-12315). Writer already handles it. Reference gate `check_so.py` currently FAILs (26 self relocs); glibc/qemu dlopen happens to load it, bionic is the risk. |
| (d) DT_VERNEED | SATISFIED (residual) | None for the Android recipe (`--needed libc.so` emits no VERNEED). Residual: `--needed libc.so.6` still triggers the conditional at 11728-11729 — consider deleting the branch with the (c) fix. |

## W2 font surgery (2026-11-14, worker W2)

Compiler under test: `~/workspace/projects/Aster-env/aster`
(v0.23.79-dev + local fixes). No `.auf` file exists anywhere under
`stdlib/asterui/` (verified with `find -iname "*.auf"`); the APK
contains no `.ttf`/`.ttc`/`.otf`/`.auf` entry (see APK proof below).
All `.ast` touched here stays ASCII-only (CJK text in tests is UTF-8
bytes via `store_u8`, never a literal).

### 1. Reference text-stack map (every .auf touchpoint)

AUF1 format (docs/AsterUI-design.md §8.2, confirmed against the
code): 32-byte header -- magic `"AUF1"`, version u16@4, flags u16@6
(bit0: 8bpp coverage, else 1bpp), glyph_count u16@8, pixel_size
u16@10, line_height u8@12, baseline u8@13, table u32@16, bitmap
u32@20, bitmap_size u32@24. 16-byte records: codepoint u32@0,
advance u8@4, w u8@5, h u8@6, xoff i8@7, yoff i8@8, flags u8@9,
bitmap_off u32@12. Records sorted ascending; binary search.

Touchpoints in `stdlib/asterui/aui_impl.ast` (line numbers as landed
after the surgery):

| Touchpoint | Lines | What assumed .auf |
|---|---|---|
| `g_aui_font` / `g_aui_font2`, `g_aui_text_scale(2)` | 862-872 | Font = injected `@embed` blob pointer; two fonts, two scales (Latin 8x8 x2, CJK 16x16 x1) |
| `font_at_u8/u16/u32`, `font_u8/u16/u32`, `font_glyph_count/pixel/line_h/table/bitmap`, `font2_pixel/line_h` | 1721-1748 | Raw header reads at fixed offsets |
| `glyph_find_in(f, cp)` | 1750-1763 | Binary search over the AUF table |
| `glyph_find(cp)` | 1765 | `glyph_find_in(g_aui_font, cp)` |
| `glyph_advance(cp)` | 1767-1791 | Record advance byte `+4` x scale; missing = `8 x scale` |
| `text_line_h()` / `text_glyph_h()` | 1793-1821 | `line_h` / `pixel` header fields x scale, max of two fonts |
| `utf8_next` | 1823+ | (No .auf assumption; untouched. Decodes 1-4 byte UTF-8, sets `g_aui_utf8_adv`.) |
| `layout_text(s, tlen, maxw)` | 1856-1929 | Word-wrap / line-break / alignment input is `glyph_advance` only; layout logic itself is font-agnostic (kept verbatim) |
| `text_measure` | 1931-1933 | `layout_text` wrapper (kept verbatim) |
| `draw_glyph_aa` | 10990+ | 8bpp coverage blit from an AUF bitmap base (kept verbatim; reused by the new path with a staged bitmap, base 0) |
| `draw_glyph` | 11033+ | 1bpp/8bpp dispatch from an AUF record (kept verbatim; dead in RT mode) |
| `draw_text_run` | 11141+ | Per-codepoint AUF lookup + `draw_glyph`, pen += record advance |
| `aui_set_font(font, scale)` | 15983+ | Stored the `@embed` pointer into `g_aui_font` |
| `aui_set_fallback_font(font, scale)` | 15999+ | Stored the `@embed` pointer into `g_aui_font2` |

Reference sizing that the surgery preserves: native em 48 px at
scale 1 (`font_latin48`/`font_cjk48`, line_h 60, baselines 46/47);
old 8 px font line_h 10 at scale 2 = 20 px; 24 px font line_h 30 at
scale 2 = 60 px. `emit_text_lines` centres the 48 px glyph box in
the 60 px line (`ty = ytop + li*lh + (lh-gh)/2`) and clips text
commands to the line height, not the glyph height (so Latin
descenders are not cut) -- both untouched.

Every `@embed` of a `.auf` file in the landed tree (73 files in
`examples/` + `tests/`, e.g. `font_latin48.auf`, `font_cjk48.auf`,
`font_latin.auf`, `font_cjk.auf`, `font_latin24.auf`,
`font_cjk24.auf`) is a DEAD reference: the files do not exist, and
the files also carry the broken landed include
(`../stdlib/asterui/aui.ast`, see W1 §0). Only `ui_hello.ast` was
adapted (APK proof); the other 72 are W1 suite-wiring scope, not
font surgery. The design doc's `.auf` prose (§8.2 etc.) is
historical documentation, left as-is.

### 2. Seam design

New file `stdlib/asterui/font_runtime.ast` -- the adapter. It
presents the TrueType engine behind the interface the reference
text code expects (glyph lookup by codepoint -> 8bpp bitmap +
advance + bearings), and `aui_impl.ast` calls it at exactly three
choke points (`glyph_advance`, `text_line_h`/`text_glyph_h`,
`draw_text_run`). `layout_text` / `text_measure` /
`emit_text_lines` / word wrap / line breaking / alignment /
ellipsis are byte-identical: only the glyph SOURCE changed.

Adapter API (`aui_rt_*`, all in `font_runtime.ast`):

- `aui_rt_ensure()` -- lazy init via the engine's default chain
  (`/system/fonts/NotoSansCJK-Regular.ttc` ->
  `NotoSansSC-Regular.otf` -> `DroidSansFallback.ttf`).
- `aui_rt_set_font_path(path)` -- test/diagnostic hook: explicit
  load (SC auto-selection for a TTC). A nonexistent path fails with
  reason 1 and switches to fallback; the device never calls this.
- `aui_rt_advance(cp)` -- native px at scale 1. TrueType: the
  font's `hmtx` advance (`advance_units * 48 / upm`; the engine
  parses `hhea` but does not retain the `hmtx` offset, so the
  adapter scans the sfnt directory itself with the engine's own
  readers; glyphs past `numOfLongHorMetrics` reuse the last
  advance, per spec). Fallback: ASCII 24 (half em), CJK 48
  (full em). Missing glyphs still advance (wide 48 / narrow 24).
- `aui_rt_glyph(cp)` -- stages the bitmap behind
  `aui_rt_bm/bw/bh/xo/yo/src` getters; answers 1/0. Source order:
  system font first (`ui_tt_rasterize(cp, 48, 48)` into the
  engine's 32-entry cache; bitmap is the whole em box, xoff/yoff
  0), then the hand-drawn fallback: ASCII 8x8 via `ui_font_row`
  upscaled x3 into a 24x24 scratch (yoff 12, centred in the 48 px
  cell), CJK 16x16 via `ui_cjk_row` upscaled x3 into a 48x48
  scratch. Truly missing glyphs return 0 and increment
  `aui_rt_missing()` (counted on draw only, never on measure).
- `aui_rt_pixel()` = 48, `aui_rt_line_h()` = 60 -- the reference
  48 px metrics (see §1). `aui_rt_active()`,
  `aui_rt_fallback_events()` / `aui_rt_fallback_reason()`
  (engine error code: 1 = no file, 3 = not a font, 4 = no cmap,
  5 = no outlines) expose the fallback state; on Android the
  backend logs it at startup (the adapter only records it -- no
  log call was added to the reference host code).
- The adapter includes `asterui/render/truetype.ast` and
  `asterui/render/text.ast` (declaration imports; their
  definitions link from `truetype.o` / `text.o` / `embeds.o` /
  `std.o`). It does NOT read, copy, or embed any font file.

Changed functions in `aui_impl.ast` (all else untouched):

- `glyph_advance`: RT branch first -- `fx(aui_rt_advance(cp) *
  g_aui_text_scale)`; AUF branch kept behind `g_aui_rt_mode == 0`.
- `text_line_h` / `text_glyph_h`: RT branch first --
  `fx(60 * scale)` / `fx(48 * scale)`; AUF branch kept.
- `draw_text_run`: RT branch first -- new helper
  `aui_rt_draw_text_run` stages each glyph via `aui_rt_glyph`
  and blits it with the UNCHANGED `draw_glyph_aa` (staged bitmap,
  base 0), pen += `aui_rt_advance(cp) * scale`, so measure and
  draw agree exactly. The staged bitmap is only valid until the
  next `aui_rt_glyph` call, so each glyph is blitted before the
  next is staged. AUF branch kept.
- `aui_set_font` / `aui_set_fallback_font`: the pointer is now
  IGNORED (set to 0) -- there is no `.auf` blob to inject; only
  the scale is recorded and `g_aui_rt_mode` is set to 1. Signatures
  unchanged, so all existing call sites compile.
- `g_aui_rt_mode: i32 = 1` added next to `g_aui_font`; the AUF
  readers (`font_at_*`, `glyph_find_in`, `draw_glyph`) are kept
  verbatim behind mode 0 for reference only.
- `extern fn aui_rt_*` declarations added above §3.

What was deliberately NOT changed: `layout_text`, `text_measure`,
`emit_text_lines`, `utf8_next`, `draw_glyph_aa`, the AUF readers
themselves, and every layout/paint call site that uses
`text_measure`/`text_line_h`/`text_glyph_h`.

Dropped .auf metadata (no equivalent in the new source, by design):
per-glyph `xoff`/`yoff` (the TT bitmap is the whole em box, origin
at the em origin; `emit_text_lines` already centres the box in the
line), per-glyph `advance` bytes (replaced by `hmtx`), the fixed
16/24/48 size ladder (one native 48 px em; `scale` still multiplies
it), and the `baseline` header field (TT maps the typo
ascender/descender span onto the cell; Noto SC baseline lands at
~42 px from the cell top vs the old 46/47 -- a ~4 px shift, noted
not hidden). The reference's missing-glyph behaviour is preserved:
advance and draw nothing.

`stdlib/asterui/examples/ui_hello.ast` (APK proof only): include
fixed to `../aui.ast` (landed-layout fix, see W1 §0); the two
`.auf` `@embed`s removed; `app_init` calls `aui_set_font(0, 1)` /
`aui_set_fallback_font(0, 1)`; the icon `@embed`s moved to the
framework's single `@embed` owner (`asterui/assets/embeds.ast`:
new `ui_embed_icon48_png/raw/_len` accessors, following that
file's own documented rule -- `ui_hello.o` and `embeds.o` would
otherwise collide on `__aster_embed_0`; see compiler item C-2).
Icon bytes are PNG/bin, not fonts.

### 3. Headless verification

#### 3a. Adapter test -- PASSES (runs today)

`stdlib/asterui/tests/font_adapter_test.ast` (adapter + TT engine
+ fallback only; no `aui_impl.ast`, so it links under `link-obj`
today). Build:
```
aster build-obj stdlib/asterui/tests/font_adapter_test.ast -o font_adapter_test.o
aster build-obj stdlib/asterui/font_runtime.ast -o font_runtime.o
aster build-obj asterui/render/truetype.ast -o truetype.o
aster build-obj asterui/render/text.ast -o text.o
aster build-obj asterui/assets/embeds.ast -o embeds.o
aster build-obj stdlib/aster_std.ast -o std.o
aster link-obj font_adapter_test.o font_runtime.o truetype.o text.o embeds.o std.o -o font_adapter_test
qemu-aarch64 font_adapter_test   # twice; stdout byte-identical
```
Result: exit 0, `PASS: font_adapter` on stderr, stdout
byte-identical across two runs. Output (also frozen in
`stdlib/asterui/tests/baseline/font_adapter.pixels`):
```
RTADV zhong 48
RTADV A 29
RTADV han 48
GLYPHHASH zhong 20013 1 -625170944860969255
GLYPHHASH wen 25991 1 -7677076379245281856
GLYPHHASH zeng 22686 1 1244426333250364548
GLYPHHASH han 28450 1 -5365893267246241339
GLYPHHASH A 65 1 -2848678777850727158
GLYPHHASH zeng_fb 22686 3 8269206640803333703
GLYPHHASH A_fb 65 2 9014699099629516294
GLYPHHASH han2 28450 1 -5365893267246241339
RTFB 1 1 1
```
What this proves: TTC SC face by name (face 2); cmap U+4E2D ->
9544, U+6587 -> 20036, U+589E -> 13837 (the M4 fontTools values);
hmtx advances (CJK full em 48; Latin 'A' 29 -- the same 29 the
reference `font48_test` asserted for its 'A'); 8bpp AA bitmaps
(ink AND strictly-partial pixels asserted in-test for U+4E2D /
U+6587 / U+589E / U+6F22 / 'A'); U+6F22 renders from the system
font (it is OUTSIDE the old 54-glyph set); fallback on a
nonexistent path (1 event, reason 1 = no file) with U+589E from
the CJK atlas (src 3, 1bpp-upscaled: zero partial pixels) and 'A'
from the 8x8 font (src 2); U+6F22 misses in fallback (missing
counter +1, `RTFB 1 1 1`); reload renders U+6F22 byte-identically
(`han2` hash == `han` hash); zero decode failures, zero scan
overflows. Old `.auf` baselines are void -- the hashes above are
the new frozen baselines, recorded deliberately (new glyph source:
CFF outlines at 48 px, not pre-rendered `.auf` bitmaps).

Coverage correction found by the test: U+4E2D and U+6587 are NOT in
the hand-drawn 56-glyph atlas (probe: `ui_cjk_find` returns -1 for
both; the 54 characters cover `strings_zh.txt`, whose text does not
contain 中/文). The fallback CJK probe therefore uses U+589E 增
(atlas offset 256; also verified in-atlas: U+4E00 一, U+9009 选).
In fallback mode, 中/文 labels measure correctly (advance 48) but
draw blank until a system font is present -- that is the atlas's
known 56-glyph coverage limit, now stated explicitly instead of
assumed. Full 6763-glyph CJK coverage in fallback would need the
forbidden Noto-derived `.auf`, so it stays a TT-only property.

#### 3b. Full-stack test -- WRITTEN, PROMOTED (C-1 fixed in v0.23.81-dev, H-3)

`stdlib/asterui/tests/font_runtime_test.ast` proves the same
ground through the reference stack (`aui_headless_render` into a
360x240 buffer: label widths 96 for "中文", 48 for "漢", line
height 60, frame ink, `PIXELHASH rt_frame_tt/fb/tt2` lines, and
the fallback-metrics-do-not-move property). It compiles clean
(`build-obj` exit 0) and now LINKS (C-1 fixed, see below) -- the
suite [23/27] links it with the 8-object recipe, runs it twice
under qemu (exit 0, `PASS: font_runtime`, byte-identical stdout,
`rt_frame_tt == rt_frame_tt2`), and diffs stdout against the
frozen baseline `stdlib/asterui/tests/baseline/font_runtime.pixels`
(frozen 2026-11-15, v2.5.2). The test is also one of the 42 C-1
tests promoted to [24/27] (linked + run there via `nb_run`).

#### 3c. Reference font tests -- SKIPPED (cannot run, two reasons)

- `font48_test.ast`, `font24_test.ast`, `cjk_test.ast` (and every
  other reference test): they `@embed` `.auf` files that do not
  exist in the landed tree, AND they carry the broken landed
  include (`../stdlib/asterui/aui.ast`, see W1 §0). They were
  skipped, not adapted: adapting 77 tests is suite-wiring scope
  (W1/coordinator), and the two new tests above replace the font
  ground they covered (TTC lookups, out-of-set CJK, Latin,
  fallback, frozen hashes) against the new glyph source.
- `text_test.ast` is in the same skipped set (it embeds
  `font_latin.auf`).

### 4. APK proof

`ui_hello` (adapted as in §2) built per-file `--pic` + `link-so`
(recipe from `tests/ui-checks.sh`, plus `--page-size 16384` per
W1 §(a) -- W1 verified target-sdk 35 works, so 35 is used):
```
aster build-obj --pic stdlib/asterui/aui_impl.ast stdlib/asterui/font_runtime.ast \
  asterui/render/truetype.ast asterui/render/text.ast asterui/assets/embeds.ast \
  stdlib/aster_std.ast stdlib/asterui/examples/ui_hello.ast
aster link-so --soname libuihello.so --needed liblog.so --needed libandroid.so \
  --needed libc.so --needed libm.so --page-size 16384 <objs> -o libuihello.so
# linked 7 objects (989 exports, 32 PLT imports, 30 GOT imports, 4 DT_NEEDED)
# libuihello.so: 795,432 bytes, SHA-256 1efbf06d7d1e3a3742dd91263ecf370cfdd26fcf842f35f37e32529f94077692
# readelf: all LOAD Align 0x4000
aster build-apk libuihello.so -o ui_hello.apk --package com.example.asterui.hello \
  --libname uihello --abi arm64-v8a --label "AsterUI Hello" \
  --min-sdk 24 --target-sdk 35 --page-size 16384 --version-code 1 --version-name "1.0"
aster verify-apk ui_hello.apk   # OK (v1 + v2 signatures verified)
unzip -l ui_hello.apk           # 7 files; NO .ttf/.ttc/.otf/.auf entries
```
Deliverable: `~/workspace/your_files/asterui-hello/ui_hello.apk`
(816,254 bytes,
SHA-256 `0a743dd784e3b3e39d235272a7dc7b06960cf6d02350c50799e44f9f8dbf7e04`,
debug-signed) with `libuihello.so` beside it. (An earlier
target-sdk 34 / 4K-page build was superseded: 771,198 bytes,
SHA-256 `976ed0d2a402952ce3cfc8424ac0f075b811806b3c7681e62641ed8225772288`.)
`.so` data offset in the APK is 16384 exactly, as in W1 §(a).
Device rendering is NOT yet proven headlessly: the C harness
(`tests/ui-android-harness.c`) is Counter-specific (it dlsyms
`asterui_counter`, which `ui_hello` does not export), and the
full-stack headless test is blocked on C-1 -- so the first render
proof for this `.so` is the user's phone, as with the M1/M2 APKs.

Reference-gate status of this `.so` (not a font issue):
`tools/check_so.py` FAILs it exactly as W1 §(c) describes --
30 self relocations / 30 duplicate UND names (W1's 26, plus 4
stdlib comparators `cmp_i32_asc/cmp_i64_asc/cmp_str_asc/cmp_u8_asc`
pulled in via `std.o`), 0 bad verneed, 0 nonexistent imports.
Same compiler item (c); the font surgery adds no new shape.

### 5. Limitations (what the surgery does NOT cover)

- No shaping, bidi, kerning, ligatures, or fractional sizes --
  the reference v1 boundary, unchanged.
- M4 engine limits carry over VERIFIED still applicable after the
  surgery (they live in the engine, which the surgery does not
  touch): deep Latin descenders clip at the cell bottom (em-box
  mapping, typo ascender/descender span == upm); FDSelect format 0
  is implemented but untested (Noto uses format 3; DejaVu has no
  CFF); CFF flex ops implemented but unexercised by the test
  fonts; cmap formats 6/14 not parsed (4/12 cover the test fonts);
  malformed charstrings degrade to wrong glyphs, never a crash
  (bounded loops, in-bounds reads); raster-timing getters answer 0
  headlessly (no clock injected).
- Fallback coverage is 56 glyphs only (54 + 2 fullwidth); 中/文
  are NOT among them (see §3a). Any CJK outside those 56 renders
  only when a system font is present. Full-width/emoji/CJK
  Extension B code points are measured wide (48 px) but have no
  fallback glyph.
- The fallback ASCII glyphs are the 8x8 font upscaled x3: legible
  but blocky; the fallback CJK glyphs are the 16x16 atlas upscaled
  x3: same. This is a degraded mode only (no system font); on any
  real Android device the system font is present.
- Per-glyph `xoff`/`yoff` and the old `baseline` field are gone
  (see §2); mixed Latin/CJK baselines now share the TT em-box
  mapping, which puts the Noto SC baseline ~4 px higher than the
  old `font_latin48` baseline 46. No visual check on device yet.
- Cold first-frame cost: the 19.5 MB TTC is slurped and parsed on
  first text use (lazy init); the M4 note about first-Gallery-open
  jank applies to the reference's first text frame too. No
  measurement was taken here.
- `aui_set_font` / `aui_set_fallback_font` still accept a pointer
  for API compatibility but ignore it; any caller still passing an
  `@embed`d `.auf` pointer fails its own build at the `@embed`,
  not at the call -- the 72 unadapted files are the visible form
  of that (W1 wiring scope).
- The Android backend does not yet log the fallback outcome
  (`aui_rt_fallback_events/reason` are recorded, not logged);
  wiring a log line into `aui_android_attach`/`onCreate` is a
  small follow-up, deliberately not done here to keep this change
  to the font path.

### 6. Compiler-cooperation items (for the compiler side -- NOT worked around here)

Per the user's guardrail ("needs-compiler-cooperation goes to the
compiler side"), these were STOPPED, not dodged in the reference:

#### C-1. link-obj/link-pie reject run-time global initializers in non-_start objects -- FIXED in v0.23.81-dev (H-3), tests promoted 2026-11-15 (v2.5.2)

Status: FIXED. The linker (`linkObjects()`, `src/aster.cpp`) now
synthesizes an 8-byte entry stub when the `_start` object has no
run-time global initializer of its own but another linked object
does (BL first initializer + B `_start`); `checkInitOrder` (A-21)
is unchanged. The `font_runtime.pixels` baseline is frozen. The
original requirement below is kept for the record.

Promotion status 2026-11-15 (v2.5.2): all 42 links succeed. 3
tests run green and are promoted to the suite [24/27]
(`nav_test`, `font_runtime_test`, `probe1_harness`). The other
39 link but fail at runtime on geometry/pixel expectations
written against the old reference layout (pre-W3 SafeArea floor,
`.auf` font metrics) -- verified by a standalone sweep (42/42
link, 3/42 exit 0, the rest exit 2-9 on the tests' own assertion
codes; e.g. `anim_test` rc=2, probed: the white card renders but
~20 px lower than the old expectation, the SafeArea floor). Same
class as the 16 harnesses re-baselined 2026-11-14. They are
link-gated in [26/27] (a link failure goes red; runtime exit
codes are tallied) pending a re-baseline pass that must verify
each new expectation rather than blindly accept current
rendering.

Re-baseline done 2026-11-15: all 39 re-baselined and promoted to
[24/27], so all 42 C-1 tests now run green in the suite
(central sweep: 42/42 exit 0, each run twice). Every new
expectation was probe-verified against the VM TrueType face
(`aui_rt_set_font_path` to the VM NotoSansCJK TTC before
rendering), never re-based to fallback metrics. Common root
cause: SafeArea floor (+24 px) + TrueType metrics (60 px line at
scale 1, 120 px at scale 2). Two tests needed more than new
numbers: `sheet_test` -- at scale 2 the sheet content (560 px)
overflowed the 85%-capped card (231 px), so the inner button sat
outside the card and viewport and was unreachable (rc=10);
arrange is sequential (probed), paint and hit-testing already
clip to the card, and the HuxerUI BottomSheet likewise clips
rather than scrolls, so the fix is test-side (scale 1 +
320x400 viewport, card [16,116,288,260]); `cjk_test` -- check 6
asserted that disabling the fallback removes CJK ink, but the
old two-.auf-font toggle has no runtime mechanism
(`aui_set_fallback_font` is a no-op in rt_mode); checks 6/9 now
test the real fallback chain instead (bad path returns 0, width
stays 384, the 7 misses are counted, atlas-covered "一三" still
draws ink 3312; reloading the good face restores TT ink 4124).
Scale map after the pass: 25 tests at scale 1, 14 at scale 2
(the scale-2 ones keep their original scale with probe-verified
TT values; `font24_test` deliberately stays scale 2 -- it is the
96 px em / 120 px line case). W7 (2026-11-15, scale unification):
all 15 scale-2 tests among the 42 (the 14 above plus `nav_test`,
promoted in v2.5.2) are now at scale 1, probe-verified under the
VM TrueType face -- 0 left at scale 2. `font24_test` needed no
exception: at scale 1 it still measures the same intent (A advance
29 = hmtx 605/1000 x 48, CJK full em 48, line height 60).
Viewports enlarged where the TT
content no longer fits the old viewport (text 560x960, dialog
320x480, menu 320x400, popup 320x520, tooltip 360x480, select
320x360, shape_aa 320x360, pager/tabs/sheet 320x400, headless
480x320); each enlargement is justified in the test's header.

What the compiler must do: accept a program whose run-time global
initializers live in an object other than the one holding `_start`
(e.g. run initializers from every linked object, or allow the
`_start` object to reference other objects' initializer tables).

Why: the reference library carries three run-time global
initializers -- `stdlib/asterui/aui_impl.ast:100`
`let g_aui_nodes: ptr<AuiNode> = g_aui_node_pool;`, `:104`
`let g_aui_cmds: ptr<AuiCmd> = g_aui_cmd_pool;`, `:848`
`let g_aui_page_cmds: ptr<AuiCmd> = g_aui_page_pool;`
(pointer globals initialized from pool arrays). Any `link-obj` /
`link-pie` of a program that links `aui_impl.o` separately fails,
even for a minimal `main() { return aui_version(); }`:

```
aster: error: <test>.o: it defines _start, but the run-time global
initializers live in aui_impl.o; initializers are entered from the
object that holds _start -- put one there, or build a single object
that holds both
```

Minimal scope: the linker change only (no language change, no
`.ast` change). The reference was NOT changed to dodge this
(the three initializers are the reference's own design; lazy
initialization would have been a reference-side workaround and was
refused under the guardrail).

Acceptance test (proves it works): build + link + run the
already-written `stdlib/asterui/tests/font_runtime_test.ast`
with the recipe in §3b (8 objects: test + `aui_impl.o` +
`font_runtime.o` + `truetype.o` + `text.o` + `embeds.o` +
`std.o` + `fake_ndk.o`), run under `qemu-aarch64` twice; expect
exit 0, `PASS: font_runtime` on stderr, stdout byte-identical,
and `PIXELHASH rt_frame_tt` / `rt_frame_fb` / `rt_frame_tt2`
lines with `rt_frame_tt == rt_frame_tt2`. That run also unblocks
freezing `tests/baseline/font_runtime.pixels`. (The same failure
blocks every other reference test link too -- `run_qemu.sh` links
`headless_test.o + aui_impl.o` the same way -- so this item is on
the critical path for ALL reference-suite wiring, not just fonts.)

#### C-2. Per-file `@embed` symbol collision (`__aster_embed_0`) -- forces the single-owner rule

What the compiler must do: namespace `@embed` blob symbols per
source file (e.g. `__aster_embed_<file>_<n>`) so two objects that
each `@embed` a file can link together.

Why: today the compiler numbers blobs per file starting at 0, so
any two objects with an `@embed` collide at `link-so`:
`aster: error: duplicate global symbol '__aster_embed_0' across
input objects`. The framework works around it with a
single-`@embed`-owner rule (`asterui/assets/embeds.ast`), which
the font surgery followed for `ui_hello`'s icon -- but that rule
does not scale: all 34 reference examples `@embed` their own
assets, and every one would need the same hand-move. Minimal
scope: symbol naming only; no change to `@embed` semantics.

Acceptance test: build `ui_hello.o` WITH its own top-level
`@embed("assets/icon48.png")` (revert the embeds.ast accessor
move) and link it together with `embeds.o` via `link-so`; expect
exit 0 and no duplicate-symbol error. (Secondary check: two
probe `.ast` files each embedding a different file link cleanly
into one `.so`.)

Note: C-1/C-2 are separate from the four reference patches already
tracked (16K page: SATISFIED per W1 §(a); configChanges: compiler
item (b); link-so funcaddr: compiler item (c); no-verneed:
SATISFIED-with-residual per W1 §(d)). The nested-call segfault
(`ui_dp(ui_text_width(...))`, M3) was already reported to the
compiler side and is not re-specified here.

## W3 merged wins (2026-11-14, worker W3)

Compiler under test: `~/workspace/projects/Aster-env/aster`
(v0.23.79-dev + local fixes). Scope: merge our M0–M4 device-verified
wins into the reference backend, keeping whichever side is better
with evidence. All three new W3 tests run headless under
`qemu-aarch64` (see §3b for the link recipe). Reference state is
quoted from `aui_impl.ast` as landed; our state from
`~/workspace/projects/Aster/asterui/` (read-only).

### W3-1. Touch bridge: f32 route KEPT — measured, both routes pass under qemu

Reference state: `event_x/event_y` (`aui_impl.ast:13771-13780`)
call `AMotionEvent_getX/Y -> i32` (:987-988) then `lrintf()` with no
arguments (`extern fn lrintf() -> i32` at :1001) — the s0→lrintf
zero-arg bridge. Reference claims v1.4 device verification.

Our state: `asterui/backend/android.ast` `android_event_x/y`
(~:493-501) use `f32` returns (`AMotionEvent_getX/Y -> f32`),
adopted in M1.2a after the s0 bridge returned `(0,0)` for every tap
on the user's Android 16 phone (1216x2688 @ 520 dpi).

Measurement (`stdlib/asterui/tests/bridge-check.sh`,
`bridge_probe.ast` verbatim reference bridge, `f32_probe.ast`,
`bridge_harness.c`, `check_bridge.py`; probe `.so` linked with the
reference's actual conditions — explicit libm DT_NEEDED, default
lazy binding; `build.sh` contains no BIND_NOW anywhere, and
`build-apk` sets no binding flags, so the "different link
conditions (libm + BIND_NOW)" hypothesis fails on its face):
six coordinate pairs incl. round-half-even cases, fresh process per
mode so the first call is cold-PLT. Results, 2026-11-14:

| mode | bridge | f32 |
|---|---|---|
| (a) RTLD_LAZY cold-PLT | 6/6 | 6/6 |
| (b) RTLD_NOW eager | 6/6 | 6/6 |
| (b2) RTLD_LAZY + LD_BIND_NOW=1 | 6/6 | 6/6 |

Disassembly check also passes for both (`get -> lrintf` adjacent,
2 insns between, none writes s0/d0/q0/v0). qemu/glibc cannot
discriminate — same as M1.2a's earlier finding (old bridge passed
8/8 under qemu in both modes while failing on device). The
reference links explicit libm + default lazy binding, exactly our
M1 failing configuration (our M1 `.so` had DT_NEEDED
liblog/libandroid/libc/libm, lazy). Same phone, same link
conditions, opposite outcomes → the reference's v1.4 trace claim
does not reproduce; the device measurement (all taps `(0,0)`) stands.

Kept: the f32 route. The bridge code stays in the reference as-is
(not deleted — it is the user's own code, and it passes under qemu);
nothing in the reference was hacked to dodge a compiler gap, and no
compiler cooperation is needed for this decision (BIND_NOW is not
producible by current `link-so`, but nothing in the measurement
requires it). The suite gains the cold-PLT case either way:
`bridge-check.sh` gates the f32 route in all three modes and
reports the bridge result informationally.
Re-run 2026-11-14: `PASS: bridge-check (f32 route true in all
binding modes)`, exit 0.

### W3-2. Input-type constant: code CORRECT, design doc stale

Reference code (`aui_impl.ast:14934-14940`, `aui_on_input`):
comment states `AINPUT_EVENT_TYPE_KEY=1, AINPUT_EVENT_TYPE_MOTION=2`,
and code dispatches `typ == 2 → handle_motion`, `typ == 1 →
handle_key`. Correct per NDK. (The v1.3 history comment there notes
"v1.3 曾误写成 1" — the D.8 fix is real.)

Stale doc line (recorded, not silently fixed):
`docs/AsterUI-design.md:723` (§10.1): "事件类型：
`AInputEvent_getType` 返回 1 = motion，2 = key" — opposite of NDK
and of the code. No code change, no harness case needed (the
routing test below exercises motion vs key paths end to end).

### W3-3. Logging: merged (file log + logcat + viewer; trace.txt kept)

Reference state: `trace.txt` only — `trace_init`
(`aui_impl.ast:14998-15040`, external dir only,
`O_WRONLY|O_CREAT|O_TRUNC` 577, milestone letters S/V/d/I/K/W/N/L/
P/F/R/X + T/x/y touch + a/e + q/w). `__android_log_print` extern'd
at :972 but never used.

Our state (`asterui/runtime/log.ast`, M1.1): `ui_log` lines
`"[<ms>] <L> AsterUI: <msg>\n"` (i64 ms, levels 2–6 V/D/I/W/E),
internal + external `<dir>/asterui.log`, 128 KiB rotation via
`file_size` check + truncate, open-per-line `O_WRONLY|O_CREAT|
O_APPEND` 1089, logcat mirror, `ui_log1/2/3` number builders,
in-app viewer (last 40 lines, footer toggle in Counter).

Merged into `aui_impl.ast` (PIC build now 106361 instructions,
770 functions, 734 globals):
- Globals after the trace globals: `g_aui_log_path1/path2: u8[256]`,
  `g_aui_log_set`, `g_aui_log_lines`, `g_aui_log_line: u8[512]` +
  `g_aui_log_line_len`, `g_aui_log_msg: u8[256]` + `g_aui_log_msg_len`.
- New functions after `trace_init`: `aui_log_fmt_i64` (decimal i64,
  no i64 `%` — `/10` + subtraction like `i32_to_str`),
  `aui_log_level_letter`, `aui_log_now_ms` (`clock_ns()/1000000`),
  `aui_log_join` (dir + `"/aui.log"`), `aui_log_init(internal, ext)`,
  `aui_log_set_file(path)` (headless/test hook, primary only),
  `aui_log_lines()`, `aui_log_file_size` (open + fstat +
  `load_i64(&st+48)`), `aui_log_append_one` (truncate if >131072,
  then O_APPEND 1089, looped write), `aui_log_format`,
  `aui_log(level, msg)` (files + `__android_log_print(level,
  "AsterUI", msg)`; never fails the caller; `%` must not appear in
  msg), `aui_log_msg_begin/str/i32/end`, `aui_log1`, `aui_log2`,
  `aui_log_tail(out, cap)` (skips to last `cap` bytes, returns bytes
  copied, -1 no path, 0 empty/missing).
- Wiring: `aui_android_attach` reads the internal dir at
  `activity+32`, calls `aui_log_init(internal, ext)`, logs
  `"aui: attach"` (INFO). `aui_cb_win_created` logs window size via
  `aui_log2`. `aui_cb_lowmem` (was a bare `return 0` stub) now logs
  `"aui: onLowMemory"` (WARN). `aui_shutdown` logs `"aui: shutdown"`.
- `aui.ast`: extern decls added in the session section: `aui_log`,
  `aui_log1`, `aui_log2`, `aui_log_lines`, `aui_log_tail`,
  `aui_log_set_file`.
- Format: `"[<ms>] <L> AUI: <msg>\n"`, tag `AUI: `, logcat tag
  `"AsterUI"`. `trace.txt` milestone letters untouched.
- Viewer (reference-idiom, example-level, not a framework paste):
  `examples/ui_system.ast` gained a "Log (aui.log tail)" section —
  Show/Hide button (key 71) + `aui_log_tail` into a 2048-byte buffer
  + per-line `aui_label_n(900+i, ...)` (max 12 lines, re-read per
  build while open). `SysApp` gained a `log_open` field.
  The example still cannot compile as landed (missing
  `font_latin48.auf` `@embed`, W1 landing gap); the edit was verified
  by compiling a /tmp copy in the original top-level-`examples/`
  layout with a dummy `.auf` — `build-obj` exit 0, 534 instructions.

Evidence — `tests/w3_log_test.ast` (exit 0, qemu):
fake clock set to 40 days (`i64(3456000) * i64(1000000000)` ns),
`aui_log_set_file("w3_log_test.log")`, asserts the line format
`"[3456000000] I AUI: w3 first"`, no `"[-"` (M1.2b
negative-timestamp guard shape), `aui_log_lines() == 5003` after
5000 rotation lines + marker, tail (8192 cap) contains
`"w3 LAST-MARKER"` but not `"w3 first"` / `"w3 rot 0"`.
Final log file from the clean re-run: 872 lines, 27907 bytes
(truncated once past 128 KiB, first surviving line `"w3 rot 4129"`),
0 occurrences of `"w3 first"`, 1 of `"w3 LAST-MARKER"`, 0 of `"[-"`.

### W3-4. SafeArea + dp scaling: merged (reference interface + our always-on floor)

Reference state (`aui_impl.ast:11373+` `calc_insets`,
`aui_set_insets`:8003, `aui_safe_*`:7977-7986,
`aui_edge_to_edge`:7994, `aui_set_system_bar`:8020):
content-rect (`g_aui_ct_*`, set by `aui_cb_rect`:15311 /
`aui_debug_set_content`:16034) + 24dp estimate **only when
`sdk>=35 && e2e==0 && full`** + manual minima via `aui_set_insets`
(max, not add) + system-bar strip.

Our state (M1.1/M1.2c): density estimate 24dp always + content-rect
max; dp via q8 fixed point (`ui_dp`, `(dpi*256+80)/160`, 48dp min
touch target as hit slop); frozen 160dpi snapshots + 320dpi
doubling assertions.

Merged: one condition change in `calc_insets` — the guess now runs
when `g_aui_e2e == 0 && (full != 0 || g_aui_ct_valid == 0)` (was
`g_aui_sdk >= 35 && g_aui_e2e == 0 && full != 0`). Reference's
manual-compensation interface + content-rect-max kept; our always-on
24dp estimate is the floor when there is no content rect yet
(startup transient) or the rect is full-window, on any SDK.
`aui_edge_to_edge(1)` still disables the guess; `E` trace letter
unchanged. Before this change the no-content-rect case returned
safe_top 0 (measured); after, 24.

Evidence — `tests/w3_dp_scale_test.ast` (exit 0, qemu; root column
pad 16, spacers key 10 = 24dp / key 11 = 48dp, button 12):
A. 160dpi frozen baseline — spacer10 x=16 y=40 h=24 (y = inset 24 +
column pad 16), spacer11 h=48; B. no content rect → safe_top 24,
bottom 24, left/right 0; C. 320dpi exact doubling (x=32, y=80,
h=48/96), safe_top still 24dp; D. `aui_debug_set_content(0,78,320,
240)` at 160dpi → safe_top 78, bottom 0 (content rect wins);
E. `aui_set_insets(0,32,0,0)` → still 78, then full content rect →
32, then reset insets → 24; F. restore 160dpi + invalid content
rect → frozen baseline again. (Debugging note: spacer y is inset +
column pad, not inset alone — first draft asserted 24, probe showed
40; the code was right, the expectation was wrong.)

### W3-5. Tap routing + scroll drag: reference already had it — verified, not re-implemented

Reference state (verified in code, `handle_motion`:13871+,
`handle_key`:13783+, `menu_pointer_down/move/up`:7669-7743,
generic UP tail:14763+):
- Press-by-key: `g_aui_press_key`/`g_aui_pressing`; generic UP fires
  only when `down != 0 && key == was && was_drag == 0`
  (re-resolved by key against the rebuilt tree — per-frame rebuild
  reuses nodes by key, so the property holds by construction).
- 8dp slop everywhere (`dp2q(8) >> 16`): drag cancels press
  (`g_aui_pressing = 0` when dragging starts); drag past slop
  writes `scroll_set` from `drag_off0` and `trace_hex(118,...)`
  (v = offset).
- Menu modal + tap-outside: DOWN with menu open →
  `menu_pointer_down`; UP `dh == -1` → `menu_close(
  AUI_MENU_REASON_OUTSIDE)` with no firing underneath; `dh == -2`
  (menu face/padding) swallowed; item fires only if UP hit == DOWN
  hit; drag cancels press; long-menu internal scroll.
- Dialog scrim: kind 23 tap → `g_aui_dialog_reason = 1` (scrim tap
  CLOSES the dialog); card blank swallowed by noop.
- BACK priority (kept as-is): tooltip → menu → sheet → popup →
  dialog → combo → select → focus → pop → finish; BACK acts on UP
  (long-press DOWN doesn't multi-pop); `handle_key` only handles
  KEYCODE_BACK (4).

Our state: DOWN+UP logical-key record, layer-first, scrim swallow
(dialog stays open; `android_tap_up` logs fired 1), menu
tap-outside, 8dp slop, MOVE→drag injectors. No code change was
needed in `aui_impl.ast` for this item — the merge is verification
+ the harness case below. Two genuine differences, both resolved in
the reference's favour:
- Scrim: ours swallows (dialog stays), reference closes on scrim
  tap — standard Android behaviour, kept the reference's.
- Menu/dialog coexistence is asymmetric and the test had to learn
  it: `menu_open` refuses to create a menu while a dialog is open
  (:3578-3581: "对话框/下拉是更底层的模态层，同时存在时不创建菜单"),
  while `aui_dialog` does NOT check the menu (:3324-3328). So
  dialog-first + menu-second never coexists; menu-first +
  dialog-second does — that is the only state in which the BACK
  priority (menu before dialog) is reachable, and the test builds
  the menu block before the dialog block for exactly that reason.

Evidence — `tests/w3_routing_test.ast` (exit 0, qemu; 320x480,
`aui_set_font(0, 1)` so two 76px buttons + a scrollable list fit;
geometry always read at runtime via `aui_debug_rect` /
`aui_debug_menu_item`, never hard-coded; reason values ITEM=1,
OUTSIDE=2, BACK=3 for menus, scrim=1 / BACK=2 for dialogs):
A. dialog OK fires + closes; B. dialog Cancel fires + closes;
C. scrim tap closes reason 1 + Under button not fired; D. tap on
card top padding: nothing happens (dialog stays, Under 0) — the
Under button sits above the card, so tapping it would land on the
scrim (already proven in C), not on the button; E. BACK closes the
dialog reason 2, then the Under button works again; F. drag-off
(DOWN on Under, MOVE to (4,4), UP there) fires nothing;
G. menu item pick (item 71, reason 1, menu closed); H. menu
tap-outside on Under center (reason 2, Under not fired);
I. BACK priority — dialog AND menu open, BACK closes the menu
reason 3 with the dialog still open, BACK again closes the dialog
reason 2; J. MOVE drag from Row C up 120px → `aui_debug_scroll(10)
== 120`, Row C rect moved by exactly 120, no row fired, then tap
Row C at its new position fires once (Row A is scrolled out of the
viewport, so it is not tapped).
Debugging notes from writing J: (1) direct field sets
(`g_t.open = 1`) need `aui_invalidate()` before render — the
retained tree only rebuilds when invalidated (same pattern as
`dialog_test`); without it the dialog/menu nodes never appear.
(2) The column itself needs `aui_weight(1)` (as in
`scroll_test:36`): without it the column wraps its content, the
scroll viewport gets height 0, scrolled children fall outside the
hit-test clip, and the drag never starts (probe showed viewport
h=0, scroll offset stuck at 0).

Existing reference coverage for the record: `tests/dialog_harness.ast`
(scrim/BACK/Cancel, node-count restore, pixels; codes 10–25),
`tests/menu_harness.ast` (item pick, disabled item, outside
reason 2, BACK reason 3, long-menu drag scroll, dark theme;
codes 10–25, 90), `tests/list_harness.ast` (MOVE drag scrolls list,
offset == drag distance, child moves, tap-after-scroll hits;
codes 20–25) prove parts of this — but none can build as landed
(include path + `.auf` `@embed`s). `tests/dialog_test.ast`,
`tests/menu_test.ast`, `tests/scroll_test.ast` are the headless
models the W3 tests copy (helpers `tap/down/move/up/back`,
`render() = aui_headless_render`, `aui_debug_set_density(160)`).

### Reference BETTER (kept as-is, no merge needed)

- BACK-key priority order (tooltip → menu → sheet → popup →
  dialog → combo → select → focus → pop → finish) — ours lacks
  it entirely; verified by W3-5 section I.
- Fling (`fling_start`/`fling_stop`, velocity via `drag_sample`,
  `|v| > 200000` + age < 80ms) — ours has none; not touched, only
  noted.
- Frame pump + animation/transition (`aui_frame`, `page_refresh`,
  `aui_invalidate_scroll` light layout) — the drag path already
  uses it (`scroll_set` → `aui_invalidate_scroll`); ours has no
  equivalent.
- Close-on-scrim dialog behaviour (see W3-5) — standard Android,
  kept over our swallow.
- i64 log timestamps: ours had them, reference had trace letters +
  relative values only — merged (W3-3), not a reference win.

### How to build + run the W3 tests

The reference tests cannot build as landed (W1: include path +
missing `.auf`; `run_qemu.sh` is stale — it does not link
`font_runtime.o`). The W3 tests use `include "../aui.ast"` (W1 fix
direction) and are font-free (W2 runtime-font fallback). Build from
a scratch mirror of the repo layout (symlinks under
`/tmp/aui-adopt/landed/`, see W2 §3b) with the compiler at
`~/workspace/projects/Aster-env/aster`:

```
# per-file, non-PIC build-obj, then link-obj (8 objects):
$ASTER build-obj stdlib/asterui/tests/w3_dp_scale_test.ast -o w3_dp_scale_test.o
$ASTER build-obj stdlib/asterui/tests/w3_log_test.ast -o w3_log_test.o
$ASTER build-obj stdlib/asterui/tests/w3_routing_test.ast -o w3_routing_test.o
$ASTER link-obj <test>.o aui_impl.o font_runtime.o truetype.o text.o \
    embeds.o std.o fake_ndk.o -o <test>
# run from a clean cwd (the log test writes w3_log_test.log there):
qemu-aarch64 ./w3_dp_scale_test   # expect exit 0
qemu-aarch64 ./w3_log_test        # expect exit 0
qemu-aarch64 ./w3_routing_test    # expect exit 0
sh stdlib/asterui/tests/bridge-check.sh   # expect PASS, exit 0
```

Linker rules that bit during this work (same as W2 §3b): at least
one run-time global initializer must live in the object holding
`_start` (font-free tests carry `let g_anchor: ptr = g_buf;` as
the anchor); `len` is a reserved intrinsic (cannot be a parameter
name — renamed to `blen` in `w3_log_test.ast`); bare `libc.so` /
`libm.so` DT_NEEDED names resolve under qemu to linker-script files
— create `libc.so`/`libm.so` → `.so.6` symlinks in the out dir
(same trick as repo `tests/guest-libc-alias.sh`).

### W3 compiler-cooperation specs

None new. The bridge decision needs no compiler cooperation (see
W3-1). The W1 items (b) configChanges 0x490→0x1F90 and (c) link-so
funcaddr remain compiler-side per the user's guardrail decision and
were not worked around here; the W2 items C-1 (linker initializer
rule) and C-2 (`@embed` symbol collision) are already specified
above. The nested-call segfault (`ui_dp(ui_text_width(...))` in a
large function, M3) is still owed by the UI side as a minimal repro
and is not re-specified here. `run_qemu.sh` staleness (no
`font_runtime.o` link, include path, missing `.auf` `@embed`s) is
an adaptation item, not a compiler item.

## W4 tests + apps (2026-11-14, worker W4)

Compiler under test: `~/workspace/projects/Aster-env/aster`
(v0.23.79-dev + local fixes). Scope: include/`@embed` fixes, suite
wiring in `tests/ui-checks.sh` (NOT `tests/ci.sh`), three apps, device
delivery. Did NOT touch `src/aster.cpp`, `bootstrap/`, `tests/ci.sh`,
or any other `tests/*` file; the old `asterui/` tree is untouched.
Scratch that survives: `~/workspace/w4-scratch/` (`/tmp` was wiped
mid-task -- VM restart or tmpfs clear -- so the `/tmp/w4` matrix
evidence below survives only in this section).

### W4-1. Landed includes + dead `@embed`s -- DONE

- 78 `include "../stdlib/asterui/aui.ast"` lines rewritten to
  `include "../aui.ast"` in 78 files (script
  `/tmp/w4/w4_fix_includes.py`, since wiped with `/tmp`).
- 77 dead `@embed("*.auf")` lines neutralised in 73 files:
  `let g_X: ptr = @embed("...");` became `let g_X: ptr = 0;` with a
  `// W4:` marker comment. Plus `ui_hello.ast`'s 2 lines fixed by W2,
  the landed total is 79 lines in 74 files (W2 said "73 files" -- it
  missed `examples/probe2_text.ast`). Per-file: 32 examples (incl.
  `probe2_text`; `ui_select` had 2 lines), 41 tests (`cjk_test`,
  `font24_test`, `font48_test` had 2 each).
- Why `0` is correct, not a stub: every `.auf` embed was a
  `let g_*: ptr = @embed(...)` used only via `aui_set_font` /
  `aui_set_fallback_font` (plus `nav_test`'s `let f: ptr = g_font;`),
  and since W2 those calls ignore the pointer (`g_aui_rt_mode == 1`).
  No stub font was invented. Non-`.auf` embeds were untouched
  (`png_test`'s real PNGs, `ui_hello`'s icon comments).
- Extra fix found by the matrix: the reference helper `starts_with`
  (`examples/ui_combo.ast:25`) collides with stdlib's
  (`stdlib/aster_std.ast:1115`) at link time when `std.o` is present
  (the font-runtime chain needs `std.o` for `memset`). Renamed to
  `combo_starts_with` in `ui_combo.ast` (7 uses) and `combo_test.ast`
  (4 uses). This unblocked `combo_harness` (now exit 0).
- Compile gate (`tests/ui-checks.sh` [22/27]): 122/122 `build-obj
  --pic` exit 0 (34 examples + 86 tests + `aui_impl` + `font_runtime`;
  `aui.ast` itself is extern-only and excluded, per W1 §0).

### W4-2. C-1 refined by measurement (the anchor rule)

- The verbatim C-1 error was re-verified for the unanchored
  `font_runtime_test.ast` (see W2 §6).
- New precision: the link fails ONLY when the `_start` object has NO
  run-time global initializer of its own. Tests carrying
  `let g_anchor: ptr = g_buf;` (all 3 W3 tests, all 31 harness files,
  `nav_watchdog_test`) link and run correctly -- and `aui_impl`'s
  pool-pointer initializers DO run in the anchored link (proved by
  the W3 tests rendering real trees: `g_aui_nodes` would be 0
  otherwise and node access would crash).
- Deliberately NOT used as a workaround for the blocked tests: adding
  one anchor line per test would make W2's C-1 acceptance test
  (`font_runtime_test.ast` as written) pass without any compiler
  change. The compiler fix has since landed (H-3, v0.23.81-dev):
  all 42 links succeed; 3 tests run green and were promoted to
  [24/27] on 2026-11-15 (v2.5.2), the other 39 were link-gated in
  [26/27] pending re-baseline and were re-baselined and promoted
  later the same day (see C-1 promotion status above).
- APK-path distinction re-verified: per-file `build-obj --pic` +
  `link-so` works for all three apps, so C-1 blocks test-executable
  linking only, never APK builds.

### W4-3. Empirical reference-test matrix (W3 8-object recipe, qemu)

Every reference test/harness linked with
`test.o + aui_impl.o + font_runtime.o + truetype.o + text.o +
embeds.o + std.o + fake_ndk.o` (harness tests add their example `.o`)
and run under `qemu-aarch64` in a fresh cwd, timeout 20 s.

- LINK-OK + exit 0 (20): `font_adapter_test`, `nav_watchdog_test`,
  15 harnesses (`android`, `list`, `form`, `nav`,
  `nav_transition`, `pager`, `dialog`, `tooltip`, `date_picker`,
  `refresh`, `chip`, `progress_circle`, `popup`, `ripple`, `combo`),
  `w3_dp_scale_test`, `w3_log_test`, `w3_routing_test`.
- LINK-OK + exit != 0 (16 harnesses): `system` 21, `anim` 19,
  `select` 34, `time` 90, `tree` 18, `toast` 14, `menu` 24, `icon`
  27, `layout` 24, `sheet` 20, `top_bar` 20, `nav_bar` 20,
  `nav_pane` 20, `vlist` 14, `vgrid` 14, `hlist` 14.
- LINK-FAIL C-1 (42): 40 plain `_test` files (`anim`, `chip`,
  `cjk`, `combo`, `controls`, `date_picker`, `dialog`, `dropdown`,
  `fling`, `font24`, `font48`, `headless`, `hlist`, `icon`,
  `layout`, `menu`, `nav_bar`, `nav_pane`, `nav`, `nav_transition`,
  `pager`, `popup`, `progress_circle`, `refresh`, `ripple`,
  `scroll`, `segmented`, `select`, `shape_aa`, `sheet`, `system`,
  `tabs`, `text`, `time_picker`, `toast`, `tooltip`, `top_bar`,
  `tree`, `vgrid`, `vlist`) + `font_runtime_test` +
  `probe1_harness` (initializers live in `probe1_red.o`).
- LINK-FAIL C-2 (1): `png_test` -- `duplicate global symbol
  '__aster_embed_0'`: its own PNG embeds collide with `embeds.o`,
  which `text.o` needs (`ui_embed_font_cjk16`); without `embeds.o`
  the link fails on that undefined symbol instead.
- Root causes sampled for the 16 failing harnesses (instrumented
  copies in scratch, `aui_log1` dumps): `top_bar` (exit 20) and
  `system` (exit 21) are the W3 SafeArea floor, not the font
  surgery. With no content rect yet, `safe_top` is now 63 px
  (24 dp @ 420 dpi) where the harness expects 0: top bar at y=63
  vs 0; system label at (63,126) vs (63,63). On a real device
  (sdk 35+) the old code would also apply the guess when the
  content rect is full-window, so the harness expectation is stale
  for devices, not a product bug -- but re-baselining the 16
  harnesses is follow-up work, not done here. `menu` (exit 24)
  fails at a later pixel/luminance check, not yet bisected. None of
  the 16 is a compiler block; all 16 fail at geometry/pixel
  assertions written against old `.auf` metrics and the pre-W3
  SafeArea rule.

### W4-4. Suite wiring (`tests/ui-checks.sh` [22/27]-[27/27], NOT `ci.sh`)

Full run 2026-11-14: `PASS: ui-checks (21/21 old + 6/6 new-base)`,
exit 0 (~3.2 min). Old 21 cases run first and stay green.

- [22/27] Compile gate: 122 files, 0 failures.
- [23/27] Font adapter (frozen `font_adapter.pixels` hashes +
  determinism) + `gallery_smoke_test` + `nav_watchdog_test`.
- [24/27] 15 green reference harnesses (see W4-3) + 16 re-baselined
  harnesses (2026-11-14) + `png_test` (C-2 fixed) + 42 C-1 tests
  promoted (3 in v2.5.2, H-3: `nav_test`, `font_runtime_test`,
  `probe1_harness`; 39 re-baselined 2026-11-15, see C-1 promotion
  status).
- [25/27] W3 log/dp/routing (exit 0) + `bridge-check.sh`
  (`PASS: bridge-check (f32 route true in all binding modes)`).
- [26/27] C-1 link gate (2026-11-15, v2.5.2; re-baseline complete
  2026-11-15): the old ratchet (links must fail) is retired; the
  section now requires all 42 links to succeed and tallies runtime
  passes (42/42 green -- see C-1 promotion status).
- [27/27] New-base APKs: Counter v2.0/code 7, Gallery v2.0/code 6,
  IME probe v2.0/code 3; target-sdk 35, 16K page, no font files,
  no dex, `ANativeActivity_onCreate` exported.

### W4-5. Apps (per-app decisions)

- Counter: ADOPTED the reference `examples/ui_hello.ast` as-is.
  It IS a counter (+/-/reset, switch, progress, icon, Chinese
  labels), so zero new code; covered headlessly by
  `android_harness` (exit 0 in the matrix). Deviations vs the old
  Counter: no in-app log-viewer footer toggle (the log is still in
  the `aui.log` file and in the Gallery/System viewer); count state
  via `aui_state_set(1)` instead of the old scope model; adds
  icon/switch/progress the old Counter lacked. Package
  `com.example.asterui.counter`, libname `counter`, v2.0/code 7.
- Gallery: NEW `examples/ui_gallery.ast` (W4; ASCII-only comments,
  UTF-8 Chinese literals like the reference files), composing the
  reference examples: TopBar (`ui_top_bar`), Tabs (`ui_tabs`, 5:
  Input / Overlay / Scroll / Nav / System), TextField + self-drawn
  keyboard (`ui_form`), Select (`ui_select`: English/German/中文),
  Switch/Checkbox/Slider/Progress, Dialog + Menu + Toast
  (`ui_dialog`/`ui_menu`), 30-row scroll list + tap-after-scroll
  (`ui_list`), NavStack push/pop (`ui_nav`), System theme toggle +
  safe-area readout + `aui.log` viewer (`ui_system`). Reason: no
  single reference example covers the old Gallery's 5-tab scope;
  composition reuses each example's proven patterns verbatim.
  New headless test `tests/gallery_smoke_test.ast` (exit 0): all 5
  tabs render; tapping the Overlay tab switches to it; dialog
  opens via "Delete draft", Cancel closes it (reason 3, drafts
  stay 2); menu pick records key 241; scroll drag moves the list
  by exactly 120 px and "Tap after scroll" counts 1; nav 1->2->1;
  Focus button focuses the field (key 110). Two findings while
  writing it (both test-side, documented in the test): (1)
  headless tests must call `aui_set_font(0, 1)` themselves --
  `app_init` never runs headlessly, and the default scale 2
  doubles every advance (dialog labels measured 600/1800 px tall,
  buttons pushed to y=2496); (2) reference tabs take intrinsic
  width and overflow narrow viewports (tab 12 centre x=444 at
  360 px wide), so the test renders 720x1280. Package
  `com.example.asterui.gallery`, v2.0/code 6.
- IME probe: KEPT the old probe source unchanged
  (`asterui/examples/ime-probe/main.ast`). Reason: it is
  framework-independent (bare NativeActivity, own rasterizer and
  logging, direct `ANativeActivity_showSoftInput` /
  `hideSoftInput` calls); the reference has no equivalent -- its
  keyboard is self-drawn nodes and never calls `showSoftInput`
  (no hit for `showSoftInput` anywhere in `aui_impl.ast`). Only
  the recipe changed: target-sdk 35, 16K page, v2.0/code 3. The
  old C harness still passes 9/9 against the new build (key
  logging with all fields, SHOW/HIDE flags, background-tap focus
  rules, SafeArea density 480 -> inset 72 / rect top 100 -> inset
  100 / floor 24, clean teardown). The device verdict stands
  unchanged: `showSoftInput` without an InputConnection produces
  no keyboard (kb 0, keys 0 on the user's Android 16 phone) --
  the probe re-measures it on the new base, it does not
  re-litigate it.

### W4-6. APK table + user checklist (device verification NOT done)

| App | Path | Size | SHA-256 | verify-apk |
|---|---|---|---|---|
| Counter v2.0/code 7 | `~/workspace/your_files/asterui-counter/counter.apk` | 817,686 | `574cbaf6311dc97e86599c18f0e473e7e74b502e1357bb8cead7607ac1d4bc1e` | OK (v1+v2) |
| Gallery v2.0/code 6 | `~/workspace/your_files/asterui-gallery/gallery.apk` | 837,782 | `933fa1361bea73336cf560d98d22d7c71fa07ba7d4f678466ca26d6f2e137cfb` | OK (v1+v2) |
| IME probe v2.0/code 3 | `~/workspace/your_files/asterui-ime-probe/ime-probe.apk` | 180,406 | `9f4d71a09134fa06b77a49ea2545c6e61c6560a0fb2beb6b246f43c349bf5b24` | OK (v1+v2) |

All three: no font files (`.ttf`/`.ttc`/`.otf`/`.auf`), no dex,
all LOAD segments Align `0x4000`, manifest minSdk 24 /
targetSdk 35 (AXML-decoded), `configChanges` still `0x490`
(AXML-decoded -- W1 item (b), compiler-side). `check_so.py`
FAILs all three exactly as W1 §(c) describes (Counter 30,
Gallery 47, IME probe 21 self-relocs; 0 bad verneed, 0
nonexistent imports) -- the link-so funcaddr compiler item;
glibc/qemu loads them, and the old M-series APKs shipped with
the same shape and installed fine on the user's phone.
Uninstall the old version of each app first (every build uses a
fresh debug key).

User checklist -- re-verify EVERY previously device-confirmed
behaviour on the new base (nothing below is proven until the
user confirms it on their Android 16 phone):
- Counter: install, count 0 -> taps (real coordinates in the
  log, no (0,0)), + / - / reset, switch toggles, progress bar,
  icon visible, Chinese labels render at system quality
  ("计数", "重置", "提醒", "已开启"), content fully below the
  status bar (SafeArea), text/buttons correctly sized at 520 dpi
  (dp scaling), background -> foreground keeps the count,
  lifecycle order on exit is onPause -> window destroyed ->
  onStop -> onSaveInstanceState (no onLowMemory phantom), log
  timestamps positive and increasing.
- Gallery: all 5 tabs switch by tap; Input tab: tap field,
  self-drawn keyboard appears, typing shows live, Clear/Focus
  work; Select opens, picks German/中文, closes on outside/BACK;
  Overlay tab: Delete draft opens a centred dialog, Cancel and
  Delete both work, scrim tap closes it, menu items are equal
  width and pick correctly, toast shows; Scroll tab: finger drag
  scrolls the list (thumb travels), "Tap after scroll" counts 1
  only after scrolling to the bottom; Nav tab: push page 2, BACK
  returns; System tab: dark toggle flips the theme (status-bar
  icons stay readable), safe-area numbers shown, log viewer
  opens and shows recent `aui.log` lines.
- IME probe: title fully below the status bar; tap field ->
  `showSoftInput IMPLICIT` logged; SHOW KB / HIDE KB buttons
  log FORCED / NOT_ALWAYS; background taps log nothing and focus
  nothing; keyboard appearance and key events are the measurement
  (expect kb 0 / keys 0, as before -- report what actually
  happens, do not assume it).
- Known deviation to check, not to be surprised by: rotate the
  phone or toggle dark mode / change density -> the app restarts
  to the home page and loses tab/drafts/scroll/text state (W1
  item (b): `configChanges` 0x490). Record whether it happens;
  rotation alone should NOT restart (0x490 already covers it).

### W4-7. Known deviations, blocked items, what remains

Deviations (recorded, not silently dropped): rotation /
dark-mode / density change restarts to the home page losing
state (item (b)); Counter loses the in-app log-viewer footer
toggle; Gallery is a new composition, not a line-for-line port
of the old Gallery; reference tabs take intrinsic width and
overflow narrow viewports (reference behaviour); dialog/menu
coexistence stays asymmetric per W3-5 (menu refuses while a
dialog is open; dialog opens over a menu).

Compiler items -- ALL FIXED in v0.23.81-dev (none worked around here):
(b) `configChanges` 0x490 -> 0x1F90 (H-1); (c) link-so funcaddr
(port `funcAddrSeen` -> `spec.funcAddrRefs` into
`linkSharedObjects`, H-2); C-1 link-obj / link-pie run-time global
initializers in non-`_start` objects (H-3: entry stub synthesis;
42/42 links succeed, 3 tests promoted to the suite [24/27] on
2026-11-15, v2.5.2, 39 link-gated in [26/27] pending
re-baseline); C-2 per-file `@embed` symbol namespacing
(H-4: `__aster_embed_0` collision fixed; `png_test` promoted to
[24/27]).

What remains: (1) user device verification of the 3 APKs
(checklist in W4-6); (2) DONE -- compiler items (b)/(c)/C-1/C-2
all fixed, see above; (3) DONE -- the 16 harnesses were
re-baselined 2026-11-14 and `tests/baseline/font_runtime.pixels`
was frozen 2026-11-15 (v2.5.2, once C-1 landed);
(4) register `tests/ui-checks.sh` in `tests/ci.sh`
(deferred by the main chat while the full gate runs);
(5) `run_qemu.sh` is still stale (no `font_runtime.o`, old
recipes) -- the suite [22/27]-[27/27] supersedes it, but the
file itself was not rewritten; (6) PROPOSAL ONLY -- delete the
old `~/workspace/projects/Aster/asterui/` tree once the new
base passes device verification AND the old 21/21 cases are
ported or formally retired. NOT done in W4: the tree is still
needed by the old suite cases, and deleting it now would break
them.

## Font fix (2026-11-14, device-verified failure of the M4.1 engine)

Device evidence (user's Android 16 phone, 12 screenshots of Gallery
v2.0 + Counter v2.0, 2026-11-14 12:11-12:13): ALL text rendered as
the wide-tracked monospace bitmap fallback (ASCII 8x8 x3 + hand-drawn
56-glyph CJK atlas x3); the system TrueType engine never engaged on
device, while every qemu test passed. The in-app log had no font
line at all. The user calls this an old problem -- the M4.1 engine
was never device-confirmed before adoption.

Root cause (two parts, both in the font path):
1. `ui_sysfont_init()` (`asterui/render/truetype.ast`) hardcoded
   three `/system/fonts` filenames (`NotoSansCJK-Regular.ttc`,
   `NotoSansSC-Regular.otf`, `DroidSansFallback.ttf`) that were
   never verified against the device. Android 15+ ships the CJK
   system font as a variable TTC
   (`NotoSansCJK-wght-400-900.ttf.ttc`); a Chinese OEM device may
   also use `/product/fonts` or `/system_ext/fonts`. No file at
   any of the three names => `g_tt_ok = 0` => the adapter fell back
   forever. File I/O itself was fine (raw `openat` syscall, same
   on Android and qemu); the names were wrong.
2. The new base never logged any font outcome: `aui_android_attach`
   never called `ui_sysfont_init()`, and the `sysfont ok ...` line
   lived only in the OLD tree's backend (`asterui/backend/
   android.ast:1023`). The load was lazy (first text draw) and
   silent, so the device gave no diagnostic at all.

Fix (no font files in any APK, no licence, no dex, pure Aster,
no compiler change):
- `asterui/render/truetype.ast`: `ui_sysfont_init()` now scans
  `/system/fonts`, `/product/fonts`, `/system_ext/fonts`, trying
  7 names in each (`NotoSansCJK-Regular.ttc`,
  `NotoSansCJK-wght-400-900.ttf.ttc`, `NotoSansCJK-VF.ttf`,
  `NotoSansSC-Regular.otf`, `NotoSansSC-VF.otf`,
  `DroidSansFallback.ttf`, `NotoSansCJK-Bold.ttc`) via
  `ui_sysfont_scan_dir` / `ui_sysfont_try_path`. Every attempt is
  recorded in a 24-row probe table
  (`ui_sysfont_probe_n/path/size/err`); when nothing loads, the
  error is the last parse error from a file that existed, else 1.
  CFF2-only fonts are now recognised distinctly (new err 6,
  `ui_sysfont_is_cff2()`; old err 5 = no outline table at all),
  and `ui_sysfont_is_glyf()` / `ui_sysfont_cmap_fmt()` getters
  were added for the probe log.
- `stdlib/asterui/aui_impl.ast`: new `aui_sysfont_probe()`,
  called from `aui_android_attach` right after app `init()`
  (eager load in onCreate, so the ~19.5 MB TTC slurp never lands
  mid-frame). Logs one summary line, one line per candidate path
  tried, one rasterize probe (A + U+6F22), and a fallback line
  when the system font is not active. The probe lives here (not
  in `font_runtime.ast`) because the adapter test links
  `font_runtime.o` WITHOUT `aui_impl.o` (C-1).
- `stdlib/asterui/tests/font_adapter_test.ast`: new section F
  proves renamed-file discovery (suite symlinks the variable-TTC
  name to the VM TTC in `/tmp/aui-fontscan-test/`), asserts the
  probe table (miss err 1, then hit err 0) and U+6F22 rendering
  from the system font; prints `SCAN 1 2 1 0`, frozen in
  `tests/baseline/font_adapter.pixels`.
- `tests/ui-checks.sh`: [23/27] creates/removes the scan fixture;
  [27/27] bumps Counter 7->8 / 2.0->2.1, Gallery 6->7 / 2.0->2.1.
  `stdlib/asterui/examples/ui_hello.ast`: label "v1.24" -> "v2.1".
- The blue label-less rectangle in the Counter's first card was
  the "重置" (Reset) button: both glyphs are missing from the
  56-glyph fallback atlas, so fallback mode drew it blank. It is
  a symptom of the same root cause, not a separate bug; it renders
  once the system font engages. Atlas expansion is out of scope.

Device checklist for v2.1: smooth proportional text everywhere
(no wide-tracked monospace), CJK at system quality including
漢 (U+6F22, outside the old 56-glyph set), the "重置" button
label visible, and in the in-app log viewer:
`sysfont ok 1 err 0 face 2 cff ... glyf ... cff2 0 cmap 12 glyphs
... upm 1000` plus `sysfont try ... err 0 <path of the font that
loaded>` and `sysfont raster A <slot>=0 han <slot>=0 decodefail 0`.
If the font still does not engage, the `sysfont try` rows say
exactly which names were tried and why each failed (err 1 = no
file, 3 = not a font, 4 = no cmap, 5 = no outline table,
6 = CFF2-only variable font).

## Font fix round 2 — v2.2 (2026-11-14, device-verified corruption)

Device evidence (user's Android 16 phone, v2.1 APKs, 2 screenshots
+ in-app log, 2026-11-14 12:58-12:59): the system font DID engage
(proportional advances, CJK clean), but many Latin glyphs rendered
as black blobs / diagonal scribbles: e, o, a, g, p, c and digits
0/6/5; straight Latin (A, s, t, r, …) and all CJK except 已 (U+5DF2)
were clean. The log showed the app rendering everything in Bold:
`sysfont try 0 size 32355424 err 6 /system/fonts/NotoSansCJK-Regular.ttc`
(the Regular TTC exists but is CFF2-only, so it was skipped) and
`sysfont try 6 size 20050760 err 0 /system/fonts/NotoSansCJK-Bold.ttc`.
The raster probe said `decodefail 0` because it only probed 'A' and
漢, neither of which uses the broken operators — that is why v2.1
shipped green. (Correction to the round-1 note: the file was NOT
renamed on Android 15+; it is still called `NotoSansCJK-Regular.ttc`,
its CONTENTS are CFF2. The discovery scan still saved the load, via
Bold.)

Root cause (NOT flex, as first suspected): the CFF Type 2
interpreter in `asterui/render/truetype.ast` (`ui_tt_cff_run`)
implemented ops 26/27/30/31 (vv/hh/vh/hvcurveto) as SINGLE-curve
operators. The spec (Adobe TN 5177; fontTools `T2OutlineExtractor`)
defines them as MULTI-curve: 4 args per extra curve, with an
optional leading arg (vv/hh) or trailing arg (vh/hv). Any glyph
using one of these ops with more than 5 args lost curves and its
outline collapsed into a blob or scribble. Confirmed headlessly:
the same glyphs reproduce as blobs under qemu from the VM TTCs, and
the raw charstrings show the multi-arg uses (e.g. '0' uses
`hvcurveto` with 16 args twice; 'o' 8 and 16 args; 已 uses
`hhcurveto` with 9 args). Flex was ruled out by a correct Type 2
tokenizer + full subr BFS: NO flex op (12 34/35/36/37) occurs in the
transitive closure of any corrupted or clean target glyph in either
VM TTC. Three adjacent flex bugs found by the same audit and fixed
in the same round:
- the flex1 (12 36) and hflex1 (12 37) branch bodies were SWAPPED
  (each implemented the other's operator);
- flex1 missed the dominant-axis negation (the second curve's free
  component must be -(sum of the other axis), not 0);
- hflex (12 34) ended its second curve at `fy0 + fdy2` instead of
  `fy0` (dy6 = 0).
Flex1 is used by exactly one glyph per font (Regular U+8C99 via
fd-12 subr 21599; Bold U+5D67 via subr 14539); hflex by two Regular
glyphs (U+585B via subr 14029, U+6BAA via subr 23650). No hflex1
(12 37) use exists in either Noto TTC, so that label swap is fixed
by inspection only (verified against fontTools).

Second bug, same round: switching fonts in one process left the
lazy CFF parse flag (`g_tt_cff_parsed`) set, so the second font's
glyphs decoded against the first font's CFF offsets and every
glyph failed (seen in the headless repro: Bold after Regular
rendered from fallback with rising `decodefail`). Fixed by
resetting the flag in `ui_sysfont_load_face` (and `unload`).

Probe changes (same round):
- `ui_sysfont_scan_dir` no longer stops at the first load: it
  enumerates all 7 names in all 3 dirs (21 rows max, table cap 24),
  and `ui_sysfont_init` then loads the BEST candidate — the first
  loadable Regular-weight face, else the first loadable Bold
  (Bold detected by "Bo" in the path). The device log now shows the
  phone's full font inventory. On the user's phone this still
  selects Bold (Regular is CFF2-only); see the CFF2 assessment.
- `aui_sysfont_probe()` raster probe now also probes 'e' (101) and
  'o' (111): `sysfont raster A <ra> han <rh> e <re> o <ro>
  decodefail <df>`.

CFF2: assessed, NOT implemented this round. Full CFF2 (arbitrary
weight instances, VariationStore + blend scalars) is ~400-600 lines
and high risk with no headless CFF2 test font on the VM. The
default-instance subset (render at the font's default instance:
`blend` drops deltas and keeps defaults, `vsindex` is a no-op —
exactly what fontTools does with no blender) is ~150-250 lines and
would unlock Regular weight 400 on this phone; it belongs in a
follow-up round. See `~/workspace/fontfix2/cff2-assessment.md`.

Suite (`stdlib/asterui/tests/font_adapter_test.ast`, section G;
baseline `tests/baseline/font_adapter.pixels`): frozen bitmap hashes
for the corrected bowl glyphs (e, o, a, g, c, p, 0, 5, 6, U+5DF2),
flex1 (U+8C99 Regular, U+5D67 Bold) and hflex (U+585B); a font-switch
check (Regular -> Bold -> Regular: Bold 'A' hash differs, Regular
'A' hash returns to the section C value, zero decode failures).
Section F updated for the enumeration (7 probe rows, errs
1 0 1 1 1 1 1). The pre-existing hashes (zhong/wen/zeng/han/A) are
unchanged by the fix — the 4/5-arg single-curve behaviour is
byte-identical — which the suite now pins. Verification of the fix
against FreeType (no hinting, 48 px) is in
`~/workspace/fontfix2/` (`ftref.py`): Aster ink and ink bounding
boxes match FreeType within rasterizer tolerance for every target
glyph, and the ASCII art is the correct letter shape.

Delivery: Counter v2.2/code 9, Gallery v2.2/code 8 (IME probe NOT
rebuilt — it links no font code). Both target-sdk 35, 16K page
aligned, verify-apk OK, no font files, no dex. Uninstall the v2.1
builds first (fresh debug key each build).

Device checklist for v2.2: e/o/a/g/p/c and 0/5/6 render as clean
letters (not blobs/scribbles), 已 clean, "重置" button labelled,
and in the in-app log viewer: `sysfont raster A 0 han 1 e 2 o 3
decodefail 0` (slots may differ if the cache order changes, but
none may be -1 and decodefail must be 0) plus one `sysfont try`
line per candidate across all three dirs (7 per dir, 21 max) with
the Regular TTC showing err 6 and the Bold TTC err 0. Text is
still Bold weight until the CFF2 default-instance subset lands.

Verification outcome (2026-11-14, after the fix): headless repro
(`stdlib/asterui/tests/flex_repro.ast`, qemu, VM TTCs) confirms
the fix — Regular ink vs FreeType (48 px, no hinting): A 417/420,
e 333/349, o 357/358, a 343/371, g 421/542 (descender clips at the
48 px cell bottom, the known M4.1 limitation), c 258/269, p
399/445 (descender clip), 0 419/425, 5 364/392, 6 426/425, S
414/412, B 548/568, 已 669/718, 中 670/685; Bold renders from
the TrueType engine (src=1, decodefail 0) with A 588/588, e
473/485, o 496/498. Pre-fix 'S'/'B' were also over-filled (586/647)
and are now correct — the corruption was wider than the visible
blobs. The eight multi-curve CJK glyphs in the zh strings
(导/已/无/此/航/色/选/？) all verify vs FreeType within 7%
(`~/workspace/fontfix2/cjk8.out`, `cjk_ops.py`). The old-tree
`asterui/tests/baseline/truetype.pixels` needed one deliberate
regeneration: `tt_gallery_zh` -4316817052686555400 ->
-6041113173446477272 (the frame contains the corrected Latin
bowls + the eight CJK glyphs; the other eight hashes are
unchanged; reason recorded in that file). Suite: the real
`tests/ui-checks.sh` passes 22/27 and stops at [23/27] — the
`font_runtime_test` link, which the suite was updated (13:23 CST,
during this session, by the main chat) to require the H-3/C-1
compiler fix; H-3 is in progress in the main chat and is in
neither `../Aster-env/aster` (Nov 13) nor the repo `./aster`
(Nov 14 03:58) — both still reject the link with the recorded
C-1 error, reproduced standalone. This is NOT caused by the
font fix. With only that link skipped (temporary copy, deleted
after the run), the suite is fully green: 28 PASS lines, 21/21
old + 6/6 new-base, SUITE_EXIT=0, 1m17s, including the [26/27]
BLOCKED ratchet (42 C-1 + 1 C-2 still fail with the recorded
errors). The v2.2 APKs below were rebuilt fresh from the current
sources with the exact [27/27] recipe and re-verified (same .so
sizes as the first build; APK SHAs differ only because the debug
key is fresh each build).

## Font fix round 2 — v2.2 DEVICE CONFIRMED, and round 3 — v2.3 (2026-11-14)

Device evidence (user's Android 16 phone, v2.2 APKs, 4 screenshots
+ in-app log, 2026-11-14 13:54-13:56): the v2.2 multi-curve fix is
DEVICE-CONFIRMED. The digit 0 is a clean "0" (was a diagonal
scribble), "65%" is clean, e/o/a/g/p/c render as clean letterforms
everywhere ("AsterUI Gallery", "Text field + select", "Tap to
type...", "Live value", "Clear", "Focus", "Language", "English",
"Notify", "Promotions", "Volume", "Toggle dark", "Show log"), CJK
clean, "重置" has text, SafeArea L 0 T 24 R 0 B 24. The log shows
all 21 candidates enumerated (7 names x 3 dirs): only try 0
(/system/fonts/NotoSansCJK-Regular.ttc, size 32355424, err 6 =
CFF2) and try 6 (/system/fonts/NotoSansCJK-Bold.ttc, size
20050760, err 0) exist; every other candidate is size -1 err 1,
including all of /product/fonts and /system_ext/fonts. Raster
probe: `sysfont raster A 0 han 1 e 2 o 3 decodefail 0`.

New bug, user's own words: "英文的下基线会遮挡文字，比如图中的g
下方的勾就会被遮挡" — descenders are clipped: the hook below 'g'
is cut flat at the text line's bottom edge (visible in "Language",
"Toggle dark", "Show log"), 'p' likewise ("Promotions",
"Tap to type..."), 'y' likewise (the "System" tab). This is the
known M4.1 limitation recorded in the round-2 verification outcome
(g 421/542, p 399/445: the tails were missing, not mangled).

Root cause: the glyph cell was a fixed 48 rows mapping the typo em
box (asc 880 .. desc -120), but Latin descenders reach -250
(g -250, p -229, y -234, j -242, q -229; fontTools curve bboxes,
confirmed equal to the engine's outline minima). Any ink below
-120 fell past the last bitmap row and was clipped. CJK was never
affected: its ink stays above -120 (中 -79, 文 -78, 已 -52).

Fix (`asterui/render/truetype.ast`): the bitmap height is now per
glyph — it grows past the requested cell height to hold the whole
outline (`ui_tt_outline_rows`: exact-ceiling
ceil((asc - miny) * ch / span); the outline minimum IS the true
minimum because the decoder flattens curves onto the outline, so
no slack row is needed — verified per glyph against fontTools).
The growth changes only the CLIP height, never the scale:
`ui_tt_scale` still takes the REQUESTED cell height (the em box
maps onto the requested cell, as since M4.1), `ui_tt_scan` takes
the grown height, so the baseline row inside the bitmap never
moves. First attempt (scale from the em instead of the cell) was
caught by the suite before shipping: it changed the tt_dejavu_a/g
hashes, because the old scene rasterizes ASCII at non-square 8x16
cells and relies on the cell-mapped scale to stretch the glyph
into the cell. The split (scale from requested, clip from grown)
restores those hashes exactly. Resulting heights at 48px: g 55,
p 54, y 54, j 54, q 54 rows (Bold g 54); 'A' and all CJK stay 48
rows. Clamped to the 64-row cache slot. The draw path needed no
change: `aui_rt_draw_text_run` blits each bitmap from the line top
at natural size, so taller bitmaps extend downward from the same
baseline; `text_glyph_h()` stays 48, so centering and line spacing
are unchanged, and a descender reaches at most the line bottom
(line height 60, glyph top offset 6, tallest bitmap 55 rows)
without touching the next line's ink (which starts 13 rows into
its cell).

Headless evidence (qemu, VM TTCs, FreeType 48px no-hinting):
pre-fix Regular ink g 421/p 399/y 296/j 198/q 428 (all with zero
ink below row 48); post-fix g 516/p 424/y 347/j 239/q 458, vs
FreeType 542/445/357/259/468 (within 8%; j is thinnest and its
dot-tip row is a pre-existing sampler difference, identical
before/after the fix). Bold (device face): g 697/715, p 623/627,
y 485/488, j 376/392, q 589/629; A 588/588, 中 927/927. Controls
unchanged: A 417/420, 中 670/685, e 333/349.

Suite (`stdlib/asterui/tests/font_adapter_test.ast`, new section
H; baselines `tests/baseline/font_adapter.pixels` and
`asterui/tests/baseline/truetype.pixels`): section H freezes the
descender bitmaps (y/j/q/g_bold new; g/p values move for the
documented reason — taller bitmaps; every other hash unchanged,
including all CJK, re-asserted in-test by comparing 'A' and
U+4E2D against their section C hashes). `truetype.pixels` needed
one deliberate regeneration: `tt_gallery_zh`
-6041113173446477272 -> 2285394663046102420 (the frame holds Latin
descenders whose tails now render; the other eight hashes are
unchanged, including tt_dejavu_g at 16px, which also confirms the
scale formula is untouched; no CJK glyph in U+4E00..U+4E7F
descends below -100, so no CJK bitmap grows at 16px). Headless
repro kept: `stdlib/asterui/tests/desc_repro.ast` (renders
g/p/y/j/q/A/中/e with below-baseline and below-cell ink counts).
Evidence dir: `~/workspace/fontfix3/` (repro outputs, adapter
and truetype runs, both suite logs, rebuild script).

Delivery: Counter v2.3/code 10 (836,182 B, SHA-256
ee76d197a2a532c613a1a8fabb67f7159ba7c506a1dcb200f4490bac6ac72d88),
Gallery v2.3/code 9 (872,662 B, SHA-256
8983085f0e97bb30c8e4e36bc4385b7603c56d6c61059066fdbebc80311e6d9a).
IME probe NOT rebuilt — it links no font code (still v2.0/code
3). Both target-sdk 35, 16K page aligned, verify-apk OK, no font
files, no dex. Uninstall the v2.2 builds first (fresh debug key
each build).

Device checklist for v2.3: the 'g' hook is whole in "Language",
"Toggle dark", "Show log"; the 'p' tail is whole in "Promotions"
and "Tap to type..."; the 'y' tail is whole in the "System" tab;
everything v2.2 confirmed stays clean (0, 65%, e/o/a/g/p/c, 重置).
Log: `sysfont raster A <ra> han <rh> e <re> o <ro> decodefail 0`
as in v2.2. Text is still Bold weight until the CFF2
default-instance subset lands.

## Font fix round 4 — v2.4 CFF2 default instance (2026-11-14)

Device evidence (user, 2026-11-14 14:34-14:35, 2 screenshots):
the v2.3 descender fix is DEVICE-CONFIRMED — 'g' hook whole in
"Language"/"Toggle dark"/"Show log", 'p' tail whole in
"Promotions"/"Tap to type...", 'y' tail whole in the "System" tab.
User: "可以了，可以进入下一轮了". The next round is this one:
the phone's Regular TTC is CFF2-only (err 6), so everything still
renders Bold. This round unlocks Regular 400.

Assessment correction: the round-2 CFF2 assessment
(`~/workspace/fontfix2/cff2-assessment.md`) is materially wrong
on one point — it claims INDEX parsing is the same as CFF. It
is not: a CFF2 INDEX count is Card32 (5-byte header: count +
offSize), a CFF count is Card16 (3-byte header). Verified in
fontTools `cffLib.Index.__init__` (`if isCFF2: readCard32 else:
readCard16`). Everything else in the assessment checked out
(blend stack layout, vsindex op 15, Private op 22, Top DICT
VarStore op 24, CFF2 file order with GlobalSubrs right after
the Top DICT, no charstring widths in CFF2). The final diff is
~310 lines in `truetype.ast` (3723 -> 4033), slightly over the
150-250 estimate, because the INDEX branching touches three
functions and the parse had to be restructured for the two
table layouts; the scope was right, the line count optimistic.

Fix (`asterui/render/truetype.ast`): `ui_tt_cff_parse` now
picks the CFF table when present else the CFF2 table, reads
the major byte, and branches — CFF2: header [major, minor,
headerSize, topDictLength u16], Top DICT at base+headerSize,
GlobalSubrs INDEX immediately after it; CFF: the old
Name/Top/String/GlobalSubrs walk, unchanged. Both converge on
the shared CharStrings/FDSelect/FDArray tail (offsets relative
to the table base in both). `ui_tt_cff_index` /
`index_end` / `index_item` branch on `g_tt_cff_is2` (u32 vs
u16 counts, 5- vs 3-byte headers). The interpreter gains ops
15 (vsindex: pop the VarData index, tracked per glyph from the
Private DICT default, op 22) and 16 (blend: stack is
[n defaults][n*m deltas][n]; the default instance keeps the n
defaults and drops the n*m deltas, m = region count of the
current VarData from the minimal VarStore parse
`ui_tt_cff_num_regions` — the Top DICT VarStore offset points
at the u16 length prefix, so the stored offset is raw + 2).
`ui_sysfont_load_face` no longer rejects CFF2 with err 6: a
CFF2-only font now sets `has_cff` and parses EAGERLY, so a bad
CFF2 table still reports err 6 (now meaning "CFF2 present but
unparsable") instead of failing at first raster. fvar is read
(`ui_tt_parse_fvar`, `ui_sysfont_fvar_wght`): the wght default
is logged, never hardcoded. Selection needed no change:
Regular (no "Bo" in the path) already wins over Bold once it
loads err 0. Probe (`aui_impl.ast:15703`): the `sysfont ok`
line gains `wght <n>`; `ui_sysfont_fvar_wght` is declared
extern there (the first suite run caught the missing extern:
`call to undeclared function` at [22/27]).

Headless verification (the VM has NO CFF2 font, so fixtures
were built, not found; builder `~/workspace/fontfix4/
build_fixtures.py`, FreeType log
`~/workspace/fontfix4/freetype-validation.log`):
`tests/fixtures/cff2_noto_sc.ttf` (3,416 B) — the VM Regular
TTC subset to A/e/o/g/0/5/6 + U+4E2D/U+6587/U+5DF2/U+6F22,
converted CFF -> CFF2; `cff2_blend.ttf` (800 B) — a hand-built
5-glyph CFF2 font, 1 VarData with 1 region, fvar wght 400..900
default 400, with a blended square (B), a vsindex+blend
triangle (C), and a blend n=2 square (D); `cff2_broken.ttf`
(686 B) — the blend fixture truncated inside the CharStrings
INDEX offset array, so the CFF2 parse fails with err 6.
FreeType 48px no-hinting: the CFF2 subset matches the ORIGINAL
CFF ink 11/11 exactly (A 420, e 349, o 358, g 542, 0 425, 5 392,
6 425, 中 685, 文 666, 已 718, 漢 1020); blend A 25, B 25
(B == A exactly — blend at the default instance), C 15, D 9.
The Aster engine renders the same fixtures with ink A/B 30/30
(B == A exactly), C 20, D 9; the A/B/C deltas vs FreeType are
the fixed-cell positioning edge effect (the 4.8px square sits
at a fractional row offset in the 48-row cell, so it touches
6 rows instead of 5 — FreeType's tight box gives 5x5), D is
exact, and the CFF2 subset hashes EQUAL the CFF Regular hashes
in-test, which were FreeType-validated in rounds 2-3. Two
fontTools facts proven while building the fixtures and worth
recording: `convertCFFToCFF2` does NOT strip charstring width
values (its decompiler keeps the width in the program; the
builder strips widths explicitly via a width-detector subclass
— 7 of 18 charstrings carried one), and a fresh `TTFont()`
defaults to a TrueType sfntVersion, so a CFF/CFF2 font MUST
set 'OTTO' or FreeType fails with err 144 (loca missing).

Suite (`stdlib/asterui/tests/font_adapter_test.ast`, new section
I, exit codes 45-50; baseline
`tests/baseline/font_adapter.pixels`): section I loads the
CFF2 subset (is_cff2 == 1, fvar wght -1 — no fvar) and asserts
all 11 glyphs render from TT with hashes EQUAL to the CFF
Regular hashes of sections C/G ('g' keeps bh 55); loads the
blend fixture (fvar wght 400) and asserts B hashes EQUAL to A
plus C/D render with ink; loads the broken fixture (load 0,
err 6), reloads Bold (still works), and switches back to the
CFF2 subset (section C 'A' hash restored); decode failures 0.
Baseline: 17 new lines (2 RTADV + 11 _cff2 + 4 _blend hashes)
and RTFB 1 1 1 -> 2 6 1 for the documented reason (the broken
fixture is a second fallback event, reason 6). NO pre-existing
hash moves. Real suite: 22/27, stops at [23/27] on the recorded
H-3/C-1 font_runtime_test link failure (expected — H-3 is not
in a compiler binary yet). Temp-copy full run (only the
[23/27] font_runtime_test link and the [24/27] png_test link
skipped, copy deleted after): fully green, 21/21 old + 6/6
new-base, SUITE_EXIT=0, 28 PASS lines; the [26/27] ratchet
still passes (42 C-1 links fail with the recorded error).
Logs: `~/workspace/fontfix4/ui-checks-real-v24.log`,
`ui-checks-temp-v24.log`. [27/27] now builds Counter 11:2.4
and Gallery 10:2.4; `ui_hello.ast` label is "v2.4 中文界面".

Delivery: Counter v2.4/code 11 (836,686 B, SHA-256
829648c0a0dc242d611db9aef1bddbd5f327330d3d2cf30072b1f2b386732c8a),
Gallery v2.4/code 10 (873,166 B, SHA-256
de0e5c08fd70f3493c93cfa570b52749cf50c476d4242941b9b2a1b4bb06fb58).
IME probe NOT rebuilt — it links no font code (still v2.0/code
3). Both target-sdk 35, 16K page aligned, verify-apk OK, no font
files, no dex. Uninstall the v2.3 builds first (fresh debug key
each build). NOTE: `check_so.py` still FAILs both .so files
(Counter 30, Gallery 47 self-relocations) — the prebuilt
compiler binary does not contain the H-2 link-so fix yet, so
this is the same pre-H-2 state as v2.0-v2.3, not a regression
from this round.

Device checklist for v2.4: text is visibly Regular weight
(lighter than Bold) everywhere; the log shows
`sysfont ok 1 err 0 face 2 cff 1 glyf 0 cff2 1 cmap 12 glyphs
65535 upm 1000 wght 400` and `sysfont try 0 size 32355424 err 0
/system/fonts/NotoSansCJK-Regular.ttc` (err 0, NOT err 6);
`sysfont raster A <ra> han <rh> e <re> o <ro> decodefail 0`.
If Regular fails to load on the device, Bold fallback still
works — the loader falls back to Bold on any CFF2 parse
failure (proven headlessly by the broken-fixture test), and
the text stays Bold rather than blank.

## Custom fonts — v2.5 (2026-11-14)

Direction (user-confirmed 2026-11-14 16:05 CST): an AsterUI app
loads an external font file from a device path at runtime, with
the user's HYZhengYuan family as the reference. The wrong turn,
explicitly ruled out: NEVER bundle HYZhengYuan (or anything from
`~/workspace/font-reference/`) into any APK — commercial
Hanyi/ZTE fonts, reference/comparison only. The reference files
(`~/workspace/font-reference/hyzhengyuan/README.md`): 4 weights,
TrueType glyf outlines, upm 1000, 29,000 glyphs each, static (no
fvar), cmap 4+12, ZERO composite glyphs; Light ZTEZhengYuan-45S
(14,867,724 B), Regular -55S (15,147,972 B), Medium -65S
(15,237,792 B), Bold -75S (15,214,716 B). OS/2 usWeightClass is
400 for ALL FOUR weights — useless; weight must come from the
family-name suffix (45S->300, 55S->400, 65S->500, 75S->700).
The 6 REDMAGIC effect images are the visual ground truth
(specimen: "与你不谋而合", "让沟通与信任无处不在 / To enable
connectivity and trust everywhere", "网络联接世界 创新引领未来
/ To connect the world with continuous for a better future").

Model: ONE active face at a time + a single-slot snapshot (not
a registry). The engine holds exactly one face (`g_tt_*`
globals); a registry would only duplicate the 15-32 MB font
buffer per entry. Switching is a re-parse of one file (tens of
ms headless, logged via `aui_rt_custom_load_ms`). The buffer is
a persistent reusable engine buffer (`g_tt_buf_mem` /
`g_tt_buf_cap`, grown only when a larger file arrives) because
`free` is a documented no-op in aster_std and `slurp_bytes`
would abandon one 15-32 MB arena chunk per switch.

API (new in v2.5):
- `aui_rt_set_custom_font(path) -> i32` (font_runtime.ast):
  snapshot the current face -> load the path -> on success
  record ms/weight/path, return 1; on failure record the error
  code, restore the snapshot face, return 0; only with no
  snapshot does it fall back to bitmap mode. Never a silent
  fallback, never a blank screen.
- `aui_rt_restore_system_font() -> i32`: reload the snapshot
  face (the system font path saved at init success); no
  snapshot -> unload + fallback event reason 1, return 0.
  NOTE: it must NOT call `ui_sysfont_init()` (early-returns
  once `g_tt_tried==1`) and must NOT go through
  `ui_sysfont_try_path` (that would corrupt `g_tt_best_row`).
- Getters: `aui_rt_custom_active/err/load_ms/path/system_path/
  font_weight`. Weight = fvar wght if present, else
  family-name suffix, else OS/2 usWeightClass, else -1 — never
  from the filename.
- Engine: `ui_tt_read_font(path)` (truetype.ast) replaces
  `slurp_bytes` in `ui_sysfont_load_face`; `ui_sysfont_name_
  weight()` scans the family name for the "-NN S" suffix.
- `aui_ext_dir() -> ptr` (aui_impl.ast): the app's external
  files dir, saved from ANativeActivity offset 40 at attach
  time (0 when headless/not attached). The Gallery prefills the
  path field from it once.

Default folder: `<ext>/fonts`, where ext is the app's external
files dir. Justification: on Android 16 scoped storage it
needs NO permission and is reachable over USB from a computer;
arbitrary /sdcard paths need storage permissions this
NativeActivity app does not have. Headless CANNOT prove Android
storage behaviour (no adb, no device-side probe) — stated
plainly; the path is user-editable in the app, so a wrong
default is recoverable. The full device path is accepted (any
path the user types is tried as-is).

Demo home: NEW "Fonts" tab (index 5, key 16) in the Gallery,
not the System tab — System already holds Theme/SafeArea/Log,
and Fonts needs a full screen: path TextField (key 610, Load
key 611), "Use system font" (key 640), weight Select (key 630,
options 631-634 Light/Regular/Medium/Bold), status block
(keys 650-652 + info rows 660/670/674), specimen card (keys
680-686, the exact effect-image lines), and in-app placement
instructions (keys 602-606). Weight pick loads immediately;
the file's weight is read back and shown, never assumed. The
Gallery logs `customfont ok ms=<ms> weight=<w>` /
`customfont fail err=<e> weight=<w>` / `customfont restore
ok/fail ...` via `aui_log2`.

Two real pre-existing engine bugs found and fixed by the
corrupt-file tests (both predate v2.5; the rasterizer itself
is untouched):
1. Truncated-font segfault: a 1024-byte truncation of
   HYZhengYuan-Regular segfaulted in `ui_tt_parse_metrics` —
   it checked table existence/length but never that the offset
   is inside the file; HYZhengYuan lays head/maxp/hhea at
   ~14.5 MB, so `ui_tt_u16(g_tt_off_head + 18)` read unmapped
   memory. Fix: `ui_tt_parse_sfnt` validates every table's
   `[offset, offset+length)` against `g_tt_flen` and marks
   out-of-range tables absent, so required-table checks fail
   cleanly (err 3/4/5). Side effect: the round-4 broken CFF2
   fixture (`cff2_broken.ttf`, CFF2 extent 612..763 overruns
   its 686-byte file) now fails with err 5 (no usable outline
   table) instead of err 6; err 6 is now reserved for a CFF2
   table that IS fully present but fails to parse. Section I +
   RTFB updated ("2 6 1" -> "2 5 1"). Device diagnostics for
   complete files are unchanged.
2. Read-loop blind doubling: `ui_tt_read_font` doubled the
   buffer whenever a read exactly filled the space — after
   earlier doublings the capacity was already large (28 MB),
   so doubling tried to allocate 112 MB > `kArenaMaxChunk`
   (64 MB) -> `alloc` returned 0 -> load failed with err 1
   even though the file was fully read. Reproduced in a 16-load
   sweep (trunc14600000 and the full file failed err 1 after
   earlier 14-14.5 MB loads). Fix: probe one byte into the NUL
   slot when the buffer is exactly full (EOF -> done, no
   growth; a byte -> the file really grew -> double); initial
   growth uses plain `alloc` (no copy — the buffer is empty at
   load start). Re-sweep clean.

Headless evidence (qemu + VM, FreeType 48px no-hinting via
`~/workspace/fontcustom/ftcheck.py`, `compare.out`): all 4
weights load through the new API; Regular probe set ink
(engine vs FreeType) — A 415/438, e 336/344, g 464/466,
p 412/421, y 323/324, j 216/246, q 389/391, 0 400/406,
5 380/384, 6 348/359, 中 613/628, 文 691/698, 已 634/725,
漢 1035/1035 (exact). 'A' across weights — Light 383,
Regular 438, Medium 483, Bold 537 (all differ; engine 'A'
hashes frozen: Light 8002124213439754773, Regular
5282179385097149974, Medium -434237012983688915, Bold
2173988711116497062). Engine ink is systematically BELOW
FreeType (worst: Medium 'j' -20.2%, Regular 't' -14.3%,
Regular 已 -12.6%); ASCII-art comparison of 已 shows the SAME
shape, shifted ~2px right / ~4px down, with the faintest
AA-only rows dropped and thin strokes rendered solid — a
pre-existing scanline-sampler fidelity limit (round 3
documented the same for 'j'), NOT an outline error and NOT a
v2.5 regression. The device visual comparison against the
effect images is the real arbiter. Truncation sweep (16 loads
in one process): trunc8/1024/100000/1M/8M/14M/14.5M/14.6M/
14.7M all r=0 err=3; trunc14800000 r=1; full Regular/Bold/
Light/Medium r=1; 32 MB VM TTC r=1 after the HYZhengYuan
loads; exit 0, no crashes.

Tests (`stdlib/asterui/tests/font_adapter_test.ast`, new
section J, exit codes 51-56; baseline
`tests/baseline/font_adapter.pixels`, 195 lines): 51 missing
file (err 1, system face restored, 'A' hash == section C,
fallback events stay 2); 52 trunc8 + trunc1024 (err 3, system
face restored); 53 four weights load, weights 300/400/500/700,
'A' hashes all differ; 54 Regular probe set (14 glyphs) + 46
distinct specimen glyphs (`hyzy_spec` hashes); 55 switch
determinism custom->system->custom (hashes equal,
`A_hyzy_again` == Regular 'A'); 56 decode failures == 0.
Baseline: 83 new lines, ONLY old line that moves is RTFB
2 6 1 -> 2 5 1 (the err-5 change above); NO other old hash
moves. The 15 MB HYZhengYuan files are NOT copied to the
fixtures dir (licence + size); the suite symlinks them from
`~/workspace/font-reference/hyzhengyuan/fonts/` into a temp
dir (precedent: section F's symlink fixture) and fails fast
if a reference font is missing. `hyzy_repro.ast` (new test,
kept per the flex_repro/desc_repro precedent) prints engine
ink for the probe set in all 4 weights + the 46 specimen
glyphs in Regular. Compile gate is now 125 files.

Smoke test change: `gallery_smoke_test.ast` renders 960x1024
instead of 720x1280. The 6-tab bar is 912px wide at the
headless fallback font's 24px/char advance (Fonts tab starts
x=768), so 720px clipped it entirely off-screen and section
H's tab tap hit nothing (exit 22). Height is 1024, not 1280:
one array is capped at 1048576 elements (960x1280 =
1228800), and 1024 still leaves the Overlay tab's buttons
above the fold. New section H (exit codes 21-25): tap Fonts
tab -> tab 5; specimen label 681 + path field 610 rects
exist; set path "/tmp/aui-hyzy-test" + tap Load -> active==1
and weight==400; specimen still renders; tap "Use system
font" -> active==0. Section A loop is now `t < 6`.

Suite: real 22/27, stops at [23/27] on the recorded H-3/C-1
font_runtime_test link failure (expected). Temp-copy full run
(only the [23/27] font_runtime_test link+run and the [24/27]
png_test link skipped, both annotated, copy deleted after):
fully green, 21/21 old + 6/6 new-base, SUITE_EXIT=0, 28 PASS
lines; the [26/27] ratchet still passes (42 C-1 links fail
with the recorded error). Logs:
`~/workspace/fontcustom/ui-checks-real-v25.log`,
`ui-checks-temp-v25.log`. NOTE on png_test/H-4: the [24/27]
comment claims H-4 fixed it, but that is premature for the
binary the suite selects. `../Aster-env/aster` (md5
8a632a5a...) still emits plain `__aster_embed_0` (verified by
nm), so png_test still fails C-2 under the suite. H-4 IS in
`../Aster-env/aster-fixed` (md5 52f82cf9..., namespaced
`__aster_embed_asterui_assets_embeds_ast_h0367ee0f2abf_0`
confirmed by nm); the prebuilt `aster` binary needs
refreshing — a main-chat item, not a UI-side fix. An early
manual png_test link that appeared to pass was an artifact of
mixing objects built by the two different binaries; do not
cite it.
[27/27] now builds Counter 12:2.5 and Gallery 11:2.5;
`ui_hello.ast` label is "v2.5 中文界面".

Delivery: Counter v2.5/code 12 (853,950 B, SHA-256
20145c43ff8ad5b8b3365e4111b426cb980383e48190a9e2cce09879831f64e0),
Gallery v2.5/code 11 (892,854 B, SHA-256
f7fa9596e4b54fe1683563bcc1e73d5f8fa587ec43fe3830c788aa9ca4aa3a2f).
IME probe NOT rebuilt — it links no font code (still v2.0/code
3). Both target-sdk 35, 16K page aligned, verify-apk OK
(v1+v2), no font files, no dex. Uninstall the v2.4 builds
first (fresh debug key each build). NOTE: `check_so.py`
still FAILs both .so files (Counter 30 self-relocations,
unchanged from v2.4; Gallery 50, up from 47 — the 3 new
GLOB_DAT self-relocs are exactly the new Fonts-tab callbacks
whose addresses are taken: `font_weight_event`, `on_font_load`,
`on_font_system`, confirmed by readelf diff against the v2.4
.so) — the prebuilt compiler binary does not contain the H-2
link-so fix yet, so this is the same pre-H-2 state as
v2.0-v2.4, not a regression from this round.

Device checklist for v2.5 (user has no adb; everything below
goes through the Gallery app + its log viewer, System tab):
1. Put the 4 TTFs on the phone FIRST (steps below), then open
   Gallery -> Fonts tab. The path field should already show
   `<ext>/fonts` (the app's external files dir); if it shows
   something else, edit it to that folder.
2. Tap Load with weight Regular. Expected: status shows
   active + `HYZhengYuan-55S` + weight 400 + load ms; the
   specimen card re-renders in the rounder, lighter HYZhengYuan
   style. Compare each line against the 6 effect images:
   "与你不谋而合", "让沟通与信任无处不在", "To enable
   connectivity and trust everywhere", "网络联接世界 创新引领未来",
   "To connect the world with continuous for a better future".
   The HYZhengYuan renderings should look visibly lighter,
   rounder and more open than the system default.
3. Switch weight via the Select (Light/Regular/Medium/Bold):
   each switch should re-render promptly (load ms in the log;
   tens of ms is normal, a visible freeze is a bug) and the
   weight label should change (300/400/500/700).
4. Tap "Use system font": the specimen returns to the system
   Noto Regular; the log shows the restore line. Switch back
   to Regular: identical rendering (headless switch
   determinism is proven; the device check is visual).
5. Log lines to send back (System tab -> log viewer, or
   `Android/data/com.example.asterui.gallery/files/aui.log`):
   `customfont ok ms=<ms> weight=<w>` (or `customfont fail
   err=<e> weight=<w>` if it fails), plus the `sysfont ok ...`
   line (must still show `cff2 1 ... wght 400` — the v2.4
   baseline must not regress) and `sysfont raster A ... e ...
   o ... decodefail 0`.
6. Fallback behaviour: if the folder is empty/wrong, the app
   must NOT go blank — it stays on the system font and logs
   `customfont fail err=1 ...` (missing file). Try it by
   typing a wrong folder and tapping Load.

Font placement, step by step (also shown in-app on the Fonts
tab, keys 602-606):
1. On the computer: unzip `fonts_32_bsfw.zip` (the zip the user
   already has). Inside are the 4 files
   `HYZhengYuan-Light.ttf`, `HYZhengYuan-Regular.ttf`,
   `HYZhengYuan-Medium.ttf`, `HYZhengYuan-Bold.ttf`.
   (If the zip is on the phone instead, extract it with the
   phone's file manager app — no computer needed for this step.)
2. Connect the phone to the computer by USB, allow file
   transfer, and open the phone's storage.
3. Go to `Android/data/com.example.asterui.gallery/files/`
   (the Gallery app's own folder — no permission needed).
   Create a subfolder `fonts` inside it if it is not there.
4. Copy the 4 TTF files into that `fonts` folder. Do NOT
   rename them (the app picks the file by weight; the weight
   itself is read from the file, not the name).
5. Open Gallery -> Fonts tab. The path field should already
   read `<ext>/fonts`; tap Load. If the folder is somewhere
   else, type its full path into the field first.
6. If Load reports `err=1`, the folder/path is wrong — check
   the spelling and that the 4 files are really in that folder
   (the app cannot read arbitrary /sdcard paths without storage
   permissions it does not have, so keep the files in the app's
   own folder above).

NOT verified headlessly (stated, not assumed): (a) the
`<ext>/fonts` default folder on Android 16 scoped storage —
no adb, no device-side probe; the path is user-editable so a
wrong default is recoverable; (b) the device prefill path
(`aui_ext_dir()` -> prefill runs only on attach); (c)
Regular-load-failure -> Bold fallback on the device (still
only headless broken-fixture proof); (d) load-ms values on
the real device (headless asserts only ms >= 0).

## Re-baselining the 16 harnesses (2026-11-14)

Closes the W4-3 follow-up ("re-baselining the 16 harnesses is follow-up
work, not done here"). All 16 now pass headless under qemu, twice in a
row with byte-identical output, and are promoted into `tests/ui-checks.sh`
[24/27] (31 harnesses). No framework behaviour was changed to fit a
baseline; no assertion was weakened or deleted (two checks were
re-expressed, see below, with the reason recorded). Work logs and scripts:
`~/workspace/rebase/` (`apply_rebase.py`, `run16_twice.sh`,
`run16-twice-final.log`, `ui-checks-real.log`, `ui-checks-temp.log`).

### The one discovery that changes the reading of W4-3

Under qemu the harnesses run in FALLBACK font mode: `/system/fonts` does
not exist on the VM (VM fonts live at
`/usr/share/fonts/opentype/noto/`), `ui_sysfont_init()` scans only
Android paths, so no font loads and every harness draws with the 24 px
hand-drawn fallback (flat 24 px advances, no descenders). The reference
harnesses were written against the 48 px `.auf` fonts. Re-baselining to
fallback metrics would have been wrong -- the device uses the TrueType
font. So every harness now loads the TrueType font first, before
`ANativeActivity_onCreate`, via the diagnostic hook
`aui_rt_set_font_path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")`
(the same file the [23/27] fixture symlinks; `select` passes with NO
other edit once the font is loaded -- its check 34 was a missing-font
failure, not a stale expectation). With the font loaded, the failures
are pure SafeArea geometry plus the four real bugs below.

### SafeArea geometry (the single root cause for most harnesses)

At 720x1280 @420 dpi with no content rect, the content area is
(0, 63, 720, 1217): safe_top = safe_bottom = 63 px (24 dp x 2.625),
content height 1154 (was 1280). This is the intended W3 `calc_insets`
behaviour; the old y=0 expectations are stale for devices, not a
product bug. Every value below follows from that one shift (y +63,
height -126), plus the TrueType metrics (see per-harness table).

| harness | old -> new (reason) |
|---|---|
| system | check 21 root h 1280 -> 1154; label key 2 y 63 -> 126 (label sits 63 px below root top, so 63+63). Check 22 (rotated 1280x720) root h 720 -> 594 (720-63-63). |
| top_bar | check 20 bar y 0 -> 63; leading/action rect y 10 -> 73 (x3); root-bg sample (4,4) -> (4,67) (inside bar, expect 0xFF). Check 21 title fit made bar-relative: `(p[15]-p[1])+40 > 126` (was `p[15]+40 > 126`; 102+40=142 failed, 39+40=79 passes). Check 24 hint line y 125 -> 188, surface 124 -> 187 (bar is y 63..189; the old pixels were title ink). Check 26 dark sample (4,4) -> (4,67) (expect 0x1E,0x1E,0x24). |
| nav_bar | check 20 bar y 1112 -> 1049; capsule pixels y 1164 -> 1101 (bar_y+52) x2. Check 21 item 11 y 1112 -> 1049. Check 22 capsule (40/220,1164) -> (40/220,1101). Check 24 hidden-text ink ranges y 1212..1278 -> 1149..1215 (bar_y+100..+166). |
| nav_pane | check 20 pane y 0 -> 63, h 1007 -> 881 (row(2) weight 1 + bottom column 60 fixed 273 px: 1154-273 = 881); capsule (40,60) -> (40,123), (40,190) -> (40,249). Check 21 items y 0/126/252/378 -> 63/189/315/441. Check 22 same capsule moves. Check 24 ink_dark y 30..100 -> 93..163 (x3) and expanded p[3] 1007 -> 881. |
| sheet | check 20 sheet bottom `sy+shh != 1280` -> `!= 1217` (bottom-anchored to content bottom). Check 21 surface pixel (360,1270) -> (360,1212) (1217-5; y=1270 is below the content bottom, scrim-covered). |
| toast | checks 14/17/19 `1280 - 63` -> `1217 - 63` (= 1154) x3. Check 14 centering re-expressed with +/-1 px tolerance: width 429 is odd, exact centering is impossible (145+429=574 vs 720-145=575); the toast is centred within a pixel, which is quantization, not a layout change. |
| vlist | check 14 vr y 144 -> 207, h 992 -> 866. Check 16 row 0 y 144 -> 207, row 2 y `144+2*168` -> `207+2*168` (= 543). Check 18/19 selected-row pixels moved to the new row positions ((700,553), (700,889)). Check 20 scroll max 839008 -> 839134 (= 5000*168-866). Check 21 comment "视口 992 px" -> 866 (ranges pass; first 2378, last 2388). Check 22 `ylast` 144 -> 207 (= 905), bounds 144/1136 -> 207/1073. |
| vgrid | check 14 vr y 144 -> 207, h 992 -> 866. Check 16 cell 0 y 144 -> 207, cell 4 y 480 -> 543. Check 18/19 selected-cell pixels (700,154) -> (700,217), (460,490) -> (460,553). Check 20 max 111211 -> 111337 (= 334*315+333*21-866). Check 21 comment "441/455" -> "438/461" (ranges pass). Check 22 last cell y 821 -> 758 (= 866-315+207), bottom 1136 -> 1073. |
| hlist | check 14 vr y 144 -> 207, h 992 -> 866 (comment "992 px 项高" -> 866). Check 16 item 0 y 144 -> 207, h 992 -> 866. Check 22 last item y 144 -> 207. (mx 440259 unchanged -- horizontal max depends on width.) |
| select | NO value change. Passes unchanged once the TrueType font is loaded (check 34 'g' descender ink at rows 381..392; fallback had no descender). |

### Real bugs found and fixed (not re-baselined)

1. **anim: Replay button unreachable (example bug).** The anim page is
   1801 px tall with a plain-column root, so the Replay button
   (y=1330, centre 1387) is permanently below the fold and outside the
   root rect, so the tap cannot land (`hit_test` is pure rect
   containment). The reference has the same latent bug (its button is
   at y~1267, centre ~1324, also outside its 1280 root) -- it cannot
   have passed at 720x1280 either; on the user's 1216x2688 phone the
   page fits. Fix: `examples/ui_anim.ast` root `aui_column(1)` ->
   `aui_scroll(1)` PLUS `aui_weight(1)` after it. The weight is the
   part that matters: without it the scroll container sizes to its
   content (1801 px) and `scroll_max` is 0 (measured); with it the
   container is viewport-sized and `scroll_max` is 528. The harness
   scrolls the button into view (to y=743) before tapping. (A
   `card()` missing `aui_end()` was tried and reverted -- it changes
   the reference layout but was not the scroll blocker; the nesting
   quirk is recorded here, not fixed.)
2. **time: hint line unreachable + handle-centre pixel too strict
   (example + harness).** The time page is a plain column, content
   bottom 1304 > 1280 (1217 content). Fix: `examples/ui_time.ast`
   root `aui_column(1)` -> `aui_scroll(1)` (it already had
   `aui_weight(1)` after it, so it scrolls); check 90 becomes a
   scroll-reachability check (scroll to max, hint line fully inside
   63..1217). Check 28 re-expressed as a +/-2 px neighbourhood
   primary check: the 24-minute handle centre is covered by the "25"
   label ink (v1.29.1 draws labels last, after the 5 dp handle
   circle); the handle IS present (primary blob x 446..486, y
   955..1001, verified by region scan). The single-centre-pixel
   assertion cannot hold given that trade-off; the neighbourhood
   check preserves its intent (a primary handle at the right angle).
3. **tree: "generated" row 16 px below the fold (harness).** Row 111
   sits at content offset 767, viewport 751. Fix (sections D and F):
   scroll to 150, tap, scroll back to 0 before the next frame, so the
   section-F scroll test (which sets an absolute 200 and requires
   `scroll_max` >= 200 -- collapsing shrinks it to 110) still works.
4. **menu: dark toggle off-screen, then its anchor off-screen
   (harness).** The dark switch (key 23) is at y=1285; `show_key(23,
   300)` brings it to y=713 and the tap toggles dark (root bg 18,
   verified). But that scroll pushes the menu-open button (key 10) to
   y=-154, so the menu never opens (`aui_debug_menu` returns -1).
   Fix: `show_key(10, 300)` after the dark toggle, before opening the
   menu.
5. **layout: mode buttons below the content bottom (harness).**
   Button 32 centre y=1220 (> 1217 content bottom), button 34 at
   y=1282 (off-screen). The page IS scrollable (`aui_scroll(1)`).
   Fix: `show_key(32/34, 300)` before tapping. This also fixes the
   knock-on check 30 (tap counter 970 was 2 short because the mode
   taps never registered).
6. **icon: press indicator clipped by the SafeArea floor (harness).**
   The indicator darkens 246 -> 237 everywhere inside the button
   below y=63 but is clipped above it; the old sample point (67,27)
   is above the content top. Fix: sample the bottom-left inset
   `(pb[0]+15, pb[1]+pb[3]-15)` instead of the top-left.

### Promotion + suite results (2026-11-14)

- `tests/ui-checks.sh` [24/27] now runs 31 harnesses (15 original + the
  16 above); header comment and PASS line updated. No H-3/H-4
  requirement was touched.
- Real suite: [22/27] PASS (125 files, 0 failures); stops at [23/27]
  on the recorded H-3/C-1 link error (prebuilt `../Aster-env/aster`
  is still md5 `8a632a5a…`, pre-H-3/H-4), SUITE_EXIT=1 -- as expected.
  Font adapter (frozen hashes) + gallery smoke + nav watchdog ran
  before the H-3 link and passed (their frozen hashes did not move).
- Temp-copy full run (log `~/workspace/rebase/ui-checks-temp.log`,
  copy deleted after): **28 PASS lines, 21/21 old + 6/6 new-base,
  SUITE_EXIT=0**, skipping ONLY the [23/27] font_runtime_test link
  (H-3) and the [24/27] png_test link (H-4), both annotated in the
  log. [26/27] BLOCKED ratchet stayed green (42 C-1 links still fail
  with the recorded error).
- Each re-baselined harness passes twice in a row with byte-identical
  output (log `~/workspace/rebase/run16-twice-final.log`).
- Delivered v2.5 APKs NOT rebuilt: the only example changes
  (`ui_anim`, `ui_time`) are not included by `ui_hello`/`ui_gallery`,
  and no framework file changed, so Counter v2.5 / Gallery v2.5 SHAs
  stand (`20145c43…` / `f7fa9596…`).

## v2.5.1: text-pool capacity + Fonts path visibility (2026-11-14)

Device bug, found by the user on v2.5: the Fonts tab path field
truncated the font folder path, so custom-font loading always
failed with err=1 even though the files were in place
(`/storage/emulated/0/Android/data/com.example.asterui.gallery/files/fonts/HYZhengYuan-Bold.ttf`,
confirmed present by the user; 8x `customfont fail err=1` in their
log, system font intact, `customfont restore ok` fallback working).

### Root cause

The framework text pool holds every text field in 64-byte slots
(`AUI_TEXT_MAX = 63`, `g_aui_text_pool: u8[2048]` = 32 x 64 B).
The real folder path is 72 chars, so the prefill
(`aui_text_set(610, ...)` in `tab_fonts`) was silently truncated
to `.../gallery/fi` (63 chars); `font_load_current` then appended
`/HYZhengYuan-<Weight>.ttf` to that truncated folder, which does
not exist. The screenshot showed the tail of the truncated string
(the field renders the fitting tail by design, `text_fit_start`);
swiping showed nothing more because the stored string genuinely
ended at "fi" -- the field is single-line with no horizontal
scroll offset, and there was nothing more to reveal.

### Fix

- `stdlib/asterui/aui_impl.ast`: pool slot 64 -> 256 B
  (`AUI_TEXT_SLOT = 256`, `AUI_TEXT_MAX` 63 -> 255, pool
  2048 -> 8192). The stride is centralised in the one constant:
  all 8 `idx * 64` sites now read `idx * AUI_TEXT_SLOT`
  (`aui_text_field`, `text_slot`, `text_append`, `text_backspace`,
  `text_clear`, `text_set`, `combo_text_ptr`, `aui_text_value`).
  No other file references the pool. Cost: +6 KB static. A
  255-char field still fits `font_load_current`'s 200-char folder
  cap (200 + 1 + 23 = 224 < 256-byte path buffer). The
  "keep the folder in g_font_def_folder as source of truth"
  alternative was rejected: the field is the editor, so a
  truncated editor would still corrupt long paths on edit, and
  the displayed value would diverge from the value used.
- `stdlib/asterui/examples/ui_gallery.ast`: label 603 now mirrors
  the field's live value (`aui_text_value(610)`) instead of the
  prefill copy -- the old label showed the prefill even after the
  user edited the field, so it lied about the folder actually
  used. The label wraps (`layout_text` breaks a long word per
  character; `AUI_LINE_CAP` is 64), so the full 72-char path is
  inspectable by scrolling to the top of the Fonts tab; the
  single-line field keeps showing the fitting tail (now ending
  in `/fonts`), which proves the full path is stored.

### Tests (no existing hash moved)

- `font_adapter_test.ast` section K (exit 57-58): Regular +
  Bold load through a 72-char folder (96-char file path, exactly
  the device Regular path) and Regular through a 96-char folder
  (120-char file path); 'A' hashes equal the section J
  Regular/Bold hashes. Three new `GLYPHHASH` lines in
  `tests/baseline/font_adapter.pixels` (section K comment); RTFB
  stays `2 5 1`.
- `gallery_smoke_test.ast` section H2 (exit 26-28): the 72-char
  folder through the real field (round-trip `aui_text_len(610)`
  == 72), Load, Regular weight 400, label 603 taller than the
  single-line label 601 (wrap proof), restore. With the old
  63-char pool the round-trip fails outright.
- `tests/ui-checks.sh` [23/27]: two long fixture folders under
  `/tmp/aui-hyzy-test/` (symlinks only, fonts never copied);
  lengths asserted in the script (72 / 96). [27/27] versions
  Counter 13:2.5.1, Gallery 12:2.5.1.

## Canvas custom drawing node — v2.6 (2026-11-15)

Headline: the first HuxerUI-gap round (GAP.md §4). A Canvas node lets
an app draw with the six existing display-list commands inside a
rectangle it owns; the node is non-interactive (hit testing skips it)
and the draw callback may only emit draw commands. No compiler
change was needed: the node kind, the callback slot (`cb`/`user`)
and the clip machinery already existed.

### API (aui.ast)

- `aui_canvas(key, w_dp, h_dp, draw_fn, user)` — a leaf node, kind
  57. The size parameters are deliberate: GAP.md §4.2 writes
  `aui_canvas(key, draw_fn, ctx)` but a canvas with no intrinsic
  size cannot lay out (precedent: `aui_image(key, rgba, w, h)`).
  `w_dp == 0` + `aui_align(3)` stretches to the parent width;
  `h_dp` must be > 0. `draw_fn` receives `user` as its only
  argument (`fn(ptr) -> i32`); `aui_cv_size(out)` reports the
  laid-out `[w_dp, h_dp]` inside the callback (-1 outside) so the
  callback can centre its composition -- the HuxerUI PaintContext
  Size, in Aster form.
- Primitives (all dp, relative to the canvas top-left, only inside
  the callback; outside they return -1 and emit nothing):
  `aui_cv_rect(x, y, w, h, color, radius_dp)` (radius 0 = square),
  `aui_cv_text(x, y, text, color)` (single line), `aui_cv_image(x,
  y, w, h, rgba, iw, ih)` (RGBA8888, stride iw*4), `aui_cv_ring(x,
  y, d, color, ring_dp)` (**ring_dp is the THICKNESS**; 0 = filled
  disc), `aui_cv_tri(x, y, w, h, color, dir)` (dir 0 right, 1
  down), `aui_cv_line(x0, y0, x1, y1, color, half_dp)` (half width).
  All six map to the existing display-list ops 1-6; no new op was
  added. Colours are 0xAARRGGBB, normally `aui_theme_color` tokens.

### Contract (also in aui.ast, canvas_draw.ast header, both tests)

- The callback runs during paint, inside the node's clip rect:
  commands outside the rect are clipped (never drawn outside).
- The callback must ONLY emit draw commands. It must not change
  state, build controls, or create nodes: `node_alloc` refuses
  while a draw is running (returns -1), so `aui_label` /
  `aui_canvas` / any builder inside the callback is a no-op that
  returns -1. Out-of-contract behaviour is undefined; there is no
  silent fallback and no error is logged for it.
- Hit testing v1 skips the Canvas interior: `find_clickable`
  excludes kind 57, so a tap on a Canvas neither invokes the
  draw function as a click handler nor blocks the scroll container
  behind it (drag starting on the Canvas scrolls the page).

### Runtime (aui_impl.ast)

- Kind 57, `measure_canvas` (fixed dp2q size from aux, like
  `measure_image`), `q2dp(q)` helper (inverse of `dp2q`).
- `paint_node`: kind 57 narrows the clip to the node rect, sets
  the canvas origin/size globals, sets `g_aui_in_cv = 1`, calls
  `n.cb(n.user)`, then restores clip/origin and clears the flag.
  The clip restore is a separate occurrence of the kind list from
  the narrow block -- both gained kind 57. The origin is n.x/n.y
  WITHOUT the anim paint offsets (`cmd_add` adds those, as for
  every other paint path). Kind 57 is in the leaf bg-paint list,
  so `aui_bg()` works on a Canvas.
- `aui_cv_ring` thickness bug, found by the harness grid probe
  (2026-11-15): the first implementation passed `ring_dp`
  straight through as the display-list inner radius, so a "2 dp
  thick" outline ring drew as a filled disc with a 2 dp hole and
  covered the whole Taiji with primary. The fix converts
  thickness to inner radius (`rin = d/2 - thickness`, 0 stays a
  filled disc). `canvas_test` section C now has a hole-edge check
  ((170, 20), distance 10 from the centre) that distinguishes the
  thickness contract from an inner-radius reading.

### Example (HuxerUI examples/canvas, read-only reference)

`examples/canvas_draw.ast` is the shared demo content; both
`examples/ui_canvas.ast` (standalone) and the Gallery Canvas tab
include it. Layout follows HuxerUI `examples/canvas/main.cpp`
(Title + subtitle + Tabs {Taiji, Orbit, Path} + a surface card
holding one Canvas, 280 dp high, stretched width). Effects are
redrawn with v1 primitives only; approximations are documented in
the file header: Taiji = disc pair (no semicircle fill / circular
clip in v1 -- the S-curve halves are two discs; a true taiji waits
for the path/clip round); Orbit = three full concentric rings
instead of arcs (dots at HuxerUI's angles -18°/144°/104.4° via
integer cos/sin approximations); Path = rounded panel + triangle +
solid rule + text + icon + plain ground strip (no paths/dashes).
All seven primitives appear across the three effects; colours
only from theme tokens; geometry is integer dp math (±1 dp
truncation). A deliberate clip probe lives in the Path effect: a
60x60 TEXT rect at (w-20, h-20) shows as a 20x20 dark tab on the
panel corner and must leave nothing in the card padding.
**Gallery, not a standalone app**: the 7th tab reuses the
established Gallery pattern (no 4th APK/recipe/gate section); the
7-tab bar is ~1080 px wide in the headless fallback font, so the
smoke test reaches the Canvas page via `gallery_set_tab(6)`.
Future rounds' verification examples should likewise prefer the
corresponding HuxerUI `examples/` example (gestures, scroll_view,
split_layout, task, theme, ...).

### Tests + suite

- `tests/canvas_test.ast` (headless 320x240 @160dpi, C-1 blocked,
  in the [26/27] ratchet): all seven primitives + two
  out-of-bounds clip rects + contract probes (primitives outside
  draw -> -1; builders inside draw -> -1; `aui_cv_size` reports
  200x120); `CANVASHASH canvas 5187323947181030054` (twice,
  deterministic). Frozen baseline
  `tests/baseline/canvas.pixels` (2 lines, added only). Note: the
  headless content top is the 24 dp SafeArea, so the canvas sits
  at y = 32, not 8 -- the reference `*_test` files still assert
  y == 8 and are stale (icon_test fails the same way under
  aster-fixed); pixel checks are computed from the measured rect
  origin. The second frame needs `aui_invalidate()` first or the
  pump skips painting and the callback does not re-run.
- `tests/canvas_harness.ast` (720x1280 @420dpi, [24/27]):
  A. canvas rect (280 dp high, stretched); B. Taiji pixels
  (dark top disc sampled 20 dp off-centre -- the eye dot sits on
  the disc centre and covers a ±10 px sample -- light bottom
  disc, dark eye, primary ring); C. Orbit by tap; D. Path by tap;
  D2. clip probe + clean card padding; E. dark theme follows the
  tokens; F. drag on the Canvas scrolls the page exactly +120 px
  (all three motion events share one timestamp -- 10 ms spacing
  flings +30 px) and scroll-back leaves the drawing undistorted.
- `tests/ui-checks.sh`: [23/27] `gallery_smoke_test` links
  `canvas_draw.o` (new section I: Canvas tab via set_tab(6),
  effect tabs 711/712/713); [24/27] `canvas_harness` runs as an
  explicit line (not in the MAP -- its example needs the extra
  `canvas_draw.o`; `include` is declaration-only, so `ui_canvas.o`
  leaves `canvas_page`/`g_cv` undefined); [26/27] ratchet gains
  `canvas_test` (43 items); [27/27] Gallery `link-so` gains
  `canvas_draw.pic.o`; versions Counter 14:2.6, Gallery 13:2.6.
  [22/27] picks the new files up by glob (129 files).
- Regression surface: existing 21/21 + 6/6 unchanged; the frozen
  baseline only ADDS the two CANVASHASH lines.

### Device results

- v2.6 APKs (built from the copy tree; see the Canvas round
  report in ~/workspace/canvas/): Counter v2.6/code 14, Gallery
  v2.6/code 13, verify-apk OK, target-sdk 35, 16K LOAD alignment,
  no font files, no dex. Acceptance checklist for the device:
  all seven contents drawn at once on the Canvas tab; no
  distortion after scroll; dark theme follows the tokens; no new
  error/fail log lines.
- Merge note: the patch must land only after the 5-segment full
  gate finishes (the tree is frozen while the gate runs); the
  ms=0 clock-injection fix landed as v2.5.2 in the live tree before
  this patch was rebased (2026-11-15); the patch below is rebased
  onto v2.5.2 (C-1 promotion + ms=0), it does not touch that work.

## v2.6.1: tab bar horizontal scroll (device bug, 2026-11-15)

- Rebase note: the v2.6.1 work was first built on the pre-v2.5.2
  tree (codes 15/14) and re-verified after v2.5.2 (C-1 promotion +
  ms=0 clock injection) landed in the live tree 2026-11-15. The
  patch below is rebased onto v2.5.2; versions are 16/15 because
  v2.5.2 took codes 15/14. The pre-rebase verification logs
  (`ui-checks-*-v261.log`, `rebuild-apks-v261.log`) are superseded
  by the `*-v261b.log` runs on the rebased tree.
- Bug (user report, 2026-11-15 07:50): Gallery has 7 tabs; the tab
  bar does not scroll, so the 7th (Canvas) tab is unreachable on the
  device (1216x2688, 520 dpi). Headless never caught it: the smoke
  test switched tabs by `gallery_set_tab` / key tap, never by
  dragging the bar.
- Root cause (framework, not Gallery): `arrange_tabs` laid tabs out
  left-to-right with no scroll offset; `measure_tabs` discarded the
  content width, so no max offset was ever registered; kind 19 was
  not in `find_scrollable`, so a horizontal drag on the bar claimed
  no scroll container at all (`SCROLL_MAX 0`, `SCROLL_AFTER 0`).
  Paint clip (kind 19 already in `paint_node`'s clip list) and
  hit-test (clipped to the container) already behaved; only the
  scroll plumbing was missing.
- Measured (probe `~/workspace/canvas/zz_tabs_repro.ast`, before
  the fix; log `zz_tabs_repro_before.log`):
  - 960x1024 fallback font: bar 1080 px, viewport 960, overflow
    120; Canvas tab at x=912 w=168 (spans 912..1080; 48 px sliver
    visible, centre off-screen); drag 800->400: scroll stays 0.
  - VM TrueType font: bar 1114 px.
  - Device geometry (520 dpi, 1216 px viewport): bar 1492 px
    (48 px em is density-independent; the 12 dp side padding per
    tab is 39 px at 3.25x, +54 px/tab vs headless), overflow 276;
    Canvas tab at x=1254 w=238 (spans 1254..1492, fully off-screen);
    Fonts spans 1052..1254 (mostly visible). Matches the report:
    tabs 1-5 fully visible, Fonts mostly, Canvas invisible.
  After the fix (log `zz_tabs_repro_after.log`): 960 px drag
  scrolls to max 120, Canvas at 792..960, tap switches to tab 6;
  device geometry drag scrolls to max 276, Canvas at 978..1216,
  tap switches to tab 6; probe rc=0.
- Fix (framework-level, in `aui_impl.ast`; no Gallery-side change
  was needed -- the bar is a plain `aui_tabs` container):
  - `arrange_tabs`: sums the tab widths, registers
    `scroll_store_max(key, sumw - viewport_w)` and arranges from
    `cx - scroll_get(key)` (Q16.16, same table as ScrollView).
  - `find_scrollable`: kind 19 joins the scrollable kinds.
  - DOWN handler: kind 19 claims the drag with axis 1 (horizontal),
    like hlist (kind 55). Drag/fling reuse the existing machinery
    (8 dp slop cancels the press; same-timestamp events avoid fling
    overshoot); the scroll-blit fast path does not cover kind 19,
    so a tab-bar drag repaints fully (one row; fail-safe by design,
    `g_aui_scroll_vp_ok` stays 0).
  - `aui.ast`: `aui_tabs` documents the horizontal scroll.
  - Not done: auto-scroll the selected tab into view (no device
    path reaches an invisible selected tab -- selection only
    changes by tapping a visible tab); follow-up if ever needed.
- Tests: `gallery_smoke_test` gains section J (exit 33-37): drag
  the bar left, Canvas on-screen, tap switches to 6; drag back,
  scroll resets to 0, tap Input switches to 0. Offsets are read via
  `aui_debug_scroll_max`, never hard-coded. No frozen baseline
  changes (smoke is exit-code based; `tabs_test` rects are at
  offset 0, unchanged; `canvas_test`/`canvas_harness` effect tabs
  fit, max offset 0).
- Versions: Counter 16:2.6.1, Gallery 15:2.6.1, IME probe
  unchanged (3:2.0). `ui_hello.ast` label "v2.6.1". (v2.5.2 took
  codes 15/14; v2.6.1 is 16/15 so an upgrade over v2.5.2 installs.)
- Delivered v2.6 APKs' `configChanges` (checked 2026-11-15 with
  `tests/validate_apk.py`, the only failing check for both APKs):
  **0x490** (keyboard|orientation|screenSize), not 0x1F90 -- the
  v2.6 APKs were built with the pre-H-1 suite binary
  (md5 8a632a5a...). Missing: screenLayout, uiMode,
  smallestScreenSize, density. CORRECTION (device-verified
  2026-11-15 08:14, user rotated the v2.6.1 Gallery): 0x490 DOES
  include ORIENTATION (0x80), and the manifest has no
  screenOrientation/portrait lock -- the app does NOT restart on
  rotation, it simply does not switch: the backend never responds
  to the size change (no relayout/redraw on resize). The fix is
  framework-side (onConfigurationChanged / window resize ->
  relayout + redraw) and is UNRELATED to 0x1F90; it moves to
  v2.6.2. v2.6.1 built with the same suite binary stays 0x490;
  0x1F90 still needs the binary refresh (H-1 is in source;
  main-chat work), but it is not the landscape fix.
- Device results (user, 2026-11-15 08:14-08:15, 3 screenshots +
  log): **tab-bar scroll CONFIRMED** -- the user dragged the bar
  to the Canvas tab. System-font baseline intact (Regular TTC,
  cff2 1, wght 400), no error/fail lines in the log. Three new
  issues filed for v2.6.2 (separate round): Taiji/Orbit/Path tab
  switching lags, Taiji drawn wrong (not a real ☯), landscape
  does not switch (see above).

## v2.6.2 -- Canvas: tab-switch lag, true Taiji, Orbit arcs, landscape (2026-11-15)

Fixes the three device-reported issues from the v2.6.1 verification
(2026-11-15 08:14, 3 screenshots + log). Worked in a copy tree;
patch replaces canvas-v2.6.1.patch (merged v2.6.1 + v2.6.2).

Rebase note (2026-11-15): the coordinator's 39-test re-baseline
finished in the live tree after v2.6.2 was built (cjk_test and
select_test fixed, 42/42 promoted to [24/27]); this patch was
rebased onto it. The suite counts in the v2.6.2 subsection below
are the re-based values; the 41/43 figure from the v2.6.2 round
was a pre-re-baseline snapshot, not a regression.

### 1. Tab-switch lag -- root cause: fill_ring was per-pixel isqrt

Measurement first (probe ~/workspace/canvas/zz_v262_probe.ast,
qemu, 720x1280 fake host, one tap-switch + frame): draws 3, paints
3 per switch (deterministic), but isqrt calls per switch were
Taiji->Orbit 1,313,880, Orbit->Path 342,425, Path->Taiji 869,895;
a bare Orbit frame alone cost 682,690 isqrt calls. The hotspot was
fill_ring: one Newton-iteration isqrt (with an i32 division per
step) per pixel, ~99.9% of all isqrt calls. The pipeline was NOT
the problem (3 draws per switch is the same before and after).

Fix (aui_impl.ast, exact-equivalent output -- same formulas,
reorganised): scanline fill_ring. Per row, chord bounds via isqrt
(2-4 per row instead of 1 per pixel); interior runs use fill_run
(proven identical to per-pixel fill_px_cov(255)); edge pixels use
the exact per-pixel formula (ring_px_radial / arc_cov). New
helpers floor_div16 / ceil_div16 / ring_px_radial / arc_cov /
ring_row_bounds / ring_edge. A measurement bug was found and fixed
on the way: the ring middle-edge loop visited the whole hole
(~129K px/frame) even though the formula returns 0 there.

After the fix (same probe): to_orbit isqrt 35,934 (36.6x),
to_path 10,840 (31.6x), to_taiji 20,322 (42.8x), bare Orbit frame
19,520 (35x). Draws/paints unchanged (3/3). Pixel-exactness is
proven by the suite, not the probe: canvas_test's frozen
CANVASHASH reproduced the v2.6 value before the new draws were
added, and canvas_harness pixel sections pass.

After the demo rewrite (arcs replace full rings, half-disc added):
to_orbit 32,317, to_path 8,934, to_taiji 26,625, bare Orbit frame
15,708; draws still 3 per switch. Taiji rose from 20,322 because
the true Taiji draws one more real disc (the old bottom disc was a
no-op) plus the half-disc; fill_half is scanline-based (reuses
ring_row_bounds), not per-pixel. Estimated single-frame cost is now
~5-10 ms on device vs ~100 ms+ before (device to confirm).

Regression test: canvas_harness section H (exit 31) bounds the
draw_fn calls across one tap-switch to 1..4 (measured 3). The bound
is on draw calls, not raster work; the isqrt numbers above are the
probe evidence, recorded here. (The probe's temporary isqrt/ringpx
counters were removed before delivery; cv_draw_calls() and
aui_debug_paint_gen() stay.)

### 2. Taiji / Orbit / Path redrawn per HuxerUI examples/canvas

- Taiji (PaintTaiji): surf disc -> left half-disc (dark, new op 7)
  -> top small dark disc -> bottom small light disc -> top eye
  (light) -> bottom eye (dark) -> outline ring, width
  max(2, r*0.025). The clip is redundant (all shapes lie inside
  the big disc). Static frame; rotation animation out of scope.
- Orbit (PaintOrbit): 3 arcs, not full rings -- arc 0.70r primary
  thick 0.055r start 72 deg span 248 deg; arc 0.46r tint thick
  0.045r start 234 deg span 58 deg; dashed ring 0.86r onpri thick
  0.025r start 194 deg dash 5 deg gap 3 deg (spec 5.33/3.33 deg,
  integer degrees, sub-pixel difference). Centre dot + 3 satellite
  dots at the arc starts (covering the start caps); round end caps
  (discs, radius thick/2) at arc1 end 320 deg and arc2 end 292 deg.
  Angles converted from HuxerUI's 0 = 3 o'clock to ours, 0 = 12
  o'clock (ours = hx + 90).
- New Canvas API (aui.ast + aui_impl.ast, ops 7-8, AuiCmd struct
  unchanged -- dash reuses the unused tlen field):
  aui_cv_half(x, y, d, color, dir) (0 left / 1 right / 2 up /
  3 down, diameter edge included, invalid dir -> 0);
  aui_cv_arc(x, y, d, color, thick_dp, start_deg, span_deg)
  (degrees, 0 = 12 o'clock clockwise, thick 0 = solid sector);
  aui_cv_dashring(x, y, d, color, thick_dp, start_deg, dash_deg,
  gap_deg) (full circle, invalid dash/gap -> 0). All three guard
  g_aui_in_cv -> -1 outside draw, same contract as the other six.
  fill_ring gained start/span/dash/period (Q16.16 circles);
  fill_half is the scanline half-disc above.
- Path: the white rule at 18% panel height now stops 8 dp before
  the icon's left edge (it used to run under the icon and cross
  the "A" -- confirmed by geometry: rule y = iy + ph*18/100 sits
  inside the icon's 48 dp box). The stray black square at the
  card's bottom-right was the clip probe (an intentional probe
  leaked into the shipped demo); it is now behind cv_set_probe(v)
  (default off, test-only). Path's remaining gap is honest: HuxerUI
  fills a cubic-bezier S-shape; v1 has no paths, so Path stays an
  approximation (rounded panel + triangle + rule + text + icon).
- Captions updated (Orbit "3 arcs + dashed ring", Taiji "left half
  dark ... ring max(2, r*0.025)", Path "rule 2 dp"); subtitle now
  "ten primitives".

Tests: canvas_test draws all three new primitives + invalid-arg
contract probes (exit 18 half-disc, 19 arc, 20 dashed ring,
21 contract) and its frozen baseline was re-frozen
(CANVASHASH canvas -2723322295871047197, twice in one run and twice
across runs, deterministic; was 5187323947181030054 in v2.6).
canvas_harness: B adds left-middle dark + right-middle light
(the true S-curve); C adds arc1 present at the left point (our
270 deg) + absent at the top (0 deg); D adds the rule/icon check
(a 2 px tall box just inside the icon's left edge at the rule's
height must be blue -- thinner than the 2 dp rule, so the old rule
would read all white) + a probe-off-by-default check (the canvas
corner is light, not the dark tab); D2 enables the probe via
cv_set_probe(1), checks the tab + clean padding, then disables it.

### 3. Landscape -- root causes: stale window size + stale rect

Device facts (verified, not re-checked): manifest has no
screenOrientation/portrait lock; configChanges 0x490 already
includes ORIENTATION (0x80); the app does NOT restart -- it
simply never responds to the size change. 0x1F90 is NOT the
landscape fix (it adds density/screenLayout/uiMode bits and comes
with the suite-binary refresh, main-chat work).

Two mechanisms, both probe-proven (canvas width is the signal:
portrait 531, landscape 1091):
1. aui_cb_rect never re-read the window size, so a new landscape
   rect was interpreted against the stale portrait window and
   calc_insets clamped it back to portrait width.
2. A stale stored content rect pins the layout even after the
   window size updates: calc_insets clamped the stale portrait
   rect (0,0,720,1280) into the landscape window -> root width 720.

Fix (aui_impl.ast):
1. aui_cb_rect re-reads the window size first, then discards a
   rect that does not fit the fresh window (g_aui_ct_valid = 0 +
   invalidate + return). A valid content rect always fits inside
   its window, so discarding cannot hurt a valid rect.
2. calc_insets ignores a stored rect that does not fit the current
   window (falls back to the 24 dp estimate). A fitting rect is
   preserved (density/night config changes keep it).
A first attempt (blanket g_aui_ct_valid = 0 in aui_cb_config) was
REVERTED: it broke system_harness exit 25 (after a night + 160 dpi
config change the content rect (40,60,1240,660) must SURVIVE --
only an orientation/size change invalidates it, and that is what
the fit check detects).

Probe matrix after the fix (all canvas widths): E1 rect-only
1091, E2 resize-only 1091, E3 config-only 1091, E4 rect + stale
window 531 (correct), E5/E6 sequences 1091, all resets 531.

Regression test: canvas_harness section G (exit 27-30): E1
rect-only -> landscape w in [1080, 1100], reset -> portrait
[520, 545], E3 config-only -> landscape, reset -> portrait.

### Versions / suite (v2.6.2)

- Versions: Counter 17:2.6.2, Gallery 16:2.6.2, IME probe
  unchanged (3:2.0). `ui_hello.ast` label "v2.6.2".
- Suite (aster-fixed, md5 86234516...): [22/27] compile gate
  129 files 0 failures; [23/27] PASS; [24/27] PASS (31 harnesses
  + png_test + canvas_harness + 42 promoted (3 in v2.5.2, 39
  re-baselined 2026-11-15); [25/27] PASS;
  [26/27] C-1 link gate 43/43 link, 43/43 run green (the 42
  re-baselined tests plus canvas_test, the 43rd; re-based run:
  ~/workspace/canvas/ui-checks-fixed-v262r.log);
  [27/27] PASS (Counter 17 / Gallery 16). Real suite (old binary)
  stops at [23/27] H-3 as expected.

## src/ restructure (2026-11-15)

User: repo root was flat (4 framework .ast files at root), not a
standard engineering layout. Moved the framework sources under
`src/`, everything else untouched:

- `aui.ast`, `aui_impl.ast`, `font_runtime.ast`, `aster_std.ast`
  (vendored) + `render/` -> `src/aui.ast`, `src/aui_impl.ast`,
  `src/font_runtime.ast`, `src/aster_std.ast`,
  `src/render/truetype.ast`, `src/render/text.ast`.
- `examples/`, `tests/`, `docs/`, `assets/`, `ADOPTION-NOTES.md`,
  `README.md`, `.gitignore` stay where they were.
- Includes rewritten (87x `../aui.ast` -> `../src/aui.ast`,
  9x `../aster_std.ast` -> `../src/aster_std.ast` in tests +
  `assets/embeds.ast`; `src/render/text.ast` now
  `../../assets/embeds.ast`; `font_runtime.ast` and
  `src/render/truetype.ast` includes unchanged — same relative
  layout inside `src/`).
- `tests/ui-checks.sh`: mount detection `$FW/src/aui.ast`,
  standalone `STD=$FW/src/aster_std.ast`, [22/27] + [23/27] file
  lists and the [27/27] APK loop now under `$NB/src/`;
  `tests/run_qemu.sh` builds `src/aui_impl.ast`; `README.md`
  layout + build commands updated. No compiler-side reference to
  the moved files existed (only `ci.sh:343` pointing at
  `tests/ui-checks.sh`, unchanged, and historical notes) — nothing
  changed in the compiler repo for this restructure.
- Verification (standalone, new repo; logs
  `~/workspace/canvas/ui-checks-{fixed,real}-src*.log`):
  aster-fixed re-run SUITE_EXIT=0 — 6/6 new-base PASS, [26/27]
  43/43 link + 43/43 run green, Counter 17 / Gallery 16 APKs
  verify OK. First fixed run died at [24/27]
  (`menu_harness` exit 124, timeout 20) under parallel §6.3
  load on the 1.5-core VM; re-run passed everything, so the
  timeout was a load pseudo-failure, not a regression — timeout
  20 was NOT relaxed. Old binary: [22/27] PASS (129 files),
  stops at [23/27] H-3 with the recorded C-1 error, as expected.

  Mounted (compiler repo, submodule at this commit; logs
  `~/workspace/canvas/ui-checks-{fixed,real}-src-mounted*.log`):
  aster-fixed 28 PASS lines (21/21 old + 6/6 new-base), [26/27]
  43/43 link + 43/43 run green, SUITE_EXIT=0; old binary 22 PASS,
  stops at [23/27] H-3 as expected. First mounted fixed run also
  died at [24/27] on `menu_harness` exit 124 under the same
  parallel §6.3 load; re-run passed everything — same load
  pseudo-failure, timeout 20 untouched.
  APKs rebuilt from the new layout (`~/workspace/canvas/apk-src/`):
  Counter v2.6.2/code 17 (871,454 B) + Gallery v2.6.2/code 16
  (927,950 B), verify-apk OK (v1+v2), no font files, no dex, 16K
  LOAD align; .so md5 byte-identical to the delivered packages
  (libcounter.so f2dbc6251c27edda8d14d06753253247, libgallery.so
  ffd21d961a2d8fc3fa37f3d043abbfaa; whole-APK SHAs differ only by
  the fresh debug key, as usual).

## v2.7 -- Long-press gesture + scroll jank (2026-11-15)

Two pieces, one commit, verified separately.

### Long-press (HuxerUI gap #2)

- API (`src/aui.ast`): `aui_long_press(cb, user)` (modifier, attaches
  to the most recently created node, or the just-closed container
  after `aui_end()`, same rule as `aui_tooltip`) +
  `aui_long_press_key()` (key of the fired node, read inside the
  callback, segmented/tabs getter pattern).
- Threshold 500 ms (`AUI_LP_NS`): Android
  `ViewConfiguration.getLongPressTimeout()` and HuxerUI
  `LongPressGesture` default 0.5 s agree. Movement tolerance 8 dp
  slop, same as tooltip/drag.
- Design: mirrors the tooltip pending pattern exactly (registry cap
  32, `find_lp` walks ancestors like `find_tip`, pending state
  snapshotted at DOWN, `lp_tick()` from `pump_ui()` right after
  `tip_tick()`, `lp_busy()` added to `scroll_blit_plan` fail-9).
  NO second gesture system: DOWN arms pending only in the generic
  tail of `handle_motion` (after all modal/specialized early-returns,
  so text field/slider/date/time/select/combo/menu/sheet/snack/popup
  never arm it); MOVE > 8 dp cancels; UP before fire cancels and
  the tap proceeds; fire clears `g_aui_pressing`/`g_aui_press_key`
  (generic tap dispatch requires `down != 0`, so no tap is issued)
  and the UP handler's fired-held branch returns early (mirroring
  the tooltip-held branch); new DOWN / CANCEL / BACK UP all call
  `lp_cancel()`. A node with both a tooltip and a long-press fires
  both at 500 ms; the tooltip-held UP branch also calls `lp_cancel()`
  so no fired state lingers.
- Debug getters (tests declare their own externs, tooltip_test
  pattern): `aui_debug_long_press_state()` (0 idle / 1 pending /
  2 fired-held), `aui_debug_long_press_n()`,
  `aui_debug_long_press_key()`, `aui_debug_long_press_at(px, py)`
  (1 = the point is still within the 8 dp slop of the DOWN point).
- Gallery demo (`examples/ui_gallery.ast`, Scroll tab): every list
  row (key 1320+i) gets `aui_long_press(on_row_lp, user)`; the
  callback records `aui_long_press_key() - 1320` in `s.lp_row` and
  shows Toast "已长按列表项" (2000 ms); a new "Long press" info row
  shows the last long-pressed index (-1 = none).
- Test (`tests/longpress_test.ast`, headless, virtual clock,
  tooltip_test pattern; frozen baseline
  `tests/baseline/longpress.pixels`, `LONGPRESSHASH frame
  -365741264238267276`, twice in one run, twice across runs,
  byte-identical): fires at 500 ms (300 ms still pending), early UP
  doesn't fire + tap proceeds, move > 8 dp cancels, scroll drag
  cancels, no tap after fire, repeat long-press fires once each
  time, BACK cancels pending, pressing the row's label fires the
  row's callback (ancestor walk). Return codes in the file header.
- Tap-slop fix found by the test (NOT a long-press bug, but the
  same tap arbitration long-press reuses): a finger moving > 8 dp
  on a NON-scrollable control still counted as a tap — only the
  scroll-drag branch (`g_aui_drag_key != 0`) cancelled pressing on
  MOVE. The probe proved it (`C up clicks=2` after a 20 px move).
  Fix: the generic DOWN tail records the DOWN point
  (`g_aui_press_downx/downy`); the generic MOVE tail cancels the
  press (`pressing=0`, `dragging=1`, so the UP dispatch's
  `was_drag == 0` check skips it) when the finger moves > 8 dp
  with no scroll/pager drag active. `dragging` is reset at the
  start of the UP handler, so nothing leaks. Section C of the
  test now also asserts the tap is cancelled by the move (rc 144).
  Text-field/combo/select keep their own slop handling (untouched).

### Scroll jank (user device feedback 2026-11-15 10:55: "上下滚动明显卡顿")

- Probe first (`tests/scroll_cost_harness.ast`, fake-window harness,
  ScrollView scene 0 + vlist scene 1, 6x30 px drags at 16 ms cadence):
  per MOVE step build Δ=0, paint Δ=1, cmds/nodes constant — no
  per-frame rebuild/remeasure. Two root causes instead:
  1. The blit never engaged (`fb_cmds_ok` fail 13, `why=5` — "no
     covering command before the viewport"): a header text box
     grazes the viewport top by 6 px (`emit_text_lines` centres the
     48 px glyph box in the 60 px line, so the command box ends 6 px
     past the node bottom; the ink itself ends exactly at the node
     bottom). `cmd_covers` needs an op-1 rect; a text command can
     never cover, so the backward scan stopped there and never
     reached the fullscreen bg rects. Fix: `cmd_hits_ink` tests the
     text command's ink box (bottom trimmed by the 6 px
     line-height/glyph-height gap); a hitting text command whose ink
     does NOT reach the viewport is skipped and scanning continues.
     The bottom 6 px of a standard text box are always ink-free, and
     `fb_do_blit`'s top-4px replay covers 1 px rounding error.
     After the fix, steps 3-7 in both scenes blit (`fail=0`).
  2. The 32-entry glyph cache thrashed on every screen (probe scene
     62 distinct glyphs, Gallery Fonts tab ~90, list tab ~35):
     every frame missed on ~every glyph, so each `fb_replay`
     re-rasterized all outlines (probe time rose 8.6 s -> 14.1 s
     with blit-only). Fix: cache 32 -> 128 entries
     (`src/render/truetype.ast`, 6 arrays + pool 128 KB -> 512 KB,
     BSS +384 KB; untouched slots are zero pages, no RAM cost).
     After both fixes: every move step and fling frame `miss=0
     evict=0 live=63`, blit on steps 3-7 and all 6 fling frames,
     `PIXELCHECK eq=1` in both scenes (blit frame pixel-identical
     to a forced full repaint — no smearing from the skipped text
     command), total probe time ~3.1-3.3 s (was 8.6-9.1 s).
- New debug helpers (same pattern as `aui_debug_blit_diag`):
  `aui_debug_tt_cache(out)` ([hits, misses, evictions, live,
  raster_ms, raster_n]), `aui_debug_cmds_why(out)` (failure stage
  0-5 + cmd/word indices), `aui_debug_cmd_at(idx, out)` (op, x, y,
  w, h, radius, color, tlen in px).
- Test (`tests/scroll_cost_harness.ast`, asserting): per step build
  Δ==0 (rc 33), paint Δ==1 drag / ≤1 fling (rc 34), glyph
  miss/evict Δ==0 (rc 32), drag steps k≥2 all blit (≥5/6, rc 30;
  step 1 is the by-design `force_full` frame), fling frames ≥4/6
  blit (rc 31), UP paints once + at most one extra frame moving
  forward (rc 3/4), `PIXELCHECK eq==1` (rc 2). Frozen baseline
  `tests/baseline/scroll_cost.pixels`: `SCROLLHASH s=0 1773845912`,
  `s=1 -1823807559`.
- v2.6.2 observation (a) NOT reproduced for a drag UP: `TAPPAINT
  up_paint=1, extra_frame=0` before the fling-timing fix, and
  `up_paint=1, extra_frame=1 off=180->204` after it (the extra
  frame is the fling's first frame, not a double paint). The
  tab-switch double paint itself is a different path, still open.
  Observation (b) (frame_at re-raster from saved commands) still
  open.
- Device confirmation of smoothness comes from the user after
  delivery; headless numbers are reference only.

### Suite registration (v2.7)

- `tests/ui-checks.sh`: [24/27] gains explicit `nb_run` lines for
  `longpress_test` + `scroll_cost_harness` (self-contained, same
  pattern as tooltip_test/canvas_harness, NOT in the MAP);
  [26/27] link gate 43 -> 45 links (canvas_test 43rd,
  longpress_test 44th, scroll_cost_harness 45th); [27/27] version
  codes Counter 18:2.7 / Gallery 17:2.7.
- Verification (logs `~/workspace/canvas/ui-checks-*-longpress.log`):
  standalone aster-fixed SUITE_EXIT=0, 7 PASS lines (6/6 new-base +
  summary), [26/27] 45/45 link + 45/45 run (log
  `ui-checks-fixed-longpress.log`, re-run after the [27/27]
  version-code bump). Mounted aster-fixed SUITE_EXIT=0, 28 PASS
  lines (21/21 old + 6/6 new-base), [26/27] 45/45 link + 45/45 run
  (log `ui-checks-fixed-longpress-mount.log`; one early mounted
  attempt ran the stale ceebcad checkout and was killed — the EXIT
  trap did not restore the hidden old binary on SIGTERM, restored
  by hand, md5s re-verified). Old binary: standalone EXIT=1, 1 PASS
  line ([22/27] compile gate only — standalone has no old tree),
  mounted EXIT=1, 22 PASS lines, both stop at [23/27] with the
  recorded H-3/C-1 error (logs `ui-checks-real-longpress.log`,
  `ui-checks-real-longpress-mount.log`). No timeout-20 failure in
  any run; the repo script's `timeout 20` was not touched.
- APKs v2.7 (Counter code 18, Gallery code 17): rebuilt from the
  new repo (`~/workspace/canvas/apk-v27/`), verify-apk OK, no font
  files, no dex, 16K LOAD align. .so files DIFFER from delivered
  v2.6.2 by design (new feature + scroll fixes); `git diff` shows
  the only framework changes are the long-press + scroll pieces
  above (+ the tap-slop fix). Delivered to
  `~/workspace/your_files/asterui-counter/counter.apk` and
  `~/workspace/your_files/asterui-gallery/gallery.apk` (old build
  must be uninstalled first).

## v2.7.1-diag — 诊断构建（v2.7 两项真机失败，用户 2026-11-15 12:01 反馈）

- 现象（真机 Android 16，1216x2688）：Gallery 列表行长按完全不
  触发；上下滚动还是不顺畅。headless 全绿（挂载 28 PASS，
  [26/27] 45/45），所以本轮不凭 headless 猜修：先加诊断日志，
  让用户测出日志再定根因。
- 代码已核实的疑点（待真机日志确认）：`pump_frame_once()` 只调
  `tip_tick()`/`present_tick()`，从不调 `lp_tick()`；两处
  pump_need 保活检查都只看 `tip_busy()/present_busy()/
  ripple_busy()`，没有 `lp_busy()`。headless 测试经
  `aui_headless_render` -> `pump_ui()` -> `lp_tick()` 驱动，
  所以 headless 全绿、真机静按时泵一空闲就再也不调 `lp_tick`。
  滚动则待查：blit 是否只在 headless 生效、后端现帧是否全量重画。
- 诊断日志（`src/aui_impl.ast`，level 4，`[ms] I AUI: ` 前缀）：
  `lp down key=<k> lk=<idx> tip=<0/1>`（每按一次；key=-1 表未命
  中长按节点）、`lp fire key=<k> el=<ms> ticks=<n>`、
  `lp cancel why=<1 新按下/2 返回键/3 提示认领抬起/4 系统取消/
  5 移动超 slop/6 提前抬起> el=<ms> ticks=<n>`、
  `lp pump idle el=<ms> ticks=<n>`（泵回空闲而长按仍待定，每按
  一次只记一次）、`lp up fired key=<k>`、`tip show el=<ms>`
  （工具提示对照：同走 500ms 泵机制）、`scroll frame w=<锁等待
  ms> c=<光栅ms> t=<提交ms> bl=<直搬计划> blit=<实际直搬>
  same=<帧缓冲匹配> miss=<字形缓存累计> evict=<累计> off=<滚动
  偏移px> mv=<自上帧 MOVE 数>`（只在拖动/惯性滚动进行时每帧一
  行）。另新增 `aui_log3`（三值日志）与诊断计数
  `g_aui_lp_diag_ticks`/`g_aui_lp_diag_idle`/
  `g_aui_diag_moves`（只写日志，不参与判定）；`lp_cancel()`
  改为 `lp_cancel_why(why)` +  wrapper，行为不变。
- 读日志判定：`lp down` 后出现 `lp pump idle` 且 `ticks=0`、
  再 `lp cancel why=6` ——泵没调过 `lp_tick`（根因锁定）；
  `ticks` 接近按住毫秒/16 且无 fire——时钟或判定逻辑问题；
  无 `lp down` 行——按下没进通用尾部；`tip show` 出现而长按
  不触发——泵本身正常，问题只在长按路径。滚动：`blit=1` 且
  `c` 小——直搬在工作，卡在别处；`blit=0` 且 `same=1`——直搬
  计划在真机上失败；`same=0`——窗口缓冲不匹配致全重画；
  `c` 大——光栅本身慢；`w` 大——等窗口缓冲；`mv` 持续 >2——
  帧泵跟不上输入速率。
- 版本：v2.7.1-diag（Counter code 19，Gallery code 18；正式
  v2.7.1 沿用这两个 code）。Counter 标题改为
  "v2.7.1-diag 中文界面" 以便肉眼确认装的是诊断包；Gallery
  无应用内版本字样，以 APK versionName 为准。诊断包交付后，
  `~/workspace/your_files/` 里的 v2.7 原包留存在
  `~/workspace/canvas/apk-v27/`。
