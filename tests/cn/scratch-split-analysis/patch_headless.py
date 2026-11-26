import sys
path, W, H = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
src = open(path).read()
# 1. extern for live text value
src = src.replace(
  "extern fn aui_nav_depth() -> i32;",
  "extern fn aui_nav_depth() -> i32;\nextern fn aui_text_value(key: i32) -> ptr;",
  1)
# 2. viewport + frame buffer
src = src.replace("let W: i32 = 480;", f"let W: i32 = {W};", 1)
src = src.replace("let H: i32 = 880;", f"let H: i32 = {H};", 1)
src = src.replace("let g_buf: i32[422400] = 0;", f"let g_buf: i32[{W*H}] = 0;", 1)
# 3. emit_input before fn main
emit_input = '''// Input tab snapshot (B23 probe). Keys from page_input.ast:
// scroll 1000, column 1001, label 101, text_field 110, label 111,
// row 112, live label 113, row 114, buttons 115/116, label 120,
// select 130, options 131-133, row 140, label 141, switch 143,
// checkbox 150, label 155, slider 160, progress 170.
fn emit_input(name: ptr) -> i32 {
    let h1: i32 = out_str(ptr("SNAPSHOT "));
    let h2: i32 = out_str(name);
    let h3: i32 = out_nl();
    let a: i32 = emit_chrome_rects();
    let b: i32 = emit_rect(1000);
    let c: i32 = emit_rect(1001);
    let d: i32 = emit_rect(101);
    let e: i32 = emit_rect(110);
    let f: i32 = emit_rect(111);
    let g: i32 = emit_rect(112);
    let h: i32 = emit_rect(113);
    let i: i32 = emit_rect(114);
    let j: i32 = emit_rect(115);
    let k: i32 = emit_rect(116);
    let l: i32 = emit_rect(120);
    let m: i32 = emit_rect(130);
    let n: i32 = emit_rect(131);
    let o: i32 = emit_rect(132);
    let p: i32 = emit_rect(133);
    let q: i32 = emit_rect(140);
    let r: i32 = emit_rect(141);
    let s: i32 = emit_rect(143);
    let t: i32 = emit_rect(150);
    let u: i32 = emit_rect(155);
    let v: i32 = emit_rect(160);
    let w: i32 = emit_rect(170);
    let x: i32 = emit_chrome_texts(ptr("AsterUI Gallery"), ptr("Counter"), ptr("Input"), ptr("Nav"));
    let y1: i32 = emit_text(101, ptr("Text field + select"));
    let y2: i32 = emit_text(110, ptr("Tap to type..."));
    let y3: i32 = emit_text(111, ptr("Live value"));
    let y4: i32 = emit_text(113, aui_text_value(110));
    let y5: i32 = emit_text(115, ptr("Clear"));
    let y6: i32 = emit_text(116, ptr("Focus"));
    let y7: i32 = emit_text(120, ptr("Language"));
    let y8: i32 = emit_text(131, ptr("English"));
    let y9: i32 = emit_text(132, ptr("German"));
    let ya: i32 = emit_text(133, ptr("Chinese"));
    let yb: i32 = emit_text(141, ptr("Notify"));
    let yc: i32 = emit_text(150, ptr("Promotions"));
    let yd: i32 = emit_text(155, ptr("Volume"));
    let z: i32 = emit_pixelhash(name);
    return 0;
}
fn main() -> i32 {'''
src = src.replace("fn main() -> i32 {", emit_input, 1)
# 4. call emit_input after the Input-tab render in main (n2 block)
old = """    gallery_set_tab(1);
    let n2: i32 = aui_headless_render(W, H, g_buf);
    if (n2 <= 0) {
        return 5;
    }
"""
new = """    gallery_set_tab(1);
    let n2: i32 = aui_headless_render(W, H, g_buf);
    if (n2 <= 0) {
        return 5;
    }
    let dc1: i32 = out_str(ptr("DRAWCALLS input "));
    let dc2: i32 = out_i32(n2);
    let dc3: i32 = out_nl();
    let e1b: i32 = emit_input(ptr("input"));
"""
assert old in src, "n2 block not found"
src = src.replace(old, new, 1)
open(path, "w").write(src)
print("patched", path, W, H)
