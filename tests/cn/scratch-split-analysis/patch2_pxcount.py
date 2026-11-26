import sys
path = sys.argv[1]
src = open(path).read()
helpers = '''// B23 probe: pixel census. bg = (246,246,248) = 0xF6F6F8 (the
// framework background seen in every RECT centre); zero = untouched
// buffer (RGBA 0,0,0,0); other = anything else (real drawn content).
// kind: 0 = bg, 1 = zero, 2 = other.
fn count_kind(x0: i32, y0: i32, w: i32, h: i32, kind: i32) -> i32 {
    let x1: i32 = x0 + w;
    let y1: i32 = y0 + h;
    if (x0 < 0) { x0 = 0; }
    if (y0 < 0) { y0 = 0; }
    if (x1 > W) { x1 = W; }
    if (y1 > H) { y1 = H; }
    let n: i32 = 0;
    let y: i32 = y0;
    while (y < y1) {
        let x: i32 = x0;
        while (x < x1) {
            let off: i32 = (y * W + x) * 4;
            let r: i32 = load_u8(g_buf + off);
            let g: i32 = load_u8(g_buf + off + 1);
            let b: i32 = load_u8(g_buf + off + 2);
            let a: i32 = load_u8(g_buf + off + 3);
            if (kind == 0) {
                if (r == 246 && g == 246 && b == 248) { n = n + 1; }
            } else if (kind == 1) {
                if (r == 0 && g == 0 && b == 0 && a == 0) { n = n + 1; }
            } else {
                if (!((r == 246 && g == 246 && b == 248) || (r == 0 && g == 0 && b == 0 && a == 0))) { n = n + 1; }
            }
            x = x + 1;
        }
        y = y + 1;
    }
    return n;
}
fn emit_pxcounts_rect(label: ptr, x0: i32, y0: i32, w: i32, h: i32) -> i32 {
    let p1: i32 = out_str(ptr("PXCOUNT "));
    let p2: i32 = out_str(label);
    let p3: i32 = out_sp();
    let p4: i32 = out_i32(count_kind(x0, y0, w, h, 0));
    let p5: i32 = out_sp();
    let p6: i32 = out_i32(count_kind(x0, y0, w, h, 1));
    let p7: i32 = out_sp();
    let p8: i32 = out_i32(count_kind(x0, y0, w, h, 2));
    let p9: i32 = out_nl();
    return 0;
}
fn emit_pxcounts(key: i32) -> i32 {
    if (aui_debug_rect(key, g_rect) != 0) {
        return 1;
    }
    return emit_pxcounts_rect(ptr("key"), g_rect[0], g_rect[1], g_rect[2], g_rect[3]);
}
'''
anchor = "// Input tab snapshot (B23 probe)."
assert anchor in src
src = src.replace(anchor, helpers + anchor, 1)
# keyed census inside emit_input, anchored on its pixelhash + fn main tail
old_tail = """    let z: i32 = emit_pixelhash(name);
    return 0;
}
fn main() -> i32 {"""
new_tail = """    let z: i32 = emit_pixelhash(name);
    let q01: i32 = emit_pxcounts_rect(ptr("whole"), 0, 0, W, H);
    let q02: i32 = emit_pxcounts_rect(ptr("chrome"), 0, 24, W, 124);
    let q03: i32 = emit_pxcounts_rect(ptr("content"), 0, 148, W, H - 148);
    let q04: i32 = emit_pxcounts(101);
    let q05: i32 = emit_pxcounts(110);
    let q06: i32 = emit_pxcounts(115);
    let q07: i32 = emit_pxcounts(143);
    let q08: i32 = emit_pxcounts(160);
    let q09: i32 = emit_pxcounts(170);
    return 0;
}
fn main() -> i32 {"""
assert old_tail in src
src = src.replace(old_tail, new_tail, 1)
# DRAWCALLS for counter0 (n0) and nav_root (n3) for comparison
old_n0 = """    let n0: i32 = aui_headless_render(W, H, g_buf);
    if (n0 <= 0) {
        return 1;
    }
"""
new_n0 = old_n0 + """    let dd1: i32 = out_str(ptr("DRAWCALLS counter0 "));
    let dd2: i32 = out_i32(n0);
    let dd3: i32 = out_nl();
"""
assert old_n0 in src
src = src.replace(old_n0, new_n0, 1)
old_n3 = """    let n3: i32 = aui_headless_render(W, H, g_buf);
    if (n3 <= 0) {
        return 4;
    }
"""
new_n3 = old_n3 + """    let de1: i32 = out_str(ptr("DRAWCALLS nav_root "));
    let de2: i32 = out_i32(n3);
    let de3: i32 = out_nl();
"""
assert old_n3 in src
src = src.replace(old_n3, new_n3, 1)
open(path, "w").write(src)
print("patched2", path)
