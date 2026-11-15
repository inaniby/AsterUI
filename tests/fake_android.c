// fake_android.c -- minimal fake libandroid for the bridge harness.
// Only the two motion getters; each returns the C float stored in the
// fake event, exactly as the real NDK does (float in s0 on AArch64).
// The .so under test links against this as libfakeandroid.so.
typedef struct { float x; float y; } FakeEvent;

float AMotionEvent_getX(void *event, int pointerIndex) {
    (void)pointerIndex;
    return ((FakeEvent *)event)->x;
}

float AMotionEvent_getY(void *event, int pointerIndex) {
    (void)pointerIndex;
    return ((FakeEvent *)event)->y;
}
