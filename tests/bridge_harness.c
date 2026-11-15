// bridge_harness.c -- W3 bridge-measurement harness (host C, qemu-aarch64).
//
// Usage: bridge_harness <probe.so> <lazy|now>
//   lazy: dlopen(RTLD_LAZY) -- first-ever getX/lrintf calls resolve their
//         PLT slots lazily, the cold condition that failed on device.
//   now:  dlopen(RTLD_NOW) -- eager binding, the closest analogue of the
//         reference build's stated link conditions (explicit libm
//         DT_NEEDED; build.sh sets no BIND_NOW anywhere -- verified by
//         grep -- so RTLD_NOW is the eager analogue, not a documented
//         reference condition).
//
// Each run is a fresh process, so the first coordinate call in the run
// is the cold first-ever call for that binding mode. Six coordinate
// pairs exercise lrintf round-half-to-even (1042.5 -> 1042, 1919.5 ->
// 1920). The harness FAILS (exit 1) only if the kept f32 route is
// wrong: the bridge result is reported, not gated, because this host
// (qemu + glibc) is already known not to discriminate -- M1.2a proved
// the old bridge passes here under both modes while failing on the
// device. A bridge PASS here therefore proves nothing about Android;
// a bridge FAIL here would be new evidence against it.
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef struct { float x; float y; } FakeEvent;
typedef int (*coord_fn)(void *ev);

static const float kXs[6] = {198.25f, 52.6f, 1042.5f, 299.4f, 0.0f, 1216.0f};
static const float kYs[6] = {238.75f, 120.6f, 1919.5f, 399.4f, 0.0f, 2688.0f};
static const int kEx[6] = {198, 53, 1042, 299, 0, 1216};
static const int kEy[6] = {239, 121, 1920, 399, 0, 2688};

int main(int argc, char **argv) {
    if (argc != 3) { fprintf(stderr, "usage: %s <probe.so> <lazy|now>\n", argv[0]); return 2; }
    int mode = RTLD_LAZY;
    if (!strcmp(argv[2], "now")) mode = RTLD_NOW;
    else if (strcmp(argv[2], "lazy") != 0) { fprintf(stderr, "bad mode %s\n", argv[2]); return 2; }

    void *h = dlopen(argv[1], mode);
    if (!h) { fprintf(stderr, "dlopen failed: %s\n", dlerror()); return 2; }
    // POSIX dlsym returns void*; the assignment through void** is the
    // -Wpedantic-clean way to take it as a function pointer.
    coord_fn bx, by, fx, fy;
    *(void **)(&bx) = dlsym(h, "aui_bridge_x");
    *(void **)(&by) = dlsym(h, "aui_bridge_y");
    *(void **)(&fx) = dlsym(h, "aui_f32_x");
    *(void **)(&fy) = dlsym(h, "aui_f32_y");
    if (!bx || !by || !fx || !fy) { fprintf(stderr, "dlsym failed: %s\n", dlerror()); return 2; }

    // Cold first-ever calls: bridge first, then f32, in this process.
    int bridge_bad = 0, f32_bad = 0;
    for (int i = 0; i < 6; i++) {
        FakeEvent ev; ev.x = kXs[i]; ev.y = kYs[i];
        int x = bx(&ev), y = by(&ev);
        int ok = (x == kEx[i] && y == kEy[i]);
        if (!ok) bridge_bad++;
        printf("bridge [%d] in (%.2f, %.2f) got (%d, %d) expect (%d, %d) %s%s\n",
               i, (double)kXs[i], (double)kYs[i], x, y, kEx[i], kEy[i],
               ok ? "ok" : "FAIL", i == 0 ? " [cold first-ever]" : "");
    }
    for (int i = 0; i < 6; i++) {
        FakeEvent ev; ev.x = kXs[i]; ev.y = kYs[i];
        int x = fx(&ev), y = fy(&ev);
        int ok = (x == kEx[i] && y == kEy[i]);
        if (!ok) f32_bad++;
        printf("f32    [%d] in (%.2f, %.2f) got (%d, %d) expect (%d, %d) %s%s\n",
               i, (double)kXs[i], (double)kYs[i], x, y, kEx[i], kEy[i],
               ok ? "ok" : "FAIL", i == 0 ? " [cold first-ever]" : "");
    }
    printf("mode=%s bridge_bad=%d/6 f32_bad=%d/6\n", argv[2], bridge_bad, f32_bad);
    if (f32_bad) { printf("RESULT: FAIL (kept f32 route wrong)\n"); return 1; }
    printf("RESULT: f32 route PASS; bridge %s (informational only -- see header)\n",
           bridge_bad ? "FAIL" : "PASS");
    return 0;
}
