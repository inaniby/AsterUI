// fake_android.c -- minimal fake libandroid for the bridge harness.
// Motion getters return the C float stored in the fake event, exactly as
// the real NDK does (float in s0 on AArch64). The .so under test links
// against this as libfakeandroid.so.
// v2.18: two pointer slots + count, so the fake can carry a pinch
// (pointerIndex selects the slot; ids are 0/1).
typedef struct { float x; float y; float x1; float y1; int count; } FakeEvent;

float AMotionEvent_getX(void *event, int pointerIndex) {
    if (pointerIndex == 1) return ((FakeEvent *)event)->x1;
    return ((FakeEvent *)event)->x;
}

float AMotionEvent_getY(void *event, int pointerIndex) {
    if (pointerIndex == 1) return ((FakeEvent *)event)->y1;
    return ((FakeEvent *)event)->y;
}

int AMotionEvent_getPointerCount(void *event) {
    return ((FakeEvent *)event)->count;
}

int AMotionEvent_getPointerId(void *event, int pointerIndex) {
    if (pointerIndex == 1) return 1;
    return 0;
}
