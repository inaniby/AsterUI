#!/bin/sh
# run_qemu.sh — 在 x86_64 主机上用 qemu-user 跑 AsterUI 的 AArch64 冒烟测试。
#
#   ASTER=/path/to/aster tests/run_qemu.sh
#
# 需要 qemu-aarch64（Debian/Ubuntu: apt-get install qemu-user）。
set -e

ASTER=${ASTER:-/data/aster/build/aster}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build

if ! command -v qemu-aarch64 >/dev/null 2>&1; then
    echo "缺少 qemu-aarch64；请先安装 qemu-user" >&2
    exit 1
fi

echo "== 编译（非 PIC 静态链接）"
$ASTER build-obj aui_impl.ast -o build/aui_impl_nopic.o
$ASTER build-obj tests/fake_ndk.ast -o build/fake_ndk.o
$ASTER build-obj tests/android_stubs.ast -o build/android_stubs.o
$ASTER build-obj tests/headless_test.ast -o build/headless_test.o
$ASTER build-obj tests/scroll_test.ast -o build/scroll_test.o
$ASTER build-obj tests/fling_test.ast -o build/fling_test.o
$ASTER build-obj tests/anim_test.ast -o build/anim_test.o
$ASTER build-obj tests/android_harness.ast -o build/android_harness.o
$ASTER build-obj tests/list_harness.ast -o build/list_harness.o
$ASTER build-obj tests/text_test.ast -o build/text_test.o
$ASTER build-obj tests/form_harness.ast -o build/form_harness.o
$ASTER build-obj tests/nav_test.ast -o build/nav_test.o
$ASTER build-obj tests/nav_harness.ast -o build/nav_harness.o
$ASTER build-obj tests/nav_transition_test.ast -o build/nav_transition_test.o
$ASTER build-obj tests/nav_transition_harness.ast -o build/nav_transition_harness.o
$ASTER build-obj tests/nav_watchdog_test.ast -o build/nav_watchdog_test.o
$ASTER build-obj tests/system_test.ast -o build/system_test.o
$ASTER build-obj tests/system_harness.ast -o build/system_harness.o
$ASTER build-obj tests/anim_harness.ast -o build/anim_harness.o
$ASTER build-obj tests/png_test.ast -o build/png_test.o
$ASTER build-obj tests/cjk_test.ast -o build/cjk_test.o
$ASTER build-obj tests/controls_test.ast -o build/controls_test.o
$ASTER build-obj tests/font24_test.ast -o build/font24_test.o
$ASTER build-obj tests/font48_test.ast -o build/font48_test.o
$ASTER build-obj tests/select_test.ast -o build/select_test.o
$ASTER build-obj tests/segmented_test.ast -o build/segmented_test.o
$ASTER build-obj tests/tabs_test.ast -o build/tabs_test.o
$ASTER build-obj tests/pager_test.ast -o build/pager_test.o
$ASTER build-obj tests/pager_harness.ast -o build/pager_harness.o
$ASTER build-obj tests/dialog_test.ast -o build/dialog_test.o
$ASTER build-obj tests/dialog_harness.ast -o build/dialog_harness.o
$ASTER build-obj tests/dropdown_test.ast -o build/dropdown_test.o
$ASTER build-obj tests/select_harness.ast -o build/select_harness.o
$ASTER build-obj tests/tooltip_test.ast -o build/tooltip_test.o
$ASTER build-obj tests/tooltip_harness.ast -o build/tooltip_harness.o
$ASTER build-obj tests/date_picker_test.ast -o build/date_picker_test.o
$ASTER build-obj tests/date_picker_harness.ast -o build/date_picker_harness.o
$ASTER build-obj tests/time_picker_test.ast -o build/time_picker_test.o
$ASTER build-obj tests/time_harness.ast -o build/time_harness.o
$ASTER build-obj tests/refresh_test.ast -o build/refresh_test.o
$ASTER build-obj tests/refresh_harness.ast -o build/refresh_harness.o
$ASTER build-obj tests/chip_test.ast -o build/chip_test.o
$ASTER build-obj tests/chip_harness.ast -o build/chip_harness.o
$ASTER build-obj tests/progress_circle_test.ast -o build/progress_circle_test.o
$ASTER build-obj tests/progress_circle_harness.ast -o build/progress_circle_harness.o
$ASTER build-obj tests/shape_aa_test.ast -o build/shape_aa_test.o
$ASTER build-obj tests/tree_test.ast -o build/tree_test.o
$ASTER build-obj tests/tree_harness.ast -o build/tree_harness.o
$ASTER build-obj tests/toast_test.ast -o build/toast_test.o
$ASTER build-obj tests/toast_harness.ast -o build/toast_harness.o
$ASTER build-obj tests/menu_test.ast -o build/menu_test.o
$ASTER build-obj tests/menu_harness.ast -o build/menu_harness.o
$ASTER build-obj tests/icon_test.ast -o build/icon_test.o
$ASTER build-obj tests/icon_harness.ast -o build/icon_harness.o
$ASTER build-obj tests/layout_test.ast -o build/layout_test.o
$ASTER build-obj tests/layout_harness.ast -o build/layout_harness.o
$ASTER build-obj tests/sheet_test.ast -o build/sheet_test.o
$ASTER build-obj tests/sheet_harness.ast -o build/sheet_harness.o
$ASTER build-obj tests/popup_test.ast -o build/popup_test.o
$ASTER build-obj tests/popup_harness.ast -o build/popup_harness.o
$ASTER build-obj tests/top_bar_test.ast -o build/top_bar_test.o
$ASTER build-obj tests/top_bar_harness.ast -o build/top_bar_harness.o
$ASTER build-obj tests/nav_bar_test.ast -o build/nav_bar_test.o
$ASTER build-obj tests/nav_bar_harness.ast -o build/nav_bar_harness.o
$ASTER build-obj tests/nav_pane_test.ast -o build/nav_pane_test.o
$ASTER build-obj tests/nav_pane_harness.ast -o build/nav_pane_harness.o
$ASTER build-obj tests/combo_test.ast -o build/combo_test.o
$ASTER build-obj tests/combo_harness.ast -o build/combo_harness.o
$ASTER build-obj tests/vlist_test.ast -o build/vlist_test.o
$ASTER build-obj tests/vlist_harness.ast -o build/vlist_harness.o
$ASTER build-obj tests/vgrid_test.ast -o build/vgrid_test.o
$ASTER build-obj tests/vgrid_harness.ast -o build/vgrid_harness.o
$ASTER build-obj tests/hlist_test.ast -o build/hlist_test.o
$ASTER build-obj tests/hlist_harness.ast -o build/hlist_harness.o
$ASTER build-obj tests/ripple_test.ast -o build/ripple_test.o
$ASTER build-obj tests/ripple_harness.ast -o build/ripple_harness.o
$ASTER build-obj examples/ui_hello.ast -o build/ui_hello_nopic.o
$ASTER build-obj examples/ui_list.ast -o build/ui_list_nopic.o
$ASTER build-obj examples/ui_form.ast -o build/ui_form_nopic.o
$ASTER build-obj examples/ui_nav.ast -o build/ui_nav_nopic.o
$ASTER build-obj examples/ui_system.ast -o build/ui_system_nopic.o
$ASTER build-obj examples/ui_pager.ast -o build/ui_pager_nopic.o
$ASTER build-obj examples/ui_dialog.ast -o build/ui_dialog_nopic.o
$ASTER build-obj examples/ui_select.ast -o build/ui_select_nopic.o
$ASTER build-obj examples/ui_tooltip.ast -o build/ui_tooltip_nopic.o
$ASTER build-obj examples/ui_date.ast -o build/ui_date_nopic.o
$ASTER build-obj examples/ui_time.ast -o build/ui_time_nopic.o
$ASTER build-obj examples/ui_refresh.ast -o build/ui_refresh_nopic.o
$ASTER build-obj examples/ui_chip.ast -o build/ui_chip_nopic.o
$ASTER build-obj examples/ui_progress_circle.ast -o build/ui_progress_circle_nopic.o
$ASTER build-obj examples/ui_tree.ast -o build/ui_tree_nopic.o
$ASTER build-obj examples/ui_toast.ast -o build/ui_toast_nopic.o
$ASTER build-obj examples/ui_menu.ast -o build/ui_menu_nopic.o
$ASTER build-obj examples/ui_icon.ast -o build/ui_icon_nopic.o
$ASTER build-obj examples/ui_layout.ast -o build/ui_layout_nopic.o
$ASTER build-obj examples/ui_sheet.ast -o build/ui_sheet_nopic.o
$ASTER build-obj examples/ui_popup.ast -o build/ui_popup_nopic.o
$ASTER build-obj examples/ui_top_bar.ast -o build/ui_top_bar_nopic.o
$ASTER build-obj examples/ui_nav_bar.ast -o build/ui_nav_bar_nopic.o
$ASTER build-obj examples/ui_nav_pane.ast -o build/ui_nav_pane_nopic.o
$ASTER build-obj examples/ui_combo.ast -o build/ui_combo_nopic.o
$ASTER build-obj examples/ui_vlist.ast -o build/ui_vlist_nopic.o
$ASTER build-obj examples/ui_vgrid.ast -o build/ui_vgrid_nopic.o
$ASTER build-obj examples/ui_hlist.ast -o build/ui_hlist_nopic.o
$ASTER build-obj examples/ui_ripple.ast -o build/ui_ripple_nopic.o

echo "== 链接"
$ASTER link-obj build/headless_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/headless_test
$ASTER link-obj build/scroll_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/scroll_test
$ASTER link-obj build/fling_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/fling_test
$ASTER link-obj build/anim_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/anim_test
$ASTER link-obj build/android_harness.o build/ui_hello_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/android_harness
$ASTER link-obj build/list_harness.o build/ui_list_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/list_harness
$ASTER link-obj build/text_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/text_test
$ASTER link-obj build/form_harness.o build/ui_form_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/form_harness
$ASTER link-obj build/nav_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/nav_test
$ASTER link-obj build/nav_harness.o build/ui_nav_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/nav_harness
$ASTER link-obj build/nav_transition_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/nav_transition_test
$ASTER link-obj build/nav_transition_harness.o build/ui_nav_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/nav_transition_harness
$ASTER link-obj build/nav_watchdog_test.o build/ui_nav_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/nav_watchdog_test
$ASTER link-obj build/system_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/system_test
$ASTER link-obj build/system_harness.o build/ui_system_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/system_harness
$ASTER link-obj build/anim_harness.o build/ui_anim_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/anim_harness
$ASTER link-obj build/png_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/png_test
$ASTER link-obj build/cjk_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/cjk_test
$ASTER link-obj build/controls_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/controls_test
$ASTER link-obj build/font24_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/font24_test
$ASTER link-obj build/font48_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/font48_test
$ASTER link-obj build/select_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/select_test
$ASTER link-obj build/segmented_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/segmented_test
$ASTER link-obj build/tabs_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/tabs_test
$ASTER link-obj build/pager_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/pager_test
$ASTER link-obj build/pager_harness.o build/ui_pager_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/pager_harness
$ASTER link-obj build/dialog_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/dialog_test
$ASTER link-obj build/dialog_harness.o build/ui_dialog_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/dialog_harness
$ASTER link-obj build/dropdown_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/dropdown_test
$ASTER link-obj build/select_harness.o build/ui_select_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/select_harness
$ASTER link-obj build/tooltip_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/tooltip_test
$ASTER link-obj build/tooltip_harness.o build/ui_tooltip_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/tooltip_harness
$ASTER link-obj build/date_picker_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/date_picker_test
$ASTER link-obj build/date_picker_harness.o build/ui_date_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/date_picker_harness
$ASTER link-obj build/time_picker_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/time_picker_test
$ASTER link-obj build/time_harness.o build/ui_time_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/time_harness
$ASTER link-obj build/refresh_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/refresh_test
$ASTER link-obj build/refresh_harness.o build/ui_refresh_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/refresh_harness
$ASTER link-obj build/chip_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/chip_test
$ASTER link-obj build/chip_harness.o build/ui_chip_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/chip_harness
$ASTER link-obj build/progress_circle_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/progress_circle_test
$ASTER link-obj build/progress_circle_harness.o build/ui_progress_circle_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/progress_circle_harness
$ASTER link-obj build/shape_aa_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/shape_aa_test
$ASTER link-obj build/tree_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/tree_test
$ASTER link-obj build/tree_harness.o build/ui_tree_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/tree_harness
$ASTER link-obj build/toast_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/toast_test
$ASTER link-obj build/toast_harness.o build/ui_toast_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/toast_harness
$ASTER link-obj build/menu_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/menu_test
$ASTER link-obj build/menu_harness.o build/ui_menu_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/menu_harness
$ASTER link-obj build/icon_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/icon_test
$ASTER link-obj build/icon_harness.o build/ui_icon_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/icon_harness
$ASTER link-obj build/layout_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/layout_test
$ASTER link-obj build/layout_harness.o build/ui_layout_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/layout_harness
$ASTER link-obj build/sheet_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/sheet_test
$ASTER link-obj build/sheet_harness.o build/ui_sheet_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/sheet_harness
$ASTER link-obj build/popup_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/popup_test
$ASTER link-obj build/popup_harness.o build/ui_popup_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/popup_harness
$ASTER link-obj build/top_bar_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/top_bar_test
$ASTER link-obj build/top_bar_harness.o build/ui_top_bar_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/top_bar_harness
$ASTER link-obj build/nav_bar_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/nav_bar_test
$ASTER link-obj build/nav_bar_harness.o build/ui_nav_bar_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/nav_bar_harness
$ASTER link-obj build/nav_pane_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/nav_pane_test
$ASTER link-obj build/nav_pane_harness.o build/ui_nav_pane_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/nav_pane_harness
$ASTER link-obj build/combo_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/combo_test
$ASTER link-obj build/combo_harness.o build/ui_combo_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/combo_harness
$ASTER link-obj build/vlist_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/vlist_test
$ASTER link-obj build/vlist_harness.o build/ui_vlist_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/vlist_harness
$ASTER link-obj build/vgrid_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/vgrid_test
$ASTER link-obj build/vgrid_harness.o build/ui_vgrid_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/vgrid_harness
$ASTER link-obj build/hlist_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/hlist_test
$ASTER link-obj build/hlist_harness.o build/ui_hlist_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/hlist_harness
$ASTER link-obj build/ripple_test.o build/aui_impl_nopic.o build/fake_ndk.o \
    -o build/ripple_test
$ASTER link-obj build/ripple_harness.o build/ui_ripple_nopic.o \
    build/aui_impl_nopic.o build/fake_ndk.o -o build/ripple_harness

echo "== headless（离屏 320×240，按钮 +1 / 点外 / 移出）"
qemu-aarch64 ./build/headless_test
echo "   exit=0 OK"

echo "== scroll（离屏 200×200：偏移 / clamp / 裁剪 / 滚动后点击）"
qemu-aarch64 ./build/scroll_test
echo "   exit=0 OK"

echo "== fling（离屏 200×200：减速 / 自然停止 / 边界 / 滚动条）"
qemu-aarch64 ./build/fling_test
echo "   exit=0 OK"

echo "== anim（离屏 320×240：alpha 淡入 / TX 位移 / 时间注入 / 64 槽上限）"
qemu-aarch64 ./build/anim_test
echo "   exit=0 OK"

echo "== anim harness（ui_anim，720×1280 假宿主：启动动画 / 中点 / Replay / 前后台）"
qemu-aarch64 ./build/anim_harness
echo "   exit=0 OK"

echo "== probe1 轨迹（裸 NativeActivity，A/K 落盘）"
$ASTER build-obj examples/probe1_red.ast -o build/probe1_static.o
$ASTER build-obj tests/probe1_harness.ast -o build/probe1_harness.o
$ASTER link-obj build/probe1_harness.o build/probe1_static.o build/android_stubs.o \
    -o build/probe1_harness
rm -rf /tmp/asterui-p1
mkdir -p /tmp/asterui-p1
qemu-aarch64 ./build/probe1_harness
echo "   exit=0 OK"
echo "   p1.txt:"
sed 's/^/     /' /tmp/asterui-p1/p1.txt

echo "== android harness（ui_hello，720×1280 假宿主全回调）"
mkdir -p /tmp/asterui-trace
rm -f /tmp/asterui-trace/trace.txt
qemu-aarch64 ./build/android_harness
echo "   exit=0 OK"

echo "== text（离屏 560×420：字段 / 键盘 / 大小写 / 退格 / 模式 / Done）"
qemu-aarch64 ./build/text_test
echo "   exit=0 OK"

echo "== form harness（ui_form，点字段 -> 键盘 -> 输入 -> BACK 收键盘 -> Done）"
qemu-aarch64 ./build/form_harness
echo "   exit=0 OK"

echo "== nav（离屏 320×480：页面栈 / 上限 / 清焦点）"
qemu-aarch64 ./build/nav_test
echo "   exit=0 OK"

echo "== nav harness（ui_nav，按钮 push/pop + 系统 BACK + 根页面 finish）"
qemu-aarch64 ./build/nav_harness
echo "   exit=0 OK"

echo "== nav transition（离屏 320×480：push/pop/reset 双层快照 / 文字深拷贝 / 容量退化）"
qemu-aarch64 ./build/nav_transition_test
echo "   exit=0 OK"

echo "== nav transition harness（ui_nav，240 ms 转场：输入吞噬 / 自动结束 / push+pop）"
qemu-aarch64 ./build/nav_transition_harness
echo "   exit=0 OK"

echo "== nav watchdog（ui_nav，帧定时器全程不触发：转场到点自动收尾，点击/BACK 不丢）"
qemu-aarch64 ./build/nav_watchdog_test
echo "   exit=0 OK"


echo "== png（stored/fixed/dynamic、0~4 过滤器、tRNS、多 IDAT、池、拒绝路径）"
qemu-aarch64 ./build/png_test
echo "   exit=0 OK"

echo "== cjk（离屏 720×1280：16x16 回退字体 / 混排宽度 / 关掉回退 / UTF-8 编辑）"
qemu-aarch64 ./build/cjk_test
echo "   exit=0 OK"

echo "== controls（离屏 320×240：开关开/关/点按 / 进度 50% / 0、1000 夹紧）"
qemu-aarch64 ./build/controls_test
echo "   exit=0 OK"

echo "== font24（离屏 720×1280：24px 拉丁/汉字 / 比例步进 / 3 字节行）"
qemu-aarch64 ./build/font24_test
echo "   exit=0 OK"

echo "== font48（离屏 720×1280：48px 原生 / 1 倍绘制 / 5 字节行 / 行字节序）"
qemu-aarch64 ./build/font48_test
echo "   exit=0 OK"

echo "== select（离屏 320×240：复选/单选/滑块 / 吸附 / 拖动实时值）"
qemu-aarch64 ./build/select_test
echo "   exit=0 OK"

echo "== segmented（离屏 320×240：等宽分段 / 胶囊内缩 / 按下态 / 下标回读）"
qemu-aarch64 ./build/segmented_test
echo "   exit=0 OK"

echo "== tabs（离屏 320×240：固有宽度 / 2dp 指示条 / 选中文字 / 下标回读）"
qemu-aarch64 ./build/tabs_test
echo "   exit=0 OK"

echo "== pager（离屏 320×240：拖动/吸附/回调/轴锁/裁剪/邻页不误触）"
qemu-aarch64 ./build/pager_test
echo "   exit=0 OK"

echo "== pager harness（ui_pager，720×1280 假宿主：左滑翻页 / Tab 吸附 / 版本号）"
qemu-aarch64 ./build/pager_harness
echo "   exit=0 OK"

echo "== dialog（离屏 320×240：遮罩/卡片几何 / 遮罩关闭 / 卡片空白 / BACK 原因）"
qemu-aarch64 ./build/dialog_test
echo "   exit=0 OK"

echo "== dialog harness（ui_dialog，720×1280 假宿主：打开 / 遮罩 / BACK / Cancel）"
qemu-aarch64 ./build/dialog_harness
echo "   exit=0 OK"

echo "== dropdown（离屏 320×240：触发器几何 / 浮层锚定 / 选项回调 / 外部与 BACK 关闭）"
qemu-aarch64 ./build/dropdown_test
echo "   exit=0 OK"

echo "== select harness（ui_select，720×1280 假宿主：展开 / 选中 / 外部 / BACK / 深色 / 上翻）"
qemu-aarch64 ./build/select_harness
echo "   exit=0 OK"

echo "== tooltip（离屏 320×240：500 ms 长按 / 按住持有 / 停留 / 取消 / 四方向 / 翻边 / BACK）"
qemu-aarch64 ./build/tooltip_test
echo "   exit=0 OK"

echo "== tooltip harness（ui_tooltip，720×1280 假宿主：长按显示 / 不点击 / 停留 / 容器 / BACK）"
qemu-aarch64 ./build/tooltip_harness
echo "   exit=0 OK"

echo "== date（离屏 360×700：归一化 / 网格 / 翻月 / 年页 / 范围 / 周一 / 双卡 / 拖动）"
qemu-aarch64 ./build/date_picker_test
echo "   exit=0 OK"

echo "== date harness（ui_date，720×1280 假宿主：翻月 / 年页 / 选日 / 回显 / 深色）"
qemu-aarch64 ./build/date_picker_harness
echo "   exit=0 OK"

echo "== time（离屏 360×700：字段切换 / 分钟拖动 / 24h 内外圈 / 12h AM/PM / 步长 / 双卡 / 深色）"
qemu-aarch64 ./build/time_picker_test
echo "   exit=0 OK"

echo "== time harness（ui_time，720×1280 假宿主：选分 / 拖动 / 选时进分 / 12h / 步长 / 深色）"
qemu-aarch64 ./build/time_harness
echo "   exit=0 OK"

echo "== refresh（离屏 360×700：阻尼 / 阈值 / 52 dp / 反馈窗口 / 应用 refreshing / 滚动）"
qemu-aarch64 ./build/refresh_test
echo "   exit=0 OK"

echo "== refresh harness（ui_refresh，720×1280 假宿主：下拉 / 回调 / 52 dp / 滚动 / 深色）"
qemu-aarch64 ./build/refresh_harness
echo "   exit=0 OK"

echo "== chip（离屏 320×240：固有尺寸 / 选中主色 / 24% 描边 / 按下态 / 深色）"
qemu-aarch64 ./build/chip_test
echo "   exit=0 OK"

echo "== chip harness（ui_chip，720×1280 假宿主：单选切换 / 多选位 / 列内不拉伸 / 深色）"
qemu-aarch64 ./build/chip_harness
echo "   exit=0 OK"

echo "== progress circle（离屏 320×240：确定弧 / 0-100% / 28% 旋转 / 默认 24 dp / 深色）"
qemu-aarch64 ./build/progress_circle_test
echo "   exit=0 OK"

echo "== progress circle harness（ui_progress_circle，720×1280 假宿主：并排 / 受控 +25% / 旋转 / 默认尺寸 / 深色）"
qemu-aarch64 ./build/progress_circle_harness
echo "   exit=0 OK"

echo "== shape_aa（离屏 320×240：圆角/圆/胶囊/描边/2dp 指示条的覆盖率过渡）"
qemu-aarch64 ./build/shape_aa_test
echo "   exit=0 OK"

echo "== tree（离屏 320×240：缩进 / 选中底色 / 三角 / 点按 / 滚动 / 禁用 / 版本）"
qemu-aarch64 ./build/tree_test
echo "   exit=0 OK"

echo "== tree harness（ui_tree，720×1280 假宿主：展开/收起 / 滚动 / 深色）"
qemu-aarch64 ./build/tree_harness
echo "   exit=0 OK"

echo "== toast（离屏 320×240：底部居中 / 堆叠 / 穿透 / 到期 / SnackBar 动作与暂停）"
qemu-aarch64 ./build/toast_test
echo "   exit=0 OK"

echo "== toast harness（ui_toast，720×1280 假宿主：穿透 / 堆叠 / UNDO / 到期 / 深色）"
qemu-aarch64 ./build/toast_harness
echo "   exit=0 OK"

echo "== menu（离屏 320×240：锚定/翻边/夹紧 / 条目/勾选/禁用 / 选择顺序 / 外部/BACK / 滚动 / 屏幕点）"
qemu-aarch64 ./build/menu_test
echo "   exit=0 OK"

echo "== menu harness（ui_menu，720×1280 假宿主：锚定 / 勾选 / 选择 / 禁用 / 外部 / BACK / 屏幕点 / 滚动 / 深色）"
qemu-aarch64 ./build/menu_harness
echo "   exit=0 OK"

echo "== icon（离屏 320×240：40 dp 方块 / 22 个图形 / 禁用 / 按下 / 尺寸 / 深色）"
qemu-aarch64 ./build/icon_test
echo "   exit=0 OK"

echo "== icon harness（ui_icon，720×1280 假宿主：工具条 / 点击 / 禁用 / 尺寸行 / 滚动 / 深色）"
qemu-aarch64 ./build/icon_harness
echo "   exit=0 OK"

echo "== layout（离屏 320×320：Flow 换行 / 居中 / space-between / 权重 / 分隔线 / 深色）"
qemu-aarch64 ./build/layout_test
echo "   exit=0 OK"

echo "== layout harness（ui_layout，720×1280 假宿主：标签片换行 / 对齐模式 / 分隔线 / 深色）"
qemu-aarch64 ./build/layout_harness
echo "   exit=0 OK"

echo "== sheet（离屏 320×320：贴底 / 遮罩 / 圆角 / 拖拽吸附与关闭 / 遮罩/BACK / 手柄 / 深色）"
qemu-aarch64 ./build/sheet_test
echo "   exit=0 OK"

echo "== sheet harness（ui_sheet，720×1280 假宿主：滑入 / 滑块 / Confirm / 下拉 / 遮罩 / BACK / 手柄 / 深色）"
qemu-aarch64 ./build/sheet_harness
echo "   exit=0 OK"

echo "== popup（离屏 320×320：锚定/翻边/夹取 / 四方向 / 居中末尾 / 外部/BACK/dismiss / 互斥 / 深色）"
qemu-aarch64 ./build/popup_test
echo "   exit=0 OK"

echo "== popup harness（ui_popup，720×1280 假宿主：打开 / 滑块 / Apply / 外部 / BACK / 方向 / 对齐 / 深色）"
qemu-aarch64 ./build/popup_harness
echo "   exit=0 OK"

echo "== top bar（离屏 320×320：高度/内边距 / leading/动作 / 标题区间 / 居中 / 提示线 / 撑高 / 深色）"
qemu-aarch64 ./build/top_bar_test
echo "   exit=0 OK"

echo "== top bar harness（ui_top_bar，720×1280 假宿主：leading / 动作 / 居中 / 提示线 / 长标题 / 深色）"
qemu-aarch64 ./build/top_bar_harness
echo "   exit=0 OK"

echo "== nav bar（离屏 320×320：等宽项 / 指示胶囊 / 选中回读 / 已选不回调 / 禁用 / 隐藏文字 / 越界 / 单项 / 缩进 / 深色）"
qemu-aarch64 ./build/nav_bar_test
echo "   exit=0 OK"

echo "== nav bar harness（ui_nav_bar，720×1280 假宿主：贴底 64 dp / 等宽 / 选中切换 / 隐藏文字 / 禁用 / 深色）"
qemu-aarch64 ./build/nav_bar_harness
echo "   exit=0 OK"

echo "== nav pane（离屏 320×320：收缩 72 dp / 展开 256 dp / 胶囊 / 选中回读 / 已选不回调 / 禁用 / 越界 / 缩进 / 文字裁剪 / 深色）"
qemu-aarch64 ./build/nav_pane_test
echo "   exit=0 OK"

echo "== nav pane harness（ui_nav_pane，720×1280 假宿主：收缩 189 px / 展开 672 px / 选中切换 / 禁用 / 文字 / 深色）"
qemu-aarch64 ./build/nav_pane_harness
echo "   exit=0 OK"

echo "== combo（离屏 320×320：触发器/浮层/建议几何 / 点按展开 / 前缀过滤 / 选择回读 / 外部与 BACK / 深色）"
qemu-aarch64 ./build/combo_test
echo "   exit=0 OK"

echo "== combo harness（ui_combo，720×1280 假宿主：展开 / 键盘输入过滤 / BACK / 选建议 / 外部 / Clear / 深色）"
qemu-aarch64 ./build/combo_harness
echo "   exit=0 OK"

echo "== vlist（离屏 320×240：窗口 0..8 / 1000 行 / 选中回读 / 滚动到 320 / 滚动条 / 惯性跟随）"
qemu-aarch64 ./build/vlist_test
echo "   exit=0 OK"

echo "== vlist harness（ui_vlist，720×1280 假宿主：5000 行 / 168 px 行高 / 点行 / 中段滚动 / 滚到底 / 深色）"
qemu-aarch64 ./build/vlist_harness
echo "   exit=0 OK"

echo "== vgrid（离屏 320×240：4 列 / 窗口 0..27 / 点格回读 / 滚动到 480 / 滚到底 / 惯性 / 自适应 3 列）"
qemu-aarch64 ./build/vgrid_test
echo "   exit=0 OK"

echo "== vgrid harness（ui_vgrid，720×1280 假宿主：3 列 / 315 px 行高 / 点格 / 中段滚动 / 滚到底 / 深色）"
qemu-aarch64 ./build/vgrid_harness
echo "   exit=0 OK"

echo "== hlist（离屏 320×240：1000 项 / 窗口 0..5 / 点项回读 / 滚动到 480 / 滚到底 / 惯性 / 固定项高 48 + 间距 8）"
qemu-aarch64 ./build/hlist_test
echo "   exit=0 OK"

echo "== hlist harness（ui_hlist，720×1280 假宿主：420 px 项宽 / 21 px 间距 / 点项 / 中段滚动 / 滚到底 / 深色）"
qemu-aarch64 ./build/hlist_harness
echo "   exit=0 OK"

echo "== ripple（离屏 320×240：默认关闭 / 按住扩散 / 只画按下行 / 淡出 / 关闭清除 / 按钮 key）"
qemu-aarch64 ./build/ripple_test
echo "   exit=0 OK"

echo "== ripple harness（ui_ripple，720×1280 假宿主：按住行 / 半径增长 / 淡出恢复 / 按钮 key / Toggle 关闭）"
qemu-aarch64 ./build/ripple_harness
echo "   exit=0 OK"

echo "== system（离屏 720×1280：内容区 / 安全区 / 深色主题）"
qemu-aarch64 ./build/system_test
echo "   exit=0 OK"

echo "== system harness（ui_system，旋转 / 内容区 / 配置变化 / 深色切换）"
qemu-aarch64 ./build/system_harness
echo "   exit=0 OK"

echo "== list harness（ui_list，按实际矩形拖动 + 滚动后点按钮）"
qemu-aarch64 ./build/list_harness
echo "   exit=0 OK"

echo "   trace.txt 摘要:"
grep -E '^[ANLPFRvgh]' /tmp/asterui-trace/trace.txt | tail -20 | sed 's/^/     /'
