# AsterUI v1.48.6

Aster 的原生 UI 标准库：`NativeActivity` + 自绘软件光栅，**没有 dex / Java / Kotlin**。
设计与取舍见 `docs/AsterUI-design.md`（附录 D 是实现记录与真机闪退修复记录）。

```
stdlib/asterui/aui.ast          公共头：全部 extern（v1.48.6）
stdlib/asterui/aui_impl.ast     v1.48.6 单体实现（系统适配 / 主题 / 键盘 / 页面栈 / 动画 / 页面转场 / PNG 解码 / edge-to-edge 安全区 / 系统栏条带 / CJK 回退字体 / 开关 / 进度条 / 复选 / 单选 / 滑块 / 分段控件 / 标签页 / 分页 / 模态对话框 / 下拉选择 / 工具提示 / 日期选择 / 时间选择 / 下拉刷新 / 标签片 / 环形进度 / 树视图 / Toast / SnackBar / 菜单 / 图标 / 图标按钮 / 流式布局 / 分隔线 / 底部弹层 / 锚定浮层 / 顶部应用栏 / 底部导航栏 / 侧边导航栏 / 可编辑组合框 / 虚拟列表 / 虚拟网格 / 横向虚拟列表 / 按压水波纹 / 48px 原生比例字体 / 按词换行 / 形状抗锯齿 / 8bpp 文本覆盖度抗锯齿）
stdlib/asterui/assets/font_latin.auf   8x8 1bpp 位图字体（ASCII 32..126，旧示例兼容）
stdlib/asterui/assets/font_cjk.auf     16x16 1bpp 汉字回退字体（GB2312 6763 字 + 标点/全角，325 KB）
stdlib/asterui/assets/font_latin24.auf 24px 比例拉丁字体（95 字形，含 xoff/yoff 与真实 advance，8bpp，19 KB）
stdlib/asterui/assets/font_cjk24.auf   24x24 1bpp 汉字回退字体（6932 字形，610 KB）
stdlib/asterui/assets/font_latin48.auf 48px 比例拉丁字体（95 字形，8bpp 覆盖度，69 KB，1 倍绘制）
stdlib/asterui/assets/font_cjk48.auf   48x48 1bpp 汉字回退字体（6932 字形，2.0 MB，1 倍绘制）
tools/gen_auf.py                字体图集生成器
tools/gen_cjk_auf.py            从 Noto Sans CJK 生成 16x16 / 24x24 / 48x48 CJK 图集
tools/gen_latin_auf.py          从 Noto Sans CJK 生成 24px / 48px 比例拉丁图集（xoff/yoff + advance，1bpp/8bpp 可选）
tools/gen_png_fixtures.py       PNG 测试图生成器（各色型 / 过滤器 / deflate 块型）
examples/ui_hello.ast           计数器 + 开关/进度条示例（标题、图标、+/-/Reset、提醒开关、65% 进度）
examples/ui_list.ast            滚动列表示例（24 行 + 列表内按钮）
examples/ui_form.ast            文本输入示例（字段 + 键盘 + 实时回显 + Focus/Clear）
examples/ui_nav.ast             页面栈示例（3 页 + 系统 BACK + 240 ms 转场）
examples/ui_system.ast          系统适配示例（内容区 / 安全区 / 深色模式）
examples/ui_anim.ast            动画示例（两张卡片淡入 + 上滑，Replay 重播）
examples/ui_settings.ast        设置示例（复选 / 单选 + 深色切换 / 两个滑块带实时数值 / 分段单位切换 / Reset）
examples/ui_tabs.ast            标签页示例（Feed / Stats / More 三页 + 每页独立内容 + 深色开关 / Reset）
examples/ui_pager.ast           分页示例（Tab + 三页可横滑：Feed / Stats / Settings，页内可纵向滚动）
examples/ui_dialog.ast          对话框示例（列表页 + 删除确认：遮罩/BACK/Cancel/Delete 四种关闭路径）
examples/ui_select.ast          下拉选择示例（三个下拉 + 实时回显：选项/外部/BACK 关闭 + 深色 + 中文选项）
examples/ui_tooltip.ast         工具提示示例（四方向 + 容器 + start/center/end；长按 500 ms，短按照常点击）
examples/ui_date.ast            日期选择示例（月视图 / 年视图 / 箭头换月 / 范围限制 / 深色 / 实时回显）
examples/ui_time.ast            时间选择示例（时/分字段 / 表盘拖动 / 12h + AM/PM / 15 分钟步长 / 深色 / 实时回显）
examples/ui_refresh.ast         下拉刷新示例（24 行列表 / 阻尼与阈值 / 刷新计数 / 行点击 / 深色）
examples/ui_chip.ast            标签片示例（单选筛选 / 多选标签 / 列内固有宽 / 深色）
examples/ui_progress_circle.ast  环形进度示例（25/60/100% 并排 / +25% 受控 / 不确定旋转 / 默认 24 dp / 深色）
examples/ui_tree.ast            树视图示例（20 行目录 / 展开收起 / 选中 / 禁用 / 滚动 / 深色 / 状态回显）
examples/ui_toast.ast           Toast / SnackBar 示例（单条/堆叠/常驻/穿透/UNDO 回调/深色）
examples/ui_menu.ast            菜单示例（锚定/屏幕点/超长滚动/勾选/禁用/翻上/深色）
examples/ui_icon.ast            图标示例（22 个内置矢量图标 / 工具条 / 禁用 / 尺寸 / 深色）
examples/ui_layout.ast          流式布局示例（换行标签片 / 对齐模式 / 分隔线 / 深色）
examples/ui_sheet.ast          底部弹层示例（滑入 / 滑块 / Cancel/Confirm / 手柄隐藏 / 深色）
examples/ui_popup.ast          锚定浮层示例（四方向 / 三对齐 / 滑块 / Cancel/Apply / 深色）
examples/ui_top_bar.ast        顶部应用栏示例（leading / 动作 / 居中 / 提示线 / 长标题 / 深色）
examples/ui_nav_bar.ast        底部导航栏示例（4 项 / 等宽 / 隐藏未选中文字 / 禁用 / 深色）
examples/ui_nav_pane.ast       侧边导航栏示例（收缩/展开 / 4 项 / 禁用 / 深色）
examples/ui_combo.ast          可编辑组合框示例（前缀过滤 / 键盘输入 / 选建议 / Clear / 深色）
examples/ui_vlist.ast          虚拟列表示例（5000 行 / 固定 64 dp 行高 / 点行选中 / 深色）
examples/ui_vgrid.ast          虚拟网格示例（1000 格 / 3 列 / 行高 120 dp / 点格选中 / 深色）
examples/ui_hlist.ast          横向虚拟列表示例（1000 卡 / 项宽 160 dp / 横滑 / 点项选中 / 深色）
examples/ui_ripple.ast        按压水波纹示例（20 行 / 按住扩散 / 松手淡出 / 开关 Toggle / 深色）
examples/probe1_red.ast         诊断包 1：裸 NativeActivity 纯红屏
examples/probe2_text.ast        诊断包 2：AsterUI 最小两行文字
tests/headless_test.ast         离屏渲染 + 输入派发自检（返回码 0..7）
tests/scroll_test.ast           滚动自检：偏移 / clamp / 裁剪 / 滚动后点击
tests/fling_test.ast            fling / 滚动条自检（返回码 0..12）
tests/anim_test.ast             动画槽自检（alpha / TX / 时间注入 / 64 槽上限）
tests/anim_harness.ast          ui_anim 的假宿主测试（启动 / 中点 / Replay / 后台）
tests/text_test.ast             文本字段 / 键盘自检（返回码 0..14）
tests/form_harness.ast          ui_form 的假宿主端到端测试（键盘显隐与输入 + BACK 收键盘）
tests/nav_test.ast              页面栈自检（push/pop/reset/上限/清焦点）
tests/nav_harness.ast           ui_nav 的假宿主测试（按钮 + 系统 BACK + 根页 finish）
tests/nav_transition_test.ast   页面转场自检（push/pop/reset 双层快照 / 文字深拷贝 / 容量退化）
tests/nav_transition_harness.ast ui_nav 转场的假宿主测试（输入吞噬 / 自动结束）
tests/nav_watchdog_test.ast     转场看门狗自检（帧定时器全程不回调：到点收尾 + 降级直切）
tests/png_test.ast              PNG 解码自检（三种 deflate 块 / 0~4 过滤器 / 色型 / tRNS / 拒绝路径）
tests/cjk_test.ast              CJK 回退字体 / UTF-8 编辑自检（16x16 字形 / 混排宽度）
tests/controls_test.ast         开关 / 进度条自检（开/关/点按 / 千分比 / 夹紧 / 绘制色）
tests/select_test.ast           复选 / 单选 / 滑块自检（几何 / 配色 / 对勾 / 圆点 / 点击 / 吸附 / 拖动实时值）
tests/segmented_test.ast        分段控件自检（等宽 / 胶囊内缩 / 边框 / 按下态 / 下标回读 / 行内固有宽度）
tests/tabs_test.ast             标签页自检（固有宽度 / 2dp 指示条 / 选中文字 / 下标回读 / 空白区域不回调）
tests/pager_test.ast            分页自检（拖动 / 吸附 / 回调 / 轴锁 / 裁剪 / 邻页不误触 / 速度阈值）
tests/pager_harness.ast         ui_pager 的假宿主测试（左滑翻页 / Tab 吸附 / 版本号）
tests/dialog_test.ast           对话框自检（遮罩/卡片几何 / 遮罩关闭 / 卡片空白 / BACK 原因 / 底层恢复）
tests/dialog_harness.ast        ui_dialog 的假宿主测试（打开 / 遮罩 / BACK / Cancel / 版本号）
tests/dropdown_test.ast         下拉选择自检（触发器几何 / 浮层锚定 / 回调下标 / 外部与 BACK 关闭）
tests/select_harness.ast        ui_select 的假宿主测试（展开 / 选中 / 外部 / BACK / 深色 / 上翻）
tests/tooltip_test.ast          工具提示自检（500 ms / 持有 / 停留 / 取消 / 四方向 / 翻边 / BACK / 多行换行）
tests/tooltip_harness.ast       ui_tooltip 的假宿主测试（长按显示 / 不点击 / 停留 / 容器 / BACK）
tests/date_picker_test.ast      日期选择自检（网格 / 换月 / 年视图 / 范围 / 周一开头 / 夹紧 / 归一化）
tests/date_picker_harness.ast   ui_date 的假宿主测试（换月 / 年视图 / 选日 / 重复点 / 深色）
tests/time_picker_test.ast      时间选择自检（字段切换 / 拖动 / 24h 内外圈 / 12h AM/PM / 步长 / 双卡 / 深色）
tests/time_harness.ast          ui_time 的假宿主测试（选分 / 拖动 / 选时进分 / 12h / 步长 / 深色）
tests/refresh_test.ast          下拉刷新自检（阻尼 / 96 dp 上限 / 68 dp 阈值 / 52 dp / 700 ms / 应用 refreshing / 滚动）
tests/refresh_harness.ast       ui_refresh 的假宿主测试（下拉 / 回调 / 52 dp / 相位 / 滚动 / 深色）
tests/chip_test.ast             标签片自检（固有尺寸 / 选中主色 / 24% 描边 / 按下态 / 深色）
tests/chip_harness.ast          ui_chip 的假宿主测试（单选切换 / 多选位 / 列内不拉伸 / 深色）
tests/progress_circle_test.ast   环形进度自检（0-100% / 弧起点 / 28% 旋转 / 默认尺寸 / 夹紧 / 深色）
tests/progress_circle_harness.ast ui_progress_circle 的假宿主测试（并排 / +25% / 旋转 / 默认 24 dp / 深色）
tests/shape_aa_test.ast          形状抗锯齿自检（圆角/圆/胶囊/描边/2dp 指示条的覆盖率过渡）
tests/tree_test.ast              树视图自检（几何/缩进/标志位/选中底色/三角方向/点按/滚动/禁用/版本）
tests/tree_harness.ast           ui_tree 的假宿主测试（展开收起 / 滚动 / 禁用 / 深色）
tests/toast_test.ast             Toast / SnackBar 自检（几何/堆叠/穿透/到期/暂停/回调/深色）
tests/toast_harness.ast          ui_toast 的假宿主测试（穿透 / 堆叠 / UNDO / 到期 / 深色）
tests/menu_test.ast              菜单自检（锚定/翻边/夹紧 / 勾选/禁用 / 顺序 / 外部/BACK / 滚动 / 屏幕点）
tests/menu_harness.ast           ui_menu 的假宿主测试（锚定 / 选择 / 禁用 / 外部 / BACK / 屏幕点 / 滚动 / 翻上 / 深色）
tests/icon_test.ast              图标自检（40 dp 方块 / 22 个图形 / 禁用 / 按下 / 尺寸 / 深色）
tests/icon_harness.ast           ui_icon 的假宿主测试（工具条 / 点击 / 禁用 / 尺寸行 / 滚动 / 深色）
tests/layout_test.ast            Flow / Divider 自检（换行 / 对齐 / 权重 / 分隔线 / 深色）
tests/layout_harness.ast         ui_layout 的假宿主测试（标签片换行 / 对齐模式 / 分隔线 / 深色）
tests/sheet_test.ast             底部弹层自检（贴底 / 遮罩 / 圆角 / 拖拽吸附 / 关闭原因 / 手柄 / 深色）
tests/sheet_harness.ast          ui_sheet 的假宿主测试（滑入 / 滑块 / Confirm / 下拉 / 遮罩 / BACK / 手柄 / 深色）
tests/popup_test.ast             锚定浮层自检（锚定/翻边/夹取 / 四方向 / 外部/BACK/dismiss / 互斥 / 深色）
tests/popup_harness.ast          ui_popup 的假宿主测试（打开 / 滑块 / Apply / 外部 / BACK / 方向 / 对齐 / 深色）
tests/top_bar_test.ast           顶部应用栏自检（高度/内边距 / leading/动作 / 标题区间 / 居中 / 提示线 / 撑高 / 深色）
tests/top_bar_harness.ast        ui_top_bar 的假宿主测试（leading / 动作 / 居中 / 提示线 / 长标题 / 深色）
tests/nav_bar_test.ast           底部导航栏自检（等宽 / 指示胶囊 / 选中回读 / 禁用 / 隐藏文字 / 深色）
tests/nav_bar_harness.ast        ui_nav_bar 的假宿主测试（贴底 / 等宽 / 选中切换 / 隐藏文字 / 禁用 / 深色）
tests/nav_pane_test.ast          侧边导航栏自检（收缩/展开 / 指示胶囊 / 选中回读 / 禁用 / 文字裁剪 / 深色）
tests/combo_test.ast             组合框自检（触发器/浮层/建议几何 / 前缀过滤 / 选择回读 / 外部与 BACK / 深色）
tests/nav_pane_harness.ast       ui_nav_pane 的假宿主测试（收缩 189 px / 展开 672 px / 选中切换 / 禁用 / 文字 / 深色）
tests/combo_harness.ast          ui_combo 的假宿主测试（展开 / 键盘输入过滤 / BACK / 选建议 / 外部 / Clear / 深色）
tests/vlist_test.ast             虚拟列表自检（窗口 / 滚动 / 选中回读 / 裁剪 / clamp / 惯性）
tests/vlist_harness.ast          ui_vlist 的假宿主测试（5000 行 / 168 px 行高 / 中段与底部 / 深色）
tests/vgrid_test.ast             虚拟网格自检（固定/自适应列 / 窗口 / 滚动 / 点格 / 惯性）
tests/vgrid_harness.ast          ui_vgrid 的假宿主测试（3 列 / 315 px 行高 / 中段与底部 / 深色）
tests/hlist_test.ast             横向虚拟列表自检（窗口 / 滚动 / 选中回读 / 惯性 / 固定项高与间距）
tests/hlist_harness.ast          ui_hlist 的假宿主测试（420 px 项宽 / 21 px 间距 / 中段与底部 / 深色）
tests/ripple_test.ast           按压水波纹自检（默认关 / 扩散 / 只画按下行 / 淡出 / 关闭清除 / 按钮 key）
tests/ripple_harness.ast        ui_ripple 的假宿主测试（按住行 / 半径增长 / 淡出恢复 / Toggle 关闭）
tests/system_test.ast           内容区 / 安全区 / 深色主题自检（离屏）
tests/system_harness.ast        ui_system 的假宿主测试（旋转 / 内容区 / 配置 / 深色切换）
tests/list_harness.ast          ui_list 的假宿主冒烟测试（按实际矩形拖动后点按钮）
tests/font24_test.ast           24px 拉丁/汉字自检（比例步进 / 3 字节行 / 墨迹）
tests/font48_test.ast           48px 原生字体自检（1 倍绘制 / 5–6 字节行 / 行字节序 / 基线）
tests/android_harness.ast       qemu 上的假 Android 宿主冒烟测试
tests/fake_ndk.ast              harness 用的 NDK 仿真（真实像素缓冲）
tests/android_stubs.ast         离屏测试用 NDK 空实现
tests/probe1_harness.ast        qemu 上跑 probe1 onCreate，验证 /p1.txt 轨迹
tests/run_qemu.sh               在 x86_64 主机上用 qemu-user 跑 AArch64 测试
tools/check_so.py               加载门禁（自查重定位 + 悬空 VERNEED + 不存在符号）
tools/check_input_bridge.py     输入坐标桥门禁（getX/Y -> lrintf 的 s0 时序）
tools/fix_selfreloc.py          已坏 .so 的应急修补（门禁通过后不需要）
patches/aster-16k.patch         16 KB 页对齐的编译器修复
patches/aster-link-so-funcaddr.patch  link-so 函数地址重定位修复（真机闪退根因 1）
patches/aster-no-verneed.patch   不再输出悬空 DT_VERNEED（真机闪退根因 2）
patches/aster-configchanges.patch  APK configChanges 覆盖 orientation/uiMode/density
build.sh                        编译 → 链接 → 打包 → 验证
```

## 构建

```sh
ASTER=/path/to/aster ./build.sh
```

产物：`build/libuihello.so`、`build/libuilist.so`、`build/libuiform.so`、
`build/libuinav.so`、`build/libuisystem.so`、`build/libuianim.so`、
`build/libuisettings.so`、`build/libuitabs.so`、`build/libuipager.so`、`build/libuidialog.so`、`build/libuiselect.so`、`build/libuitooltip.so`、`build/libuidate.so`、`build/libuitime.so`、`build/libuirefresh.so`、`build/libuichip.so`、`build/libuiprogress.so`、`build/libuitree.so`、`build/libuitoast.so`、`build/libuimenu.so`、`build/libuiicon.so`、`build/libuilayout.so`、`build/libuisheet.so`、`build/libuipopup.so`、`build/libuitopbar.so`、`build/libuinavbar.so`、`build/libuinavpane.so`、`build/libuicombo.so`、`build/libuihlist.so`、`build/libuiripple.so`、
`build/uihello.apk`、`build/uilist.apk`、`build/uiform.apk`、`build/uinav.apk`、
`build/uisystem.apk`、`build/uianim.apk`、`build/uisettings.apk`、`build/uitabs.apk`、`build/uipager.apk`、
`build/uidialog.apk`、`build/uiselect.apk`、`build/uitooltip.apk`、`build/uidate.apk`、`build/uitime.apk`、`build/uirefresh.apk`、`build/uichip.apk`、`build/uiprogress.apk`、`build/uitree.apk`、`build/uitoast.apk`、`build/uimenu.apk`、`build/uiicon.apk`、`build/uilayout.apk`、`build/uisheet.apk`、`build/uipopup.apk`、`build/uitopbar.apk`、`build/uinavbar.apk`、`build/uinavpane.apk`、`build/uicombo.apk`、`build/uihlist.apk`、`build/uiripple.apk`、
`build/probe1-red.apk`、`build/probe2-text.apk`、以及
`build/{headless_test,scroll_test,fling_test,anim_test,anim_harness,text_test,nav_test,system_test,android_harness,list_harness,form_harness,nav_harness,nav_transition_test,nav_transition_harness,nav_watchdog_test,system_harness,png_test,cjk_test,controls_test,select_test,segmented_test,tabs_test,pager_test,pager_harness,dialog_test,dialog_harness,dropdown_test,select_harness,tooltip_test,tooltip_harness,date_picker_test,date_picker_harness,time_picker_test,time_harness,refresh_test,refresh_harness,chip_test,chip_harness,progress_circle_test,progress_circle_harness,shape_aa_test,tree_test,tree_harness,toast_test,toast_harness,menu_test,menu_harness,icon_test,icon_harness,layout_test,layout_harness,sheet_test,sheet_harness,popup_test,popup_harness,top_bar_test,top_bar_harness,nav_bar_test,nav_bar_harness,nav_pane_test,nav_pane_harness,combo_test,combo_harness,hlist_test,hlist_harness,ripple_test,ripple_harness}`。
`verify-apk` 必须通过，`tools/check_so.py` 与 `tools/check_input_bridge.py`
必须通过，且 APK 内 `classes.dex` 数量必须为 0（脚本会检查）。

**编译器补丁（四个都要）**：

```sh
cd /path/to/aster
git apply /path/to/asterui/patches/aster-16k.patch
git apply /path/to/asterui/patches/aster-link-so-funcaddr.patch
git apply /path/to/asterui/patches/aster-no-verneed.patch
git apply /path/to/asterui/patches/aster-configchanges.patch
# 重新编译 aster，然后用它执行 build.sh
```

第一个让 `.so` 的 `p_align = 0x4000`、APK 内 `.so` 数据偏移 16384；
第二个修掉「回调函数地址被写成未定义 GLOB_DAT」——Android 链接器在
`dlopen` 阶段解析 `BIND_NOW` 时找不到该符号；
第三个去掉 `DT_VERNEED`（`libc.so.6` / `GLIBC_2.17`）——bionic 的
`VersionTracker::init_verneed` 要求每个 `vn_file` 必须是本库 DT_NEEDED
子节点的 soname，否则 `dlopen` 直接失败；
第四个把打包时写死的 `android:configChanges="0x490"` 扩成 `0x1F90`，
让旋转/分屏/深色/density 变化走 `onConfigurationChanged` 与
`onNativeWindowResized`，而不是重建 Activity（否则 v1.9 的配置回调在
真机上根本不会触发）。
`build.sh` 第 4 步的 `tools/check_so.py` 会同时拦截前两类产物；
`tools/check_input_bridge.py` 再检查 `event_x/event_y` 里
`bl AMotionEvent_getX/Y` 到 `bl lrintf` 之间没有指令破坏 `s0`。

## 无真机测试

```sh
ASTER=/path/to/aster tests/run_qemu.sh
```

需要 `qemu-aarch64`。会编译并运行：

- `headless_test`：离屏 320×240 渲染，校验命令数、非空画面、左上角主题色；
  再用可脚本化的假输入队列模拟点按 `+1` 按钮，断言计数 +1，并验证
  「点按钮外」「按下后移出抬起」都不触发回调。
- `scroll_test`：离屏 200×200，构造 494 px 内容 / 180 px 视口；断言拖动 40 px 后
  偏移与子节点位置同步、滚出视口的内容不会画到页头（裁剪）、下拉钳制在
  最大值、滚动之后点列表内按钮仍然命中。
- `android_harness`：模拟 `onCreate → onStart → onResume → onWindowCreated →
  onRedrawNeeded → onPause/onStop/onDestroy`，窗口是 720×1280 真实内存缓冲，
  断言回调表已装、画面非空、销毁不崩；再验证 `+` / `-` 的点击计数。
- `list_harness`：跑真实 `ui_list`，在滚动视口里向上拖 300 px，断言按钮随
  内容移动 300 px，并在新位置点它一次（计数 +1）。
- `fling_test`：离屏 200×200、可滚 700 px；检查滚动条像素、1200 px/s 抛掷的
  减速停点、5000 px/s 撞底钳制、在底端向外抛掷被拒绝、反向抛掷落点、
  2 px/s 微速被拒绝。
- `anim_test`：离屏 320×240、注入时钟；断言 alpha 0 → 128 → 255 的
  插值与半透明像素混合、TX 30 → 15 → 0 dp 的位移、动画期间 build 次数
  不变、reset 回默认值、64 槽全满后第 65 个被拒绝、key=0 被拒绝。
- `anim_harness`：跑真实 `ui_anim` 的假宿主路径；首帧 4 个槽都在跑且
  alpha=0，200 ms 时 alpha 介于 0..255，500 ms 后全部结束并到 255；
  点 Replay 后重新出现 4 个槽且 alpha 回到 0；`onPause` 保留槽、
  `onResume/onDestroy` 不崩。
- `nav_test`：离屏 320×480；断言初始 route/depth 为 1/1、push 2/3/4 后栈深与
  route 正确、push 会清焦点、栈满 8 后 push 被拒绝、pop 回退、reset 重置、
  根页面 pop 返回 -1。
- `nav_harness`：跑真实 `ui_nav`，按钮 push 到 2/3、系统 BACK 逐级 pop、
  直接 push、reset 回根，最后在根页面按 BACK 断言调用了
  `ANativeActivity_finish`（假 NDK 记录标志）；测试内先 `aui_nav_transition(0)`
  关掉演示里的 240 ms 转场。
- `nav_transition_test`：离屏 320×480、红/绿/蓝整屏页面；push 进入转场并挂起，
  起点旧页完全不透明，中点左缘偏红/右缘偏绿/中心两层混合，终点落到新页且
  自动结束；旧页文字在新 build 覆盖文本池后仍按快照显示（x>=30 处有墨迹）；
  pop 反向、reset 只淡入不位移；`aui_nav_transition(0)` 立即取消；旧页
  2100 条命令超过 2048 上限时退化为直切（`aui_nav_busy()==0`）。
- `nav_transition_harness`：跑真实 `ui_nav`（240 ms 转场）+ 注入时钟；push 后
  busy=1，转场中的点击与 BACK 都不生效，240 ms 后自动结束；随后按钮 push、
  系统 BACK pop 各自再次进入转场并正常结束。
- `nav_watchdog_test`：模拟真机故障——转场启动后**一次 `aui_frame` 都不调用**
  （等价于帧定时器彻底不回调），只推进注入时钟。断言 `aui_nav_busy()` 到点
  自动归零、到点后的第一下点击与 BACK 照常生效；越过 240+250 ms 判定窗口后
  该转场被记为“帧源已死”，之后的 push/pop 全部直切（busy 始终 0）。
- `text_test`：离屏 560×420；点字段断言获得焦点且出现底部主色线、点 `q`
  得到 `q`、`SHIFT` 后点 `q` 得到 `Q`、`DEL` 退格、切到 `123` 后输入数字、
  `DONE` 收起焦点与键盘、`aui_text_clear` 清空。
- `form_harness`：跑真实 `ui_form`，断言初始无键盘、点字段后键盘出现、
  `q` / `SHIFT+q` / `DEL` 的文本变化、`DONE` 后键盘消失、`Focus` 按钮
  重新唤起、`Clear` 清空；再打开键盘按系统 BACK，断言只收键盘、
  文本保留、界面仍在。
- `system_test`：离屏 720×1280、density 420；初始整窗布局，然后模拟
  状态栏/导航栏内容区 `(24,72,696,1208)`，断言根节点缩进到
  `(24,72,672,1136)`、子节点随之偏移、`aui_safe_*` 的 dp 值、多出的全屏
  底色命令、安全区内按钮仍可点；再切深色断言背景/角色色与像素。v1.14
  追加：模拟 sdk=35 + 整窗内容区，断言 `aui_safe_top/bottom` 为 24 dp、
  根节点 `(0,63,720,1154)`；`aui_edge_to_edge(1)` 后回到 0 与整窗；
  `aui_set_insets(0,40,0,0)` 得 40/0 dp、根节点 `(0,105,720,1175)`；
  恢复估算后取较大值得 40/24 dp、根节点 `(0,105,720,1112)`；最后清空
  恢复 24/24。v1.15 追加：系统栏条带与内容区底色各一条命令、条带像素
  为 `AUI_COLOR_SYSTEM_BAR`、内容区仍是主题底色；`aui_set_system_bar`
  换成 `0xFF3A6DF0` 后条带像素跟着变，传 0 恢复；深色主题角色为
  `0xFF050507`。最后恢复全屏和浅色。
- `system_harness`：跑真实 `ui_system`，模拟旋转到 1280×720、内容区回调、
  `uiMode=night` + density 160 的配置变化，断言根节点、dp 尺寸、深色像素
  同时更新；再点 `Toggle dark` 切回浅色。
- `probe1_harness`：只调 probe1 的 `ANativeActivity_onCreate`，断言回调表已装，
  并检查 `/tmp/asterui-p1/p1.txt` 写出了 `A`/`K`（加载期轨迹不依赖 AsterUI）。
- `png_test`：13 张确定性测试图（7 张成功解码 + 6 个反例）。RGBA 4×3 逐像素核对公式与 47 字节
  缓冲的 -3；9×5 真彩图把 0~4 五种行过滤器各用一遍（deflate 为 fixed）；
  灰度 + tRNS 的 (1,1) 透明；调色板 + tRNS 按索引取色与 alpha；
  一条 PNG 拆成 3 个 IDAT（第一个只有 1 字节）验证跨段位流；64×48 RGBA 的
  dynamic Huffman；3×2 的 fixed 块；48×48 图标 PNG 解码结果与裸 RGBA
  逐字节相同；16 位 / 隔行返回 -2，2048×2048 超出行缓冲 -3，截断 -4，
  非 PNG -1，坏过滤器 -4；池分配往返（复位后同址、两次解码不同址、
  大图返回 0）。
- `cjk_test`：离屏 720×1280；注入 8x8 拉丁与 16x16 CJK 回退字体后，
  `中文` 宽 32 px、`A中` 宽 32 px、`中文界面` 宽 64 px、行高 20 px；
  汉字区域有墨迹；关闭回退后宽度不变但墨迹为 0；UTF-8 追加
  `U+4E2D U+6587` 得到 6 字节、退格两次删掉整个码点；恢复回退后
  再次出墨。
- `controls_test`：离屏 320×240；开关开/关两态分别是 44×24 dp 的胶囊，
  开轨道 `AUI_COLOR_PRIMARY`、滑块 `AUI_COLOR_SURFACE`，关轨道
  `AUI_COLOR_SCROLLBAR`；点开关触发一次回调并翻转应用状态，点标签不触发；
  进度条高 8 dp、宽 288 px，值 500 时左半 `PRIMARY`、右半 `SCROLLBAR`，
  左右圆角半径都是 4 dp；值 2000 夹到 1000（整条填满），值 -50 夹到 0
  （只剩轨道）。
- `select_test`：离屏 320×240、density 160；复选框为 20×20 dp 方框
  （圆角 4 dp、2 dp 边框），勾选态是 `PRIMARY` 填充 + 白色对勾像素，
  未选态是 `HINT` 边框、内部为页面底色；整行 288 px 可点，点一次回调
  一次、点标签同样生效。单选钮 20×20 dp 圆环，选中时外环 `PRIMARY`、
  内部底色、中心 10 dp 圆点 `PRIMARY`，未选外环 `HINT`；两个单选钮
  互斥由应用状态决定，点 B 只触发 B 的回调。滑块高 32 dp、轨道 4 dp、
  拇指 16 dp，轨道两端内缩 9 dp、可点区域是全宽；点 25% 位置得到 200、
  拖动时回调里 `aui_slider_value` 读到实时值（500→800）、松手后保留；
  `step=0` 不吸附：点最右得 1000、点最左得 0，两端始终可达。
- `segmented_test`：离屏 320×240、density 160；三分段容器在 column 里铺满
  288 px、高 32 px，三段各 96 px；外层 1 dp `HINT` 边框、内部 `SURFACE`，
  选中段胶囊 2 dp 内缩（上/下各留 1 px 内衬），标签在胶囊上用
  `ON_PRIMARY`、未选段用 `TEXT`。点 High 回调一次并从 `aui_segmented_value(3)`
  读回 2，重绘后胶囊移到第三段；点 Low 回到 0；再点已选中的段仍回调但下标
  不变。只按下不松开时段画 `PRESSED` 胶囊，松手才选中。点容器外不回调；
  row 里的两段控件保持固有宽度 96 px（不铺满整行），行内 A/B 独立选择；
  第三行三分段固有宽度 48+76+48=172 px，Q16.16 等分后显示为 57/57/57。
- `tabs_test`：离屏 320×240、density 160；页宽由文字决定（A/B 最少 48 px、
  Longer 72 px），容器在 column 里铺满 288 px、高 36 px；选中页文字
  `PRIMARY`、未选页 `TEXT`，底部 2 dp 指示条只盖当前页（y=68/69 两行主色，
  其余页下方没有）。点 Longer 回调一次并从 `aui_tabs_value(3)` 读回 2，
  重绘后指示条与文字颜色一起移动；点已选中页仍回调但下标不变；点第三页
  右侧的容器空白不回调。row 里的两页控件保持固有宽度 96 px，三页行
  48+72+48=168 px；行内选择独立、不影响上方主控件；未知 key 返回 -1。
- `pager_test`：离屏 320×240、density 160；三页红/绿/蓝各 288×188。
  初始偏移 0、首屏只有红页；拖到 60 px 时红页左移、绿页从右侧进入、
  视口外仍是底色；CANCEL 回弹不回调；左拖 150 px 松手提议第二页并回调，
  200 ms 后偏移 288；点第二页按钮命中 B+ 而不是 A+；短拖 50 px 回弹；
  第二页再左拖只提议相邻的一页；末页继续左拖不回调；纵向拖动锁定滚动、
  偏移不变；应用把 selected 改回 0 后自动吸附；最后用注入时钟做一次
  50 px 快速轻扫，验证速度 ≥ 600 px/s 同样翻页；最后从按钮上纵向拖
  15 px 再松手，断言不会误触发点击。
- `pager_harness`：跑真实 `ui_pager`（720×1280、density 420），在分页区
  左滑后 Tab 与 `aui_pager_value(20)` 都变成 1，第二页贴住视口；点
  Settings Tab 后自动吸附到第三页；同时断言 `aui_version() == 13300`。
- `dialog_test`：离屏 320×240、density 160；打开后卡片 `(24,58,272,124)`
  居中、遮罩像素 `0x626263`、卡片中心是 surface；遮罩挡命中（返回
  对话框负 key）、卡片空白不关闭、卡片按钮独立回调；点遮罩关闭并记
  reason=1，底层按钮不被触发，关闭后卡片节点消失、底层恢复可点；
  重开后按 BACK 关闭并记 reason=2、底层计数不变。
- `dialog_harness`：跑真实 `ui_dialog`（720×1280、density 420）；点
  Delete draft 后卡片出现且宽 594 px、水平/垂直居中、节点数 +7，遮罩
  把底色压暗；点遮罩关闭后节点数与底色恢复；重开后 BACK 关闭；第三次
  打开点 Cancel 关闭；同时断言 `aui_version() == 13300`。
- `dropdown_test`：离屏 320×240、density 160；触发器 `(8,8,304,48)`，
  展开后浮层 `(8,60,304,156)`（下方 4 dp、宽度跟触发器），首项选中用
  TINT 底、行高 48 dp、左右各内缩 4 dp；浮层 padding 命中返回 -2 且
  不关闭；点第二项 reason=1、`aui_select_value(20)` 读回 1 并关闭；
  点外部/触发器再次点击 reason=2、BACK reason=3，底层按钮在展开期间
  不触发、关闭后恢复；选项始终在树里，节点数保持 7。
- `select_harness`：跑真实 `ui_select`（720×1280 假宿主，密度 240 让整页
  放得下）；打开 Language 浮层宽度等于触发器、锚在下方，点 German 后
  重开时第 2 行变 TINT；点外部关闭；Theme 用系统 BACK 关闭；切深色后
  浮层内边距 `1E1E24`、选中底色 `232A3D`；最后把密度调回 420 让 Sort
  贴近底部，断言浮层翻到触发器上方；中途验证选项按下 PRESSED 底色、选项间拖动和从浮层外拖进选项都不会误选；全程节点数不变、版本 13300。
- `tooltip_test`：离屏 320×240、density 160；三个提示挂在按钮/容器/底部
  标签上。按住 300 ms 仍是待定、510 ms 才显示；按住期间抬起不触发按钮，
  气泡转停留 1.5 s 后消失；短按照常点击；按住后移出 8 dp 取消；容器在
  `aui_end()` 之后挂上、默认下方 4 dp；底部目标下方放不下翻到上方且夹在
  8 dp 边距内；BACK 只收起气泡；气泡深色底 + 白字；四方向与
  start/center/end 对齐；节点数不变、命令数增加。场景 3 用多行文本
  断言“气泡高 = 行数 × 20 + 8”（返回 26），覆盖绘制重新换行导致的
  末行裁切。
- `tooltip_harness`：跑真实 `ui_tooltip`（720×1280、density 420）；长按
  Above 按钮 520 ms 后气泡出现在按钮上方（4 dp 间距、水平居中或夹到
  边距），抬起不触发点击、停留 1.5 s 后消失；短按照常点击且不出现气泡；
  长按容器气泡贴容器（下方或翻上）、start 对齐；底部提示 end 对齐；
  BACK 只收起气泡；同时断言 `aui_version() == 13300` 与节点数不变。
- `date_picker_test`：离屏 360×700、density 160；默认 2026-10-15，日期块
  360×332、格 36 dp、表头 44 dp，10 月网格从 2026-09-27 起、15 日下标 18；
  白色卡片与 1 px 边框像素、标题/表头墨迹、7×6 网格全部命中；箭头换到
  11 月、标题进年视图（2020-2039，范围外年份置灰），点 2030 回月视图；
  选中 2027-01-01 回调一次，重复点不再回调；点相邻月的 9 月 27 日会跳月
  并选中；按下后拖 8 dp 松手取消。范围场景（2026-10-10..2026-11-20）：
  9/21 日置灰且点击无效，9 月/12 月的箭头被范围挡住、可见月不变，选中
  11-05 回调；周一
  开头网格从 2026-09-28 起、15 日下标 17。场景 3 覆盖夹紧与归一化：
  传入 2024-01-05（早于 min）夹到 2026-03-10 并显示 3 月；2 月 31 日
  归一化到 2 月 29 日（2028 闰年）下标 32；4 月超过 max 的日子置灰；
  两个 key 的可见月份互不影响。
- `date_picker_harness`：跑真实 `ui_date`（720×1280、density 420）；
  日期块宽 573 px、高 688 px、格 68 dp；点右箭头到 2026-11，标题进年
  视图后点 2025 回到 2025-11；点 2025-11-10 后状态回读 20251110、
  回调 1 次，重复点保持 1 次；切深色后卡片亮度骤降、切回恢复；
  同时断言 `aui_version() == 13300`。
- `time_picker_test`：离屏 360×700、density 160；09:30 / 24 小时制，
  选择块 360×300、表心 (180,184)、半径 104、表头 52 dp；选中字段主色、
  另一字段与表盘 tint、手柄/选中胶囊像素与白字。点分字段不回调；点
  05 分位置回读 905，拖到 10 分连续更新且松手不切回选时；23/24/25
  分逐点回读，且 24 分时 5 dp 圆头手柄不覆盖相邻 25 分标签（旧 14 dp
  圆会盖住，用户看到的“偏移”），对齐 25 分时仍是 28 dp 胶囊；选时外圈
  12 得到 12:10 并自动进选分，内圈 00 得到 00:10，外圈 9 点得到 09:10；
  12 小时制 21:30 下 AM/PM 高亮，点 AM/PM 各回调一次；双卡 key
  100/101 互不影响；step=15 时受控 10:07 原样显示，10 分角度吸附 15、
  25 分吸附 30，非法步长 7 返回 -1；深色像素。
- `time_harness`：跑真实 `ui_time`（720×1280、density 420）；选择器
  573×751 px、表盘半径 255 px；点分字段再点 05 分回读 905，拖到 10 分
  回读 910 且回调 ≥2 次；23/24/25 分逐点回读，24 分时 5 dp 手柄不盖
  25 分标签（像素断言）；12h 与 15m 两个开关同宽（weight 只给空位）；
  选时点外圈 12 -> 1210 并自动进选分；开 12h 后 AM/PM 在 00:10 与
  12:10 间切换；24h 内圈 00/13 正确；step=15 时 10 分角度吸附 13:15、
  25 分吸附 13:30；深色卡片亮度骤降；底部不出屏；同时断言
  `aui_version() == 13300`。
- `refresh_test`：离屏 360×700、density 160；容器从标题下方铺满剩余高度。
  容器空白区点按不触发刷新回调，也不会误点行按钮；行按钮照常计数。
  100 px 下拉按 0.45 阻尼显示 45 dp，松手不足 68 dp 自动吸附回 0；
  600 px 下拉夹在 96 dp 并按阈值触发一次。回调后收进 52 dp 旋转，
  相位在 200 ms 内继续推进；700 ms 反馈窗口结束后自动收起。应用把
  `refreshing` 置 1 时保持 52 dp 且内容仍可点击，置 0 后吸附回 0。
  上滑只改滚动偏移、不混入下拉位移；回到顶部的精确回滚不多出位移。
  深色主题下容器/轨道变暗，松手后回正。
- `refresh_harness`：跑真实 `ui_refresh`（720×1280、density 420）；
  容器宽 636 px 且不出屏；点第一行状态 901 = 1；200 px 下拉
  （90 px < 68 dp = 179 px）不回调；500 px 下拉回调一次、状态 900 = 1，
  位移收在 136 px（52 dp）、相位继续旋转，反馈窗口后归零并收起；
  上滑偏移 >250 px 且下拉位移为 0；回滚到顶部后切深色，页面亮度骤降，
  深色下拉时 36 dp 容器圆心采样明显变暗；同时断言 `aui_version() == 13300`。
- `shape_aa_test`：离屏 320×240、density 160；进度条胶囊（半径 4）、
  开关轨道（半径 12）与 9 px 拇指圆、未选复选框的 2 px 描边、已选
  复选框的主色圆角块、标签页 2 dp 指示条（半径 1）。断言圆角像素是
  前景/底色的中间色（两端原色都不算）、圆角外仍是精确底色、直边中点
  仍是精确前景色、2 dp 指示条两端各有过渡且内部仍是纯主色。
- `toast_test`：离屏 320×240、density 160；Toast 底部居中（24 dp 边距）、
  深色底 + 白字、两条按 id 向上堆叠、点 Toast 直接穿透到底层按钮、
  2 s 到期与手动收起/常驻；SnackBar 宽 288 px、动作 88×36、4 s 倒计时，
  点表面被吞掉、按住动作暂停（超过 5 s 仍在）、松手先收起再回调，
  纯消息形态与到期、无效参数全部覆盖。
- `toast_harness`：跑真实 `ui_toast`（720×1280、density 420）；版本 13400，
  Toast 底边在 1280 − 24 dp、水平居中，覆盖底部按钮时点击仍能穿透；
  两条堆叠间距 8 dp；SnackBar 表面不穿透、UNDO 回调后弹出 Restored；
  4 s 到期与深色主题下的浮层配色都保持不变。
- `menu_test`：离屏 320×240、density 160；默认菜单锚在按钮下方 4 dp，
  宽 186 px（≥ 180 dp）、高 117 px，条目/分隔线矩形逐项断言；白底、
  深色文字、勾选标记的两条描边都有墨迹，禁用条目置灰且无近黑像素；
  点勾选条目时菜单先关（surface 回调先于条目回调，reason=1、
  item_key=62），禁用条目点按不回调也不关菜单；点外部 reason=2、
  BACK reason=3；16 条长菜单产生 maxoff 且拖动按 8 dp 阈值滚动、松手
  不误选；屏幕点菜单左上角精确落在 (100,50)；锚点靠底时翻到上方；
  `aui_menu_dismiss()` 计 reason=2；无效参数返回 -1。
- `menu_harness`：跑真实 `ui_menu`（720×1280、density 420）；版本 14201，
  Actions 菜单贴按钮下方、宽 ≥ 472 px，点 Rename 后 reason=1 / item=21
  且 surface 回调已先跑（顺序计数）；禁用 Delete 不响应；点外部/BACK
  原因正确；屏幕点菜单精确在 (60,400)；16 条菜单溢出后拖动滚动 ≥100 px
  且不误选；滚到底部后底部按钮的 3 条菜单翻到按钮上方并可选；
  深色主题下表面变深、文字变亮。
- `icon_test`：离屏 320×240、density 160；40 dp 触控方块（160 dpi 下即
  40 px）逐键断言，行内 6 px 间距；加号横竖两笔、勾选左下/右上两笔都有
  近黑像素；星形轮廓与搜索圆环 + 手柄；禁用垃圾桶仍有浅灰笔画但无近黑
  像素；按下时 32 dp 指示层变深、图形仍在上层，松手恢复；点加号/勾选
  各回调一次，禁用按钮不回调；56 dp 自定义尺寸；深色主题下底色变深、
  图形变亮。
- `icon_harness`：跑真实 `ui_icon`（720×1280、density 420）；版本 14201，
  工具条 5 个 40 dp（105 px）方块、8 dp（21 px）间距且图形都不缺；
  点加号/勾选/关闭依次更新状态 980/981，禁用垃圾桶不回调；按住加号
  出现指示层；22 个网格图标滚动到视口后都有笔画；尺寸行 16→48 dp 宽度
  递增；统计行与深色开关滚到底可见；深色下图标变亮、禁用仍是中灰；
  滚动范围与裁剪正常。
- `layout_test`：离屏 320×320、density 160；7 个 40 dp 图标在 304 px
  内宽里排成 2 行（行高 84、行距 4），换行边界为“放不下才换行”（恰好
  相等不换）；第二行居中、第三行 space-between（首尾贴边），第四行
  20 dp 图标 + weight=1 图标吃掉剩余 280 px；点按流内的图标按钮命中；
  水平分隔线厚 1 dp、内缩 8 dp，竖直分隔线宽 1 dp 且拉满行高；自定义
  颜色/内缩（pad 20）时隔开位置仍是底色；深色下背景变暗、分隔线反而
  变亮（surface 12% alpha）。
- `layout_harness`：跑真实 `ui_layout`（720×1280、density 420）；版本
  14201；6 个标签片在 615 px 内宽里换行，点按依次切换选中（状态 970/
  971/973 计数与末次 key）；7 个图标按 5+2 换行，切换 Start/Center/
  Between 后首行 x 分别为左/居中/贴边（状态 972）；点按改模式后重量
  重新布局；三个图标按钮依次更新末次动作 31/32/33；水平分隔线 615×2、
  竖直分隔线 2×105 左右都有底色，16 dp 与红色 32 dp 内缩线都有墨迹；
  滚动范围、裁剪与深色切换（分隔线比背景亮）正常。
- `sheet_test`：离屏 320×320、density 160；表面 `(16,172,288,148)` 贴底、
  宽 = 内容宽 − 32 dp，遮罩像素 `(0x8F,0x8F,0x90)`；顶部圆角外侧是遮罩、
  底部两角仍是白色表面；点在表面外返回 -20、表面内 20，卡片空白点按不
  关闭；卡片按钮命中 23 且回调一次、reason=0；顶部手柄有 120..240 亮度
  的灰条；下拉 40 px 未过阈值回弹并保持打开，下拉 100 px 关闭且 reason=3；
  点遮罩关闭 reason=1 且底层不再可点；BACK 关闭 reason=2；`aui_sheet_handle(0)`
  后 flags 位 0 置位且手柄像素消失；深色表面 `0x1E1E24`。
- `sheet_harness`：跑真实 `ui_sheet`（720×1280、density 420）；版本 14201；
  打开后表面滑入，动画中途采样顶部是遮罩、结束后是表面；几何 sx=42、
  sw=636、底边贴 1280；滑块拖到 4/5 后状态 973 落在 650..900；点 Confirm
  关闭且状态 971=21；从卡片顶部向下拖 (h/4+260) 后关闭、reason=3、971=20；
  点遮罩关闭 reason=1；`aui_on_input(2,...)` 发 BACK 关闭 reason=2；隐藏
  手柄后 flags 位 0 置位、原手柄位置变成白色；深色表面 `0x1E1E24`。

- `popup_test`：离屏 320×320、density 160；默认下方/左对齐、间距 4 dp、
  固定宽 120；固定 400 被夹到内容区 304，自然宽落在 96..304；点锚在
  底部自动翻上、右缘夹到 192；首选上/右/左与右缘翻左、左缘翻右；节点锚
  居中/末尾按对齐公式落位；内边距空白吞点击、内容按钮独立回调；点外部
  reason=1、BACK reason=2、`aui_popup_dismiss` reason=3；浮层打开时
  dialog/sheet/menu 均返回 -1，对话框打开时 `aui_popup` 返回 -1；深色
  表面 `0x1E1E24`；关闭后 `aui_debug_popup` 返回 -1。
- `popup_harness`：跑真实 `ui_popup`（720×1280、density 420）；版本 14201；
  默认浮层在按钮下方 9..12 px、宽 420、表面白色；拖滑块后状态 973 落在
  650..900；Apply 关闭且状态 971=21；点外部 reason=1、BACK reason=2；
  Above 记录 side=1 且浮层位于按钮上方；Right 在右缘放不下翻到左侧并夹到
  279、Left 夹到 21；Center 记录 align=1；深色表面 `0x1E1E24`。

- `top_bar_test`：离屏 320×320、density 160；版本 14201；应用栏 320×48、
  leading 40 dp 触控块贴左（8,4,40,40）、动作贴右（232/272,4）、标题区间
  52..228；标题墨迹、leading/Search/More 回调；居中公式；底部 1 px 提示线；
  无 leading 时标题区间 24..228；动作高 56 dp 时栏高 56、leading 垂直居中；
  无动作时右端留 4 dp（xe=308）；长标题只画在区间内且起点贴左；嵌套 8 dp
  内边距下几何随内容区收缩；深色表面 `0x1E1E24`。
- `top_bar_harness`：跑真实 `ui_top_bar`（720×1280、density 420）；版本
  14201；栏 720×126、leading rect (21,10,105,105)、动作 x=489/594、标题
  区间 136..478；leading/Search/More 回调计数；居中、底部提示线、长标题
  裁剪、深色表面。
- `nav_bar_test`：离屏 320×320、density 160；版本 14201；栏 320×64、4 项各
  80×64、按下标 0..3；指示胶囊在选中项左侧（主色 12%，56×32 居中），未选中
  项同位置仍是白色；点第二项回调一次并回读下标 1、重绘后选中/胶囊转移；再点
  已选中项不回调；禁用 Star 不回调且标记可读；`aui_nav_labels(0)` 后未选中项
  文字带无墨迹、选中项仍有；selected=9 无选中项/胶囊；单项铺满 320；列内 8 dp
  内边距下栏 304、项 76；深色表面 `0x1E1E24`。
- `nav_bar_harness`：跑真实 `ui_nav_bar`（720×1280、density 420）；版本
  14201；栏贴底 720×168（y=1112）、4 项各 180、指示胶囊随选中移动；
  点 Search 状态 980/981=1、last=11，再点不回调；隐藏未选中文字后 Home
  文字带无墨迹而 Search 仍有；禁用 Star 后标记可读且不回调；深色表面
  `0x1E1E24`。
- `nav_pane_test`：离屏 320×320、density 160；版本 14201；收缩栏 72×320、
  项 56×48（x=8，下标 0..3）；胶囊 56×32 居中、未选中项同位置是白；收缩态
  无文字墨迹；点第二项回调一次并回读 1、胶囊转移；再点不回调；禁用 Star
  不回调且标记可读；展开栏 256 宽、项 240 宽、胶囊铺满、文字从 x=56 起且
  裁剪在 248 内；selected=9 无选中胶囊；行内 8 dp 内边距下栏 72×304、
  项 x=16；深色表面 `0x1E1E24`。
- `nav_pane_harness`：跑真实 `ui_nav_pane`（720×1280、density 420）；版本
  14201；底部开关栏 273 px，收缩栏 189×1007、项 147×126；点 Search 状态
  980/981=1、last=11，再点不回调；禁用 Star 后标记可读且不回调；深色表面
  `0x1E1E24`；展开栏 672×1007、项 630 宽，文字墨迹出现在图标右侧并被右缘
  裁剪；再次点 Expanded 开关能收回 189 宽（开关在底部整宽栏，展开后仍可点）。

`android_harness` 在 v1 上复现了首帧死循环（见 D.5）。

## 用法

```aster
include "asterui/aui.ast";

struct App { count: i32 }
let g_app: App = App { 0 };
let g_font: ptr = @embed("assets/font_latin48.auf");

fn on_add(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.count = a.count + 1;
    aui_invalidate();          // 重建 + 布局 + 重绘
    return 0;
}

fn build(user: ptr) -> i32 {
    let a: ptr<App> = user;
    aui_root();
    aui_column(1);
    aui_pad(24);
    aui_gap(12);
    aui_label(2, "AsterUI");
    aui_text_i32(3, a.count);
    aui_button(4, "Add one", on_add, user);
    aui_radius(12);
    aui_end();
    return 0;
}

fn app_init(user: ptr) -> i32 {
    aui_set_font(g_font, 1);   // v1.19：48px 原生图集 ×1
    return 0;
}

fn ANativeActivity_onCreate(activity: ptr, saved: ptr, savedSize: i64) -> i32 {
    return aui_android_attach(activity, saved, savedSize, build, &g_app, app_init, 0);
}
```

文本输入：

```aster
// 在 build 里：
aui_text_field(10, "type here");      // key=10，提示文字可传空串
aui_label(11, aui_text_value(10));    // 实时回显（每帧重建时重新取指针）
if (aui_focus_get() != 0) {           // 有焦点才铺键盘，避免占满屏幕
    aui_keyboard(10);                 // 自绘 QWERTY，target 为字段 key
}

// 回调里可直接读写：
aui_text_append(10, 65);              // 'A'
aui_text_backspace(10);
aui_text_clear(10);
aui_text_set(10, "hi", 2);
let n: i32 = aui_text_len(10);
aui_focus(10);                        // 聚焦并重建（键盘随之出现）
aui_focus(0);                         // 收起键盘
```

中文文本与 48px 字体（v1.16 / v1.18 / v1.19）：

```aster
// v1.19：48px 原生图集，1 倍绘制 => 48 px，density 3.25 下约 15 dp。
// 字形本身就是 48px，笔画台阶是 1 物理像素；v1.18 的 24px×2 是 2 像素。
let g_latin: ptr = @embed("assets/font_latin48.auf");
let g_cjk: ptr   = @embed("assets/font_cjk48.auf");

fn app_init(user: ptr) -> i32 {
    aui_set_font(g_latin, 1);
    aui_set_fallback_font(g_cjk, 1);
    return 0;
}

// build 里直接写 UTF-8 字面量即可；主字体缺字时自动查回退字体。
aui_label(20, "中文界面");
aui_button(21, "重置", on_reset, user);
aui_label(22, "A中");                  // 混排：A 29 px（比例步进）+ 中 48 px
```

- `font_latin48.auf`（v1.19 主用，v1.44 起 8bpp）是 48px 比例字体：95 个
  ASCII 字形，69 KB，每个字形带自己的 advance 与 xoff/yoff；`font_latin24.auf`
  是它的 24px 版本（19 KB），按 2 倍绘制，供 `font24_test` 覆盖缩放路径。
  v1.44 把这两个图集从 1bpp 阈值位图换成 **8bpp 覆盖度**：一行 `w` 字节，
  每像素一个 alpha，绘制时与文字颜色相乘后混合，笔画边缘有真实的灰阶过渡。
  advance 与墨迹包围盒的计算没有改，所以所有布局尺寸与 v1.43 完全一致。
- `font_cjk48.auf`（v1.19 主用）是 48×48 1bpp 图集，覆盖 GB2312 一、二级
  汉字 6763 个，外加 CJK 标点与全角字符，共 6932 个字形，2.0 MB；
  `font_cjk24.auf` 是 24×24 版本（610 KB）。两套都来自 Noto Sans CJK SC
  （OFL，许可证见 `assets/font_cjk.LICENSE.txt`），由 `tools/gen_cjk_auf.py`
  生成，运行时只解析位图，不加载 TTF。旧版 `font_latin.auf`（8×8）与
  `font_cjk.auf`（16×16）保留，供旧示例和回归测试使用。
- 1bpp 字形按 `ceil(w/8)` 字节读一行（行字是小端整数，最左像素在最高
  位）：48px 汉字一行 6 字节，`W` 一行 5 字节；`font48_test` 用“L”的
  左竖笔与右上角空白卡字节序，用“W”右端卡 5 字节行，`font24_test` 用
  “中”字右半卡 3 字节行。8bpp 字形一行 `w` 字节、逐像素取覆盖度，
  `draw_glyph` 先看字形 flags（`aux+9` 的 bit0）再分派到
  `draw_glyph_aa`，两种编码可以在同一行里混排（拉丁 8bpp + 汉字 1bpp）。
- 文本宽度按实际码点前进：汉字 48 px（两套字体都是），拉丁按比例 advance
  × scale（48px 的 A 是 29 px，i 是 13 px），缺失码点按 8 × scale 留空。
- 两套字体的基线在生成时对齐（latin48 baseline 46 / cjk48 47，混排时汉字
  墨迹只比拉丁低约 1 px；v1.18 的 24×2 是 6 px）。
- v1.18 起标签 / 按钮按**词**换行：优先在最近的空格折行，只有单词本身
  比整行还宽才按字符切；测量与绘制共用 `layout_text()` 的行缓存，保证
  宽度和断行位置一致，长按钮文字不会再被截断。
- `aui_text_append(key, ch)` 的 `ch` 是 Unicode 码点，按 UTF-8 写入
  （1–4 字节）；`aui_text_backspace` 删整个码点。文本池仍是每槽 63 字节，
  约 21 个汉字；系统 IME / 候选词 / 拼音输入仍未实现，中文目前用于
  标签、按钮和程序内写入。
- 只支持位图字形：没有 TTF/OTF 运行时解析、没有复杂文本整形、没有 emoji；
  GB2312 之外的汉字与生僻字显示为空白（宽度仍保留）。

开关与进度条（v1.17）：

```aster
// 开关：状态由应用持有，每次 build 把当前值传进来。
aui_switch(24, a.notify, on_notify, user);   // on != 0 为开

fn on_notify(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.notify = 1 - a.notify;                 // 只翻应用状态
    aui_invalidate();                        // 库按新状态重绘
    return 0;
}

// 进度条：value 是千分比 0..1000（越界自动夹紧），0 = 空、1000 = 满。
aui_progress(28, 650);                       // 65%
aui_progress(29, a.loaded * 1000 / a.total);
```

- 开关是固定 44×24 dp 的胶囊，开/关轨道分别用 `PRIMARY` / `SCROLLBAR`，
  滑块用 `SURFACE`；按下时轨道换成 `PRIMARY_DARK`（开）或 `HINT`（关）。
  点击整个 44×24 区域触发 `cb(user)`，命中判定与其他控件一致。
- 进度条高度固定 8 dp，宽度由父容器分配（column 中默认铺满，row 中给
  `weight(1)`）；轨道 `SCROLLBAR`、已完成部分 `PRIMARY`，两端圆角。
  填充宽度按 `w * value / 1000` 计算，非零时至少保留一个圆角直径（8 dp），
  避免 1% 时看起来像空条。
- 两者都不自己保存状态：开关的 `on` 与进度条的 `value` 每帧由应用传入，
  与 `aui_text_*` 的库内状态机制不同，方便直接映射业务字段。
- 调试：`aui_debug_node_count()` / `aui_debug_cmd_count()` 返回最近一帧的
  节点数与绘制命令数，便于在没有 trace 的环境里写断言。

复选框 / 单选钮 / 滑块（v1.20）：

```aster
// 与开关一样，状态由应用持有；库只负责画和把点击转成回调。
aui_checkbox(30, "Push notifications", a.notify, on_notify, user);
aui_checkbox(31, "Vibrate", a.vibrate, on_vibrate, user);

// 单选钮：同一组只传一个 1，互斥逻辑写在应用里（和 HuxerUI 一致）。
aui_radio(40, "Light theme", a.dark == 0, on_light, user);
aui_radio(41, "Dark theme",  a.dark != 0, on_dark,  user);

// 滑块：value 是千分比 0..1000，step 是吸附步长（千分比，0/1 = 不吸附）。
aui_slider(50, a.bright, 100, on_bright, user);   // 每 10% 一档
aui_slider(51, a.volume, 0,   on_volume, user);   // 连续

fn on_bright(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.bright = aui_slider_value(50);   // 拖动中也是实时值
    aui_invalidate();
    return 0;
}
```

- 复选框与单选钮固定 20 dp 见方（复选框圆角 4 dp、2 dp 边框；单选钮是
  圆环 + 10 dp 圆点），右边留 8 dp 再排文字；放在 column / scroll 里时
  自动铺满整行（整行可点），放在 row / stack 里保持固有宽度
  `pad*2 + 20dp + 8dp + 文字宽`。行高取 `max(20dp, 文字行高) + pad*2`。
  按下时整行有一层淡色状态层（`PRESSED`，圆角 6 dp）。
- 选中色用 `PRIMARY`（按下时复选框用 `PRIMARY_DARK`），未选边框用
  `HINT`；对勾和圆点内部露出的底色跟随父容器：库在绘制时记录当前
  节点的 `bg`（根用主题 `BG`），所以放在卡片里也是卡片色，不会出现
  白色补丁——光栅器没有描边原语，圆环/边框是用「外圈色 + 内缩底色」
  两层圆角矩形/圆拼出来的。
- 滑块高 32 dp，宽度由父容器决定（column 铺满 / row 给 `weight(1)` /
  独立时默认 160 dp）；轨道 4 dp、两端各内缩 9 dp，拇指 16 dp，
  按下时 18 dp。已完成段与拇指用 `PRIMARY`、剩余轨道 `SCROLLBAR`。
- 滑块的输入在 `handle_motion` 里被完全接管：DOWN 先按位置取值并回调，
  之后 MOVE 实时更新（再次回调），UP / CANCEL 结束手势；拖动不会触发
  外层 scroll 的拖动，回调里用 `aui_slider_value(key)` 读当前值即可。
  吸附按四舍五入到最近的 `step` 倍数，但 0 与 1000 始终可达。
- 三者都不在库里保存状态（`aux2` 只存构造时的初值与步长），每帧由
  应用传入；`aui_slider_value(key)` 在非拖动时回读节点上的值，所以
  同一个函数既能用于拖动中也能用于普通查询，未找到节点返回 -1。

分段控件（v1.21）：

```aster
// selected 是当前下标（0 起，越界自然没有胶囊）；回调挂在容器上。
aui_segmented(60, a.unit, on_unit, user);
aui_segment(61, "cm");
aui_segment(62, "in");
aui_end();

fn on_unit(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.unit = aui_segmented_value(60);   // 刚点中的段下标
    aui_invalidate();
    return 0;
}
```

- 外观照搬 HuxerUI 的 `SegmentedButtonStyle` 默认值：`SURFACE` 底、8 dp 圆角、
  1 dp `HINT` 边框；选中段画 `PRIMARY` 胶囊（按下 `PRIMARY_DARK`），未选段
  按下画 `PRESSED` 胶囊，胶囊四周内缩 2 dp、圆角 6 dp。选中段标签用
  `ON_PRIMARY`，其余用 `TEXT`；标签单行居中。
- 每段等宽（Q16.16 直接除，最后一段吃掉除不尽的余数）；段高
  `max(文字行高 + 14dp, 32dp)`，段宽最少 48 dp；容器高度取最高的一段。
- 放在 column / scroll 里铺满可用宽度；放在 row / stack 里保持固有宽度
  `pad*2 + Σ段宽`，所以可以和标签排在一行。
- 段会复制容器的回调与 `user`，点按走通用 clickable 路径：UP 时先写入
  「容器 key + 段下标」再回调，回调里用 `aui_segmented_value(容器key)` 读；
  点已选中的段同样回调（与 HuxerUI 的按钮语义一致），应用自己决定是否
  忽略重复值。`aui_segmented_value` 找不到容器时返回 -1。
- 和复选/单选/滑块一样，选中状态由应用持有，库不保存；拖动超过 8 dp
  会进入滚动并取消按压，不会误选中。

标签页（v1.22）：

```aster
// selected 是当前页下标；页内容由应用按当前下标自行渲染。
aui_tabs(10, a.tab, on_tab, user);
aui_tab(11, "Feed");
aui_tab(12, "Stats");
aui_tab(13, "More");
aui_end();

fn on_tab(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.tab = aui_tabs_value(10);   // 刚点中的页下标
    aui_invalidate();
    return 0;
}
```

- 外观照搬 HuxerUI 的 `TabsStyle` 默认值：背景透明（只有设了 `aui_bg`
  才画圆角底）、无分隔线；选中页标签 `PRIMARY`、其余 `TEXT`；当前页底部
  一条 2 dp `PRIMARY` 指示条（宽度 = 该页宽、圆角 1 dp，
  `TabIndicatorSizing::Item`）。
- 页宽 = 文字宽 + 24 dp（左右各 12 dp 内边距），最少 48 dp；页高 =
  `max(文字行高 + 16dp, 36dp)`；容器高取最高一页。纵向容器里容器铺满
  可用宽度，但页按固有宽度从左排列（`expand_items=false`），超出的部分
  被裁剪；row/stack 里容器保持固有宽度 `pad*2 + Σ页宽`。
- 点按页走通用 clickable 路径：UP 时先写「容器 key + 页下标」再回调，
  回调里用 `aui_tabs_value(容器key)` 读；点已选中页同样回调（应用自己
  决定是否忽略），容器本身的空白区域不接收点击。`aui_tabs_value`
  找不到容器时返回 -1。和分段一样，选中状态由应用持有，库不保存。

分页（v1.24）：

```aster
// selected 是当前页下标，页子项必须是 aui_page；容器占满父容器宽度，
// 每页与视口同宽，左右滑动只回调相邻页。
aui_pager(20, a.page, on_page, user);
aui_weight(1);

aui_page(21);
aui_pad(16);
aui_label(22, "First page");
aui_end();

aui_page(23);
aui_pad(16);
aui_label(24, "Second page");
aui_end();
aui_end();   // pager

fn on_page(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.page = aui_pager_value(20);   // 松手提议的相邻页
    aui_invalidate();
    return 0;
}
```

- 所有页横向并排，第 i 页 x = 视口 x + i*页宽 − offset；offset 按容器 key
  跨帧保存，首帧直接落到 selected，之后 selected 变化或松手用 200 ms
  ease-out 吸附。绘制阶段给容器加裁剪，视口外的页不产生像素。
- 手势：DOWN 同时记分页/滚动候选，第一个 8 dp 位移决定方向；横向占优
  时分页接管并取消按压与滚动，纵向占优时交给页内的 scroll。松手时速度
  ≥ 600 px/s 按方向决定，否则位移 ≥ 35% 页宽决定；一次只提议相邻页，
  首尾不越界。CANCEL 或轻点回弹到原页，不回调。
- 只有当前页接收命中：邻页露出的部分只是画面，点它不会触发邻页按钮，
  也不会改变选中页。
- `aui_pager_value(容器key)` 在松手回调里返回提议页；回到 build 后返回
  容器上的 selected，未知 key 返回 -1。回调里改完状态记得
  `aui_invalidate()`（`ui_pager` 示例把 Tab 与分页共用一个 `s.tab`）。
- 页本身是列容器：pad/gap/bg/radius 都可用；页高 = 分页视口高。页内要
  滚动时放一个 `aui_scroll` 并给它 `weight(1)`。分页容器放在 column 里
  时通常给 `weight(1)`，否则高度取最高一页。

对话框（v1.25）：

```aster
// 只在 open != 0 时构建；子项全部放进返回的卡片，最后 aui_end() 收尾。
if (a.open != 0) {
    aui_dialog(20, a.open, on_dismiss, user);
    aui_label(21, "Delete this draft?");
    aui_label(22, "This cannot be undone.");
    aui_row(23);
    aui_gap(12);
    aui_button(24, "Cancel", on_cancel, user);
    aui_weight(1);
    aui_button(25, "Delete", on_delete, user);
    aui_weight(1);
    aui_end();   // 卡片
}

fn on_dismiss(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.reason = aui_dialog_reason();   // 1 = 点遮罩，2 = 系统 BACK
    a.open = 0;
    aui_invalidate();
    return 0;
}
```

- 对话框是**游离在根树之外**的模态层：遮罩覆盖整窗、卡片在内容区居中，
  绘制在整棵树之后，不参与页面/滚动/分页布局。同时只支持一层；重复
  调用返回 -1，`key <= 0` 或 `open == 0` 也不创建。
- 几何：遮罩 `0x99000000`（60% 黑）；卡片宽 `min(内容宽 − 48dp, 320dp)`，
  高按内容测量并夹到 `内容高 − 48dp`；默认 `pad 24dp`、`gap 12dp`、
  `radius 16dp`、`SURFACE` 底，都可在 `aui_dialog` 之后用常规修饰器覆盖。
- 关闭：点遮罩或按系统 BACK 只调一次 `cb(user)`，原因用
  `aui_dialog_reason()` 读（1 遮罩 / 2 BACK，回调返回后下一轮 build 清零）。
  卡片空白区域不关闭；卡片里的按钮走自己的回调、优先于遮罩。应用只需
  在回调里把 `open` 置 0 并 `aui_invalidate()`。
- 遮罩期间命中测试整体转到对话框：底层页面完全收不到点击，但卡片按钮
  照常工作。对话框关闭后节点与遮罩立即消失，底层恢复可点。
- 对话框内不要放 `aui_text_field`：输入焦点与键盘是根树坐标，模态层
  尚未接入。

下拉选择（v1.26）：

```aster
// 触发器是普通布局里的一行；选项紧随其后声明，只有 open != 0 时才展开。
// 同一个父容器里可以放多个 select，应用用 open 记录当前展开哪一个。
aui_select(30, s.lang, is_open(s.open, 30), "Choose a language", on_lang, user);
aui_option(31, "English");
aui_option(32, "German");
aui_option(33, "Japanese");
aui_end();

fn on_lang(user: ptr) -> i32 {
    let s: ptr<App> = user;
    let why: i32 = aui_select_reason();    // 0 触发器 / 1 选项 / 2 外部或触发器 / 3 BACK
    if (why == 0) {
        s.open = 30;                       // 展开
    } else if (why == 1) {
        s.lang = aui_select_value(30);     // 刚点中的选项下标（0 起）
        s.open = 0;
    } else {
        s.open = 0;                        // 外部 / 触发器再点 / BACK
    }
    aui_invalidate();
    return 0;
}
```

- 选项是触发器节点的子项，**始终参与 build**，这样节点数在展开/关闭时
  不变；只有 `open != 0` 时 `select_layout` 才把它们摆进锚定浮层。浮层
  宽度跟触发器，锚在触发器下方 4 dp，放不下时翻到上方，再不行就夹在
  内容区内；左右各留 8 dp、整体不超出内容区。
- 浮层高 = 可见行数 × 48 dp + 上下各 6 dp；一屏放不下时只摆前面几行，
  **没有内部滚动**（需要长列表请改用页面/分页或后续版本）。选项行
  左右各内缩 4 dp、圆角 8 dp；选中项用 TINT 底 + PRIMARY 文字，按下
  用 PRESSED 底。
- 展开期间是模态层：`hit_test(root)` 只命中触发器、浮层和选项，其他
  位置返回 -1 并触发「外部关闭」；浮层 padding 返回 -2，吞掉点击但
  不关闭。底层页面（按钮、滚动、分页）完全收不到手势。
- 关闭原因：点选项 reason=1（先用 `aui_select_value(触发器key)` 读下标
  再关）；点外部、再点触发器 reason=2；系统 BACK reason=3（在焦点与
  导航之前处理，不会 pop 页面）。应用只负责把 `open` 置 0。
- 同一时刻只展开一个：`aui_root` 重建时清空展开状态，应用 build 时
  再按 `open` 重新声明。对话框打开时下拉浮层不绘制，命中与 BACK 都
  优先给对话框。
- 触发器高 = 文字行高 + 20 dp（至少 48 dp），在 column/root/scroll 里
  撑满宽度，在 row/stack 里保持 160 dp 的固有宽度；右侧三角由 3 行
  10/6/2 dp 的矩形组成，不依赖字体。`selected` 越界时显示 placeholder
  的 HINT 色文字。

底部弹层（v1.38.0）：

```aster
// 只在 open != 0 时构建；子项放进返回的表面，最后 aui_end() 收尾。
if (s.open != 0) {
    aui_sheet(20, s.open, on_sheet, user);
    aui_label(21, "Quick actions");
    aui_slider(22, s.amount, 100, on_amount, user);
    aui_row(23);
    aui_button(24, "Cancel", on_cancel, user);
    aui_weight(1);
    aui_button(25, "Confirm", on_confirm, user);
    aui_weight(1);
    aui_end();   // 表面
}

fn on_sheet(user: ptr) -> i32 {
    let s: ptr<App> = user;
    s.reason = aui_sheet_reason();   // 1 = 遮罩，2 = BACK，3 = 下拉
    s.open = 0;
    aui_invalidate();
    return 0;
}
```

- 弹层由两个游离节点组成：全屏遮罩（类型 41，key 为 `-key`，42% 黑）
  与贴底表面（类型 42，key 为传入的 `key`）。表面宽 = 内容宽 − 32 dp、
  上限 640 dp，高按内容测量、上限为内容高的 85%；内部 `pad 20dp`、
  `gap 12dp`、顶部 `radius 14dp`，底部两角保持直角。
- 顶部中央有 32×4 dp 手柄；`aui_sheet_handle(0)` 隐藏手柄但仍保留
  32 dp 抓取区，`aui_sheet_handle(1)` 恢复。向下拖动时整块表面跟随，
  松手阈值 = `max(表面高/4, 96dp)`：未超过回弹，超过则关闭并计 reason=3。
- 打开时表面从屏底滑入（240 ms ease-out），滑入后 280 ms 内吞掉向下
  事件；关闭为即时移除，没有退出动画。与 dialog 互斥，同时只允许一层。
- 点遮罩空白处 reason=1、系统 BACK reason=2、下拉 reason=3；表面内
  的孩子照常命中。调试接口 `aui_debug_sheet` 输出
  `[x, y, w, h, 拖拽位移_px, flags]`，flags 位 0 = 手柄已隐藏。

锚定浮层（v1.39.0）：

```aster
// 只在 open != 0 时构建；默认锚在 key=10 的按钮下方、左对齐。
if (s.open != 0) {
    aui_popup(20, 10, s.open, on_popup, user);
    aui_popup_place(AUI_POPUP_BELOW, AUI_POPUP_ALIGN_START);
    aui_popup_width(160);          // 0 = 自然宽（孩子最宽 + 32 dp）
    aui_label(21, "Popup title");
    aui_slider(22, s.amount, 5, on_amount, user);
    aui_row(23);
    aui_button(24, "Cancel", on_cancel, user);
    aui_weight(1);
    aui_button(25, "Apply", on_apply, user);
    aui_weight(1);
    aui_end();
    aui_end();                     // 浮层
}

fn on_popup(user: ptr) -> i32 {
    let s: ptr<App> = user;
    s.reason = aui_popup_reason(); // 1 = 外部，2 = BACK，3 = dismiss
    s.open = 0;
    aui_invalidate();
    return 0;
}
```

- 一个游离节点（类型 43，key 为传入的 `key`），不参与页面布局；宽默认
  孩子最宽 + 32 dp，最少 96 dp、最多 360 dp，高度按内容测量并夹在内容区
  8 dp 边距内。`aui_popup_place(side, align)` 选首选方向（下/上/右/左）
  与交叉轴对齐（起/中/末）；放不下自动翻到反方向，最后整体夹进内容区。
- 也可以用 `aui_popup_at(key, px, py, ...)` 以屏幕点为锚点。浮层与
  dialog / sheet / menu / 展开的 select 互斥，同时只允许一层。
- 交互是模态的：点浮层外 reason=1、系统 BACK reason=2、
  `aui_popup_dismiss()` reason=3；内边距空白吞掉点击，内容里的按钮、
  滑块照常工作。调试接口 `aui_debug_popup` 输出
  `[x, y, w, h, side, align, reason]`，关闭时首元素为 -1。

顶部应用栏（v1.40.0）：

```aster
aui_root();
aui_column(1);
aui_weight(1);
aui_top_bar(10, title, AUI_ICON_ARROW_LEFT, on_back, user);
aui_top_bar_align(AUI_TOP_BAR_CENTER);   // 0 = 起始，1 = 居中
aui_top_bar_divider(1);                  // 底部 1 px 提示线
aui_icon_button(21, AUI_ICON_SEARCH, 0, 0, on_search, user);
aui_icon_button(22, AUI_ICON_MORE, 0, 0, on_more, user);
aui_end();                               // 应用栏
```

- 类型 44 的容器，最小高 48 dp，左右内边距 8 dp（可用 `aui_pad` 覆盖）。
  leading 是 40 dp 触控块，贴左并垂直居中；标题区间从 leading 右侧 4 dp
  开始（没有 leading 时从左边距 + 16 dp 开始），到动作区左侧 4 dp 结束。
  标题单行绘制、超出裁剪，并用偏移一次的重绘模拟粗体。
- 动作从右往左排布，间距取栏的 `gap`（默认 0），每个动作按自己的高度
  垂直居中；栏高 = max(48 dp, 最高子项高度)，内边距只作用于水平方向。`aui_top_bar_align`
  与 `aui_top_bar_divider` 只修改最近创建的应用栏。
- `title` 是常量字符串指针；`leading_icon = 0` 表示没有 leading。调试
  接口 `aui_debug_top_bar` 输出 16 个整数（像素）：
  `[x,y,w,h,align,leading_key,动作数,divider,标题区左,标题区右,leading x,
  leading 宽,标题宽,标题长度,标题 x,标题 y]`。

底部导航栏（v1.41.0）：

```aster
aui_root();
aui_column(1);
aui_weight(1);
aui_scroll(30);                          // 内容区
...
aui_end();
aui_nav_bar(10, selected, on_change, user);
aui_nav_labels(1);                       // 0 = 只显示选中项文字
aui_nav_item(11, AUI_ICON_HOME, "Home", 0);
aui_nav_item(12, AUI_ICON_SEARCH, "Search", 0);
aui_nav_item(13, AUI_ICON_SETTINGS, "Settings", 0);
aui_nav_item(14, AUI_ICON_STAR, "Star", AUI_NAV_ITEM_DISABLED);
aui_end();                               // 导航栏
```

- 类型 45 的容器 + 类型 46 的子项。栏高至少 64 dp（内容更高时随之增高），
  左右内边距默认 0（可用 `aui_pad` 覆盖）；子项等宽平分，余数给最后一项。
- 每项是 56×32 dp 的指示胶囊 + 24 dp 图标 + 一行文字，整体垂直居中。选中
  胶囊用主色 12% 透明度；未选中项按下用文字色 8%，选中项按下用主色 20%。
- `selected` 由应用控制。点未选中项时先记录 `(容器 key, 项下标)` 再调用
  容器回调，回调里用 `aui_nav_value(容器 key)` 读取请求下标；点已选中项、
  禁用项（`AUI_NAV_ITEM_DISABLED`）不回调。
- `aui_nav_labels(0)` 隐藏未选中项文字（`AUI_NAV_HIDE_UNSELECTED`），只留
  图标；`aui_nav_labels(1)` 恢复。`aui_nav_bar` / `aui_nav_labels` 只修改
  最近创建的导航栏，`aui_nav_item` 从父栏继承回调。
- 调试接口 `aui_debug_nav_bar` 输出 `[x,y,w,h,selected,项数,标签可见,内边距]`；
  `aui_debug_nav_item` 输出 `[x,y,w,h,下标,flags,选中,禁用]`。

侧边导航栏（v1.42.0）：

```aster
aui_root();
aui_column(1);
aui_weight(1);
aui_row(2);                              // 左栏 + 内容
aui_weight(1);
aui_align(3);
aui_nav_pane(10, selected, expanded, on_change, user);
aui_align(3);                            // 纵向铺满行高
aui_nav_pane_item(11, AUI_ICON_HOME, "Home", 0);
aui_nav_pane_item(12, AUI_ICON_SEARCH, "Search", 0);
aui_nav_pane_item(13, AUI_ICON_SETTINGS, "Settings", 0);
aui_nav_pane_item(14, AUI_ICON_STAR, "Star", AUI_NAV_ITEM_DISABLED);
aui_end();                               // 侧边栏
aui_scroll(20);                          // 内容列
aui_weight(1);
aui_align(3);
...
aui_end();
aui_end();                               // 行
aui_end();                               // 根列
```

- 类型 47 的容器 + 类型 48 的子项。宽度固定：收缩态 72 dp、展开态 256 dp
  （`expanded != 0`），不随可用宽拉伸，所以放进行里不会被拉满；横向内边距
  默认 8 dp（`aui_pad` 可覆盖），纵向内边距也用 `aui_pad`；每项 48 dp 高、
  等宽，项间用 `aui_gap`。高度 = 内边距 × 2 + 项高之和 + 间距，放进行里
  要 `aui_align(3)` 才会纵向铺满。
- 指示胶囊：收缩态 56×32 dp，展开态铺满项宽，半径 16 dp；选中主色 12%
  透明度，未选中项按下用文字色 8%，选中项按下用主色 20%。图标 24 dp，
  收缩态居中、展开态距项左 24 dp；文字从项左 48 dp 开始、垂直居中，
  右侧留 8 dp 并裁剪。图标/文字选中主色、未选中 hint、禁用文字色 38%。
- 选择同样由应用控制，与底部导航栏共用请求槽：点未选中项先记录
  `(容器 key, 项下标)` 再回调，`aui_nav_value(容器 key)` 读取；点已选中项、
  禁用项不回调。`aui_nav_pane_item` 从父栏继承回调。
- 调试接口 `aui_debug_nav_pane` 输出 `[x,y,w,h,selected,项数,展开,横向内边距]`；
  `aui_debug_nav_pane_item` 输出 `[x,y,w,h,下标,flags,选中,禁用]`。

可编辑组合框（v1.43.0）：

```aster
aui_combo(10, "Type a fruit name...", open, on_change, user);
if (aui_text_len(10) > 0) {            // 应用按前缀过滤后声明建议
    if (starts_with("Apple", aui_text_value(10)) != 0) {
        aui_combo_suggestion(11, "Apple");
    }
    if (starts_with("Apricot", aui_text_value(10)) != 0) {
        aui_combo_suggestion(12, "Apricot");
    }
    if (starts_with("Banana", aui_text_value(10)) != 0) {
        aui_combo_suggestion(13, "Banana");
    }
}
aui_end();                             // 组合框
```

- 类型 49 的容器：单行文本触发器，外观与 `text_field` 一致（48 dp 行高、
  至少 48 dp、上下 12 dp 内边距、10 dp 圆角），高度 = max(48 dp, 行高 +
  20 dp) + 上下内边距；纵向容器/根/滚动里铺满可用宽度，行/栈里按提示
  文字取固有宽度（至少 160 dp，右侧留 10 dp 箭头槽）。
- 文本与 `text_field` 共用按键文本池，`aui_text_set` / `aui_text_append` /
  `aui_text_backspace` / `aui_text_value` / `aui_text_len` 的 key 就是组合框
  的 key；空文本画占位符（hint 色）和右侧向下三角，聚焦时边框 2 dp 主色、
  光标一闪一闪。打开屏幕键盘用 `aui_keyboard(10)`。
- `open != 0` 时，紧随其后声明的 `aui_combo_suggestion(key, text)`（类型 50）
  进入锚在触发器下方的浮层：宽跟触发器、最大到内容区左右 8 dp 边距，每项
  48 dp、内边距 6 dp、项左右再缩 4 dp，放不下翻到上方；内容超高时只摆
  得下多少画多少。关闭时建议项不参与布局，只在 `build` 里按当前文本过滤
  后声明，库不做匹配。浮层与触发器同属半模态：展开时点触发器/浮层/外部
  照常判定，**屏幕键盘按键仍然可以点**，方便边输入边看过滤结果。
- 回调 `reason`：点触发器 `AUI_COMBO_REASON_FIELD`(0)，应用把 `open` 置 1；
  点建议 `AUI_COMBO_REASON_PICK`(1)，用 `aui_combo_value(容器 key)` 读当前
  建议序列下标，或用 `aui_combo_pick_key()` 读建议自己的 key（过滤后下标
  会变，key 更稳）；点外部或展开时再点触发器 `AUI_COMBO_REASON_OUTSIDE`(2)
  （该路径下 `aui_combo_pick_key()` 为 0）；系统 BACK
  `AUI_COMBO_REASON_BACK`(3)。与对话框/菜单/下拉/浮层/底部弹层互斥。
- 调试接口 `aui_debug_combo` 输出 `[x,y,w,h,open,建议数,内边距,聚焦]`；
  `aui_debug_combo_suggestion` 输出 `[x,y,w,h,下标,可见,按下,0]`；
  `aui_debug_combo_panel` 输出 `[x,y,w,h]`（没有展开返回 -1）。

虚拟列表（v1.45.0）：

```aster
fn bind_rows(user: ptr) -> i32 {
    let i: i32 = aui_vlist_first();        // 本帧窗口（闭区间）
    let e: i32 = aui_vlist_last();
    while (i <= e) {
        aui_vlist_row(i);                  // 只建窗口内的行
        aui_label(0, "Item");
        aui_text_i32(0, i);
        aui_end();
        i = i + 1;
    }
    return 0;
}

aui_vlist(10, 5000, 64, bind_rows, on_row, user);   // 5000 行，行高 64 dp
aui_weight(1);                                      // 占满剩余高度
aui_end();
```

- 类型 51 的容器：固定行高（`item_dp`），内容总高 = `count × 行高`，但每帧
  只为视口上下各多一行的窗口建行节点（类型 52）。行由 `on_bind` 里的
  `aui_vlist_row(index)` 创建，`aui_vlist_first()` / `aui_vlist_last()` 告诉
  应用当前该建哪几行；行宽由容器撑满，行高固定，所以未显示的行不占节点
  也不参与布局。5000 行的示例节点数仍只有几十个。
- 偏移与滚动条、裁剪、拖动、惯性完全复用 `aui_scroll`：`aui_vlist_scroll(key)`
  读当前偏移（px），`aui_vlist_scroll_to(key, px)` 程序化滚动并触发下一帧
  重建窗口。窗口按“当前偏移 + 上一帧视口高”计算，首帧用 480 dp 保守估计，
  布局后发现视口不同或窗口不足会置 `need_build` 在下一拍自动补齐。
- 虚拟列表的偏移按**整数像素**单独存（`scroll_get/set/max` 按 key 分派），
  因为 Q16.16 只能表示约 32768 px，而 5000×168 px 的内容有 84 万 px；
  其余滚动容器仍是 Q16.16。拖动/惯性对虚拟列表按 px 换算，滚动条比例、
  最大偏移、`aui_debug_scroll_max` 都返回真实像素值。
- 点行：`on_tap` 挂到每一行上，点击时库先记录 `(容器 key, 行下标)`；
  回调里用 `aui_vlist_tap_index()` / `aui_vlist_tap_key()` 读取。选中态由
  应用在 `on_bind` 里按 `index` 决定（示例给选中行铺浅蓝底）。
- 调试接口 `aui_debug_vlist` 输出 `[x,y,w,h,count,first,last,offset_px]`；
  `aui_debug_vlist_row(key, index, out)` 输出 `[x,y,w,h]`，行不在当前窗口
  时返回 -1。

虚拟网格（v1.46.0）：

```aster
fn bind_cells(user: ptr) -> i32 {
    let i: i32 = aui_vgrid_first();        // 本帧窗口（格子下标，闭区间）
    let e: i32 = aui_vgrid_last();
    while (i <= e) {
        aui_vgrid_cell(i);                 // 只建窗口内的格子
        aui_label(0, "Cell");
        aui_text_i32(0, i);
        aui_end();
        i = i + 1;
    }
    return 0;
}

aui_vgrid(10, 1000, 3, 80, 120, bind_cells, on_cell, user);  // 3 列，行高 120 dp
aui_gap(8);                  // 行间距与列间距都用它
aui_weight(1);               // 占满剩余高度
aui_end();
```

- 类型 53 的容器：`cols > 0` 固定列数；`cols <= 0` 按 `min_cell_dp` 自适应，
  列数 = `(内容宽 + 间距) / (最小格宽 + 间距)`。格宽按列数均分，行高固定
  `row_dp`，行/列间距统一用 `aui_gap`。内容总高 = `行数 × 行高 + 行间距`，
  每帧只为视口上下各多一行的窗口建格子（类型 54）。1000 格的示例节点数
  仍只有窗口规模。
- `on_bind` 里用 `aui_vgrid_cell(index)` 建格子，`aui_vgrid_first()` /
  `aui_vgrid_last()` 给出当前窗口（闭区间，**格子下标**而不是行号）。
  格子是列容器，宽高由布局统一安排；内容与选中态完全由应用按 index 现场
  生成，库不持有数据。
- 偏移、滚动条、裁剪、拖动、惯性与虚拟列表完全一致：按 key 分派到整数
  像素偏移表（`scroll_get/set/max/store_max` 新增 vgrid 分支），拖动/惯性
  的 px 换算与调试接口统一走“虚拟容器”判断。`aui_vgrid_scroll(key)` 读
  当前偏移（px），`aui_vgrid_scroll_to(key, px)` 程序化滚动并触发重建。
- 网格额外记住上一次实测的列数、间距和视口高，任何一项变化（旋转、窗口
  尺寸、`cols=0` 自适应、改 `aui_gap`）都会在下一拍重建窗口；自适应首帧
  还不知道宽度时按 1 列保守构建，布局后自动补齐。
- 点格：`on_tap` 挂到每个格子，库先记录 `(容器 key, 格子下标)` 再回调；
  回调里用 `aui_vgrid_tap_index()` / `aui_vgrid_tap_key()` 读取。
- 调试接口 `aui_debug_vgrid` 输出 `[x,y,w,h,count,cols,first,last,offset_px]`；
  `aui_debug_vgrid_cell(key, index, out)` 输出 `[x,y,w,h]`，格子不在当前
  窗口时返回 -1。

横向虚拟列表（v1.47.0）：

```aster
fn bind_items(user: ptr) -> i32 {
    let i: i32 = aui_hlist_first();        // 本帧窗口（闭区间）
    let e: i32 = aui_hlist_last();
    while (i <= e) {
        aui_hlist_item(i);                 // 只建窗口内的项
        aui_label(0, "Card");
        aui_text_i32(0, i);
        aui_end();
        i = i + 1;
    }
    return 0;
}

aui_hlist(10, 1000, 160, 0, bind_items, on_item, user);  // 项宽 160 dp，项高撑满
aui_gap(8);                  // 项间距
aui_weight(1);               // 占满剩余高度
aui_end();
```

- 类型 55 的容器：对照 HuxerUI `VirtualList.ScrollAxis(Horizontal)`。项宽
  固定 `item_w_dp`；`item_h_dp > 0` 时项高固定，传 0 则项高撑满容器内容高。
  内容总宽 = `pad*2 + count*项宽 + (count-1)*间距`，每帧只为视口左右各多
  一项的窗口建项（类型 56）。1000 项的示例节点数仍只有窗口规模。
- `on_bind` 里用 `aui_hlist_item(index)` 建项，`aui_hlist_first()` /
  `aui_hlist_last()` 给出当前窗口（闭区间）。项是列容器，宽度固定、高度
  由布局统一安排；内容与选中态完全由应用按 index 现场生成。
- 偏移同样按整数像素存（横向内容可达数十万 px），`scroll_get/set/max/
  store_max` 新增 hlist 分支；左右拖动、惯性、底部横滚动条、裁剪与虚拟
  列表一致。`aui_hlist_scroll(key)` 读偏移（px），
  `aui_hlist_scroll_to(key, px)` 程序化滚动并触发重建。
- 列表记住上一次实测的间距与视口宽，变化时下一拍重建窗口。点项时库先
  记录 `(容器 key, 项下标)` 再回调，用 `aui_hlist_tap_index()` /
  `aui_hlist_tap_key()` 读取。
- 调试接口 `aui_debug_hlist` 输出 `[x,y,w,h,count,first,last,offset_px]`；
  `aui_debug_hlist_item(key, index, out)` 输出 `[x,y,w,h]`，项不在当前
  窗口时返回 -1。

按压水波纹（v1.48.2）：

```aster
// 默认关闭；打开后按住走通用点击路径的控件时，从触点扩散一圈主色。
aui_ripple(1);

// 列表行 / 按钮 / 芯片 / 导航项等自动获得波纹，build 不需要改。
aui_button(20, "Tap", on_tap, user);

// 关闭并立即清除当前波纹（例如切换“减少动效”）。
aui_ripple(0);
```

- 状态层颜色 = 主题主色、alpha 31（约 12%），从触点向最远角扩散，320 ms
  线性（与 HuxerUI 默认 expansion 的 Linear 一致），按住时保持满 alpha；
  松手后 220 ms 线性淡出，UP/取消当拍就进入淡出。
  半径上限是“触点到控件四角的最远距离”，扩散完刚好盖住整个控件。
- 绘制发生在节点自身背景/内容之上、子树内容之下，按节点矩形、圆角与当前
  裁剪逐行扫描成条带命令；条带高 1–2 px（一屏最多约 1280 条），圆边不再
  出现粗台阶，也远低于 4096 条命令池。波纹只影响像素：命中、布局、滚动和
  点击回调完全不变。
- 无 key 的虚拟项（虚拟列表行 kind 52、网格格 54、横向列表项 56）用
  `(容器 key, 项下标)` 跟随，重建或滚动后不会画到别的项上。自带按压/
  拖动逻辑的容器（对话框、弹层、浮层、下拉、组合框、日期/时间、分页等）
  不画波纹，避免与它们自己的状态层叠加。
- 默认关闭是为了让既有界面与截图像素保持完全一致。`aui_ripple_active()`
  返回 0 空闲 / 1 按住 / 2 淡出；测试接口 `aui_debug_ripple(out)` 输出
  `[key,x,y,rad_px,alpha,phase,max_r,elapsed_ms]`。波纹由帧泵按 16 ms
  节拍推进（v1.48.2 起按“本帧开始 + 16 ms”等，绘制耗时不再叠加到周期
  上），应用不需要自己的定时器。
- v1.48.2 起，波纹帧只重画它所在的节点矩形（局部呈现），并把这个矩形
  作为 `ANativeWindow_lock` 的 dirty 区；只有波纹是唯一变化时才启用，
  波纹外有任何内容变化会自动退回整屏。接口无需改动。
- v1.48.3 起，手指拖动/列表开始滚动会立即清除波纹（不淡出），滚动帧不再
  为波纹额外绘制；有动效时输入线程也不再同步画帧，统一由帧泵出一帧。

形状抗锯齿（v1.23）：

- 所有圆角矩形、胶囊、圆（按钮、卡片、开关轨道与拇指、复选/单选框、
  单选圆点、滑块拇指、分段胶囊、标签页指示条）的边缘都按面积覆盖率
  混合：像素中心到圆心的距离每深入 1/16 px，覆盖率加 16/255，边界
  两侧各 0.5 px 内从底色过渡到前景色。
- 只处理形状的曲线边缘；直边本来就是整数像素对齐，仍是精确前景色，
  不做整屏模糊。1~2 dp 的描边（分段外框、复选边框、单选圆环）由
  「外圈色 + 内缩底色」两层图形组成，两层各自的圆角都会过渡，所以
  细环不会出现台阶或亮边。
- 半透明形状（按压态、动画 alpha）会把自身 alpha 与覆盖率相乘，
  不会出现两次混合或边缘发黑。
- **文字不做抗锯齿**：字体仍是 1bpp 位图（v1.19 的 48px 原生图集）。
  灰度/彩色字形会让 CJK 图集从 2.0 MB 涨到约 8 MB，而且会重新引入
  v1.19 已经解决的“发虚”；这一版只解决几何边缘。
- 性能：只对圆角带逐行算平方根，左右各一个边界像素走逐像素混合，
  中间区域仍是整行 `fill_run`；常见半径 4~12 px 时每行只多 1~3 次
  `isqrt`，整屏开销与 v1.22 同量级。

页面栈（路由只是一个 i32，build 里按它分支）：

```aster
fn on_open2(user: ptr) -> i32 { return aui_nav_push(2); }
fn on_back(user: ptr) -> i32  { return aui_nav_pop(); }

fn build(user: ptr) -> i32 {
    let route: i32 = aui_route();
    aui_root();
    if (route == 1) { /* 第 1 页 */ }
    else if (route == 2) { /* 第 2 页 */ }
    return 0;
}
// 系统 BACK 由库处理：有焦点先收键盘，否则 pop，根页面调
// ANativeActivity_finish 结束 Activity；应用不用自己接按键。
```

图片 / PNG（v1.13）：

```aster
let g_png: ptr = @embed("assets/icon48.png");
let g_png_len: i32 = @embed_len("assets/icon48.png");
let g_dims: i32[2] = 0;
let g_img: ptr = 0;

fn app_init(user: ptr) -> i32 {
    // 解码到库内 1 MiB 池；失败返回 0，可退回裸 RGBA。
    g_img = aui_png_decode_pool(g_png, g_png_len, g_dims);
    return 0;
}

// build 里：宽高来自 g_dims（RGBA8888，每行 w*4 字节，无 padding）
aui_image(11, g_img, g_dims[0], g_dims[1]);

// 或者自己管理内存（out 至少 w*h*4 字节）：
// let rc: i32 = aui_png_decode(g_png, g_png_len, buf, cap, g_dims);
// 0 成功 / -1 不是 PNG / -2 格式不支持 / -3 缓冲不够 / -4 数据损坏。
```

- 支持 8 位、非隔行的灰度、真彩、调色板、灰度+alpha、RGBA，以及灰度/
  真彩/调色板的 `tRNS` 透明；16 位与隔行返回 -2。
- 自己实现 zlib/deflate：stored / fixed / dynamic 三种块，5 种行过滤器
  （None/Sub/Up/Average/Paeth），IDAT 可拆成任意多段（≤32 段）。
- 内存全部是库内固定数组：32 KB 行缓冲 + 32 KB 上一行 + 32 KB 回溯环，
  行宽上限 32768 字节（RGBA 约 8192 px）；池总量 1 MiB（512×512 RGBA）。
- 不校验 CRCs（资源可信），但每处长度与下标都做边界检查，坏数据返回 -4。
- `aui_png_pool_reset()` 只有在确定旧图不再绘制后才能调用。

系统适配 / 主题（v1.9）：

```aster
// build 里直接用主题角色，深浅色会自动换色：
aui_bg(aui_theme_color(AUI_COLOR_SURFACE));
aui_label(1, "AsterUI");

// 需要按主题分支时：
if (aui_dark() != 0) { aui_label(2, "dark"); }

// 手动切换主题（仅本库，不改系统设置；下次配置变化会被系统夜间模式覆盖）：
aui_set_dark(1);

// 内容区安全距离（单位 dp，已扣除状态栏/导航栏/刘海）：
let l: i32 = aui_safe_left();
let t: i32 = aui_safe_top();
```

Android 15 edge-to-edge（v1.14）：

```aster
// targetSdk 35 起系统强制 edge-to-edge，onContentRectChanged 会给出整窗，
// 状态栏/导航栏直接压在内容上。NDK 没有 WindowInsets 查询接口、也不允许
// JNI，库在 API 35+、内容区等于整窗、且应用未声明铺满时，按 24 dp 估算
// 上/下系统栏，根节点自动避开。
// 需要更精确的避让（刘海、挖孔、三键导航）时：
aui_set_insets(0, 40, 0, 0);   // 四边最小安全区（dp），与系统/估算值取较大者
aui_edge_to_edge(1);           // 0 = 恢复自动估算；1 = 铺满整窗，自己排版
// 注意：估算只影响根节点布局，点击仍可落到系统栏区域之外；
// 应用在 build 里读 aui_safe_* 即可拿到本帧将使用的值。
```

系统栏条带（v1.15）：

```aster
// Android 的系统栏图标在本库的默认主题下是浅色，而 edge-to-edge 的
// 条带又直接露出应用背景；浅色背景上的白色时间/电量几乎看不见。
// v1.15 在有安全区时先铺深色条带，再把内容区铺回主题底色：
//   AUI_COLOR_SYSTEM_BAR = 0xFF1B1B1F（浅色主题）/ 0xFF050507（深色主题）
// 需要换色（例如跟随品牌色）或关掉条带时：
aui_set_system_bar(aui_theme_color(AUI_COLOR_PRIMARY_DARK)); // 自定义
aui_set_system_bar(0);                                        // 0 = 跟随主题
aui_set_system_bar(aui_theme_color(AUI_COLOR_BG));            // 关掉条带
let c: u32 = aui_system_bar_color();                          // 当前生效色
```

公共主题角色：`AUI_COLOR_BG`、`SURFACE`、`PRIMARY`、`PRIMARY_DARK`、
`TEXT`、`ON_PRIMARY`、`HINT`、`PRESSED`、`TINT`、`SCROLLBAR`、
`KEYBOARD_BG`、`SYSTEM_BAR`，用 `aui_theme_color(role)` 取当前色。根节点
由库自动排进 `onContentRectChanged` 给出的内容区；API 35+ 且内容区等于
整窗时再按 24 dp 估算上下系统栏（见上一节）；有内缩时先铺系统栏条带、
再铺内容区底色，点击在内容区之外不会命中任何控件。旋转/分屏由
`onNativeWindowResized` 触发整树重建；density 与夜间模式在 attach 和
`onConfigurationChanged` 时从 `AConfiguration` 读取。

动画（v1.10）：

```aster
// 在 build 里、或按钮回调里创建；key 与要动的节点 key 相同。
// 64 个槽按 (key, prop) 寻址；动画只影响绘制，不重建、不重新布局。
aui_anim(100, AUI_ANIM_ALPHA, 0, 255, 280, AUI_EASE_OUT); // 淡入
aui_anim(100, AUI_ANIM_TY, 18, 0, 280, AUI_EASE_OUT);     // 上滑 18 dp

// 同一 key 再次调用且目标不变时保留进度（build 每帧调用也不会重置）。
// 重播：先删槽回到默认值（alpha=255，tx/ty=0），再重新创建。
aui_anim_reset(100, AUI_ANIM_ALPHA);
aui_anim_reset(100, AUI_ANIM_TY);

let a: i32 = aui_anim_value(100, AUI_ANIM_ALPHA); // 当前值（0..255）
let n: i32 = aui_anim_active();                   // 活动槽数量
```

- 属性：`AUI_ANIM_ALPHA`（0..255）、`AUI_ANIM_TX`/`AUI_ANIM_TY`（dp）。
- 缓动：`AUI_EASE_LINEAR`、`AUI_EASE_OUT`（`1-(1-t)^2`）、
  `AUI_EASE_IN_OUT`（`3t^2-2t^3`）。
- 帧由库内 16 ms `timerfd` 驱动（与滚动 fling 共用），应用不用自己刷帧；
  `onPause/onStop` 停表，`onResume` 恢复。后台期间进度不暂停，
  恢复后会直接落到按当前时间计算的位置。
- 透明度与位移沿子树继承；滚动视口的裁剪会跟随容器当前的绘制位移。
- 槽满 64 个且都在运行、或 key <= 0 时返回 -1。

页面转场（v1.11）：

```aster
// 在 app_init 里开启（默认 0 = 关闭，行为与 v1.10 完全一致）：
aui_nav_transition(240);      // 0..1000 ms；0 立即回到直切

// 之后 push/pop/reset 自动播放；需要时查询是否在转场中：
if (aui_nav_busy() != 0) { /* 返回键可置灰 */ }
```

- push：旧页左移淡出、新页从右滑入；pop 反向；reset 只做交叉淡入。
- 转场期间不派发点击、BACK 被吞掉（避免连跳），到时自动结束。
- 旧页来自上一帧绘制命令的快照（含深拷贝的文字），不保留旧节点树；
  快照上限 2048 条命令 / 48 KB 文本，超出自动退化为直切。
- 与动画/fling 共用帧泵的 16 ms 节拍；`onPause/onStop` 停帧，`onResume` 恢复。
- 默认关闭：现有应用不调用 `aui_nav_transition` 时导航与 v1.10 相同。
- v1.11.1 的两条硬保证：`frame_timer_arm()` 失败（无 looper / timerfd 创建、
  addFd、settime 失败）时**不进入转场**，直接直切；即使定时器一次都不回调，
  输入事件到达时只要已超过时长就立即收尾并照常处理该事件，连续一次转场期间
  一帧都没来且已超时 250 ms 则永久降级为直切。轨迹里用 `a` / `e` 两个标记
  记录转场启动状态（0 已启动，1..4 定时器失败阶段，5 快照超限，6 已降级）
  与结束原因（1 定时器帧，2 输入看门狗，3 绘制路径，4 取消）。
- v1.11.2 起 trace 第二行写 `V` + 版本号（本版 `V000039D6` = 1.48.6；v1.48.5 是 `V000039D5`；v1.48.4 是 `V000039D4`；v1.48.3 是 `V000039D3`；v1.48.2 是 `V000039D2`；v1.48.1 是 `V000039D1`；v1.48.0 是 `V000039D0`；v1.47.0 是 `V0000396C`；v1.46.0 是 `V00003908`；v1.45.0 是 `V000038A4`；v1.44.0 是 `V00003840`；v1.43.0 是 `V000037DC`；v1.42.1 是 `V00003779`；v1.41.0 是 `V00003714`；v1.40.0 是 `V000036B0`；v1.39.0 是 `V0000364C`；v1.38.0 是 `V000035E8`；v1.37.0 是 `V00003584`；v1.36.0 是 `V00003520`；v1.35.0 是 `V000034BC`；v1.34.0 是 `V00003458`；v1.33.0 是 `V000033F4`；v1.32.1 是 `V00003391`；v1.32.0 是 `V00003390`；v1.31.0 是 `V0000332C`；v1.30.1 是 `V000032C9`；v1.30.0 是 `V000032C8`，v1.28 是 `V00003200`；
  v1.26.2 是 `V0000313A`；v1.26.1 是 `V00003139`；v1.25 是 `V000030D4`；v1.24 是 `V00003070`；v1.23 是 `V0000300C`；v1.22 是 `V00002FA8`；v1.21 是 `V00002F44`；v1.20 是 `V00002EE0`；v1.19 的源码里这一行误写成 11800，包实际显示
  `V00002E18`，与 `aui_version()` 11900 不一致——v1.19 文档里的
  `V00002E7C` 是按 11900 推的，并没有在真机上出现过；v1.20 已修正），
  一眼分辨跑的是不是新包。
- **v1.12.0 换了帧源**：真机证明 `timerfd` 挂在 UI 线程 looper 上时，
  looper 空闲就收不到回调（只有输入把它叫醒后才偶尔来一帧），转场必停在
  旧页。现在由**独立线程（帧泵）**按 16 ms 调 `aui_frame`，不再依赖 looper；
  绘制与输入用一把互斥锁串行化，窗口创建/销毁/尺寸变化仍只在 UI 线程。
  帧泵起不来（pipe / pthread_create 失败）或还没跑出第一帧时，导航直接
  切页（`a7`），不会停在半截转场。
- **v1.12.1 收紧“帧”的定义**：只有 `present` 真正成功（`g_aui_paint_seq`
  变化）才计入帧数；窗口锁失败的帧不再骗过首帧门，也不会让输入看门狗
  误以为帧源还在跑。瞬时失败下一拍重试，连续约 2 s 失败则永久直切
  （trace `Y1` / `Y2`）。

关键约定：

- 容器必须 `aui_end()`；根不需要。
- 修饰函数（`aui_pad/gap/weight/align/bg/radius`）作用在**最近创建**的节点上，
  所以要写在节点创建之后、下一个节点之前。
- 单位是 dp，布局内部是 Q16.16 像素；文本是预生成位图字体（拉丁 8x8 +
  可选 16x16 CJK 回退），不支持 TTF / 整形 / emoji。
- 组件状态请放应用自己的 `user` 结构体，或 `aui_state_set/get`（按 i32 key）。
- 回调里改完状态必须 `aui_invalidate()`。
- `aui_scroll(key)` 需要一个确定的高度：放在 column 里时给 `weight(1)`，
  否则视口高度等于内容高度、无法滚动；滚动容器内的子节点按固定高度排列，
  `weight` 暂不分配剩余空间。
- `aui_pager(key, selected, cb, user)` 的子项必须是 `aui_page`；放在 column
  里通常给 `weight(1)`，否则容器高度取最高一页。页高 = 分页视口高，页内
  要滚动时放 `aui_scroll` + `weight(1)`；`selected` 与 Tab 一样由应用保存，
  横滑回调里用 `aui_pager_value(key)` 读提议页。
- `aui_dialog(key, open, cb, user)` 只在 `open != 0` 时调用，子项放进卡片、
  用 `aui_end()` 收尾；遮罩/BACK 关闭时在 `cb` 里读 `aui_dialog_reason()`
  并把 `open` 置 0。卡片 key 就是传入的 `key`（必须 > 0），遮罩用 `-key`；
  只支持一层，且不要在里面放文本字段。
- 文本字段和键盘不需要应用自己保存文本：库内按 key 存在 32 槽池里
  （每槽 63 字节，UTF-8，约 21 个汉字），树重建不会丢；`aui_text_value`
  返回的指针在下一次修改前有效。
- 键盘是普通节点（key 7000/7001–7004/9000+），点击由 AsterUI 内部转成
  编辑动作；应用只负责决定何时调 `aui_keyboard(target)`。
- 页面栈固定 8 层，路由是 i32；`aui_nav_push/pop/reset` 会清焦点并同步
  重建（返回 0 成功，-1 表示超限或已在根）。根页面按 BACK 会结束 Activity，
  应用无法拦截；需要「再按一次退出」等逻辑请自己在 build 里放按钮。
- 根节点会自动避开内容区，应用一般不需要再手动加状态栏高度；如果确实
  要自己排版，可读 `aui_safe_*`（dp，向下取整）。内容区回调在某些 ROM 上
  可能滞后一帧，库会在每次回调时整树重建。
- 主题色通过角色取，不要在应用里写死深浅两套色；自定义背景用
  `aui_theme_color(...)` 的结果作为 `aui_bg` 参数。`aui_set_dark` 只影响
  AsterUI 的调色板，不改变系统状态栏图标颜色。
- 动画 key 必须 > 0，且与目标节点的 key 一致；动画值只作用于绘制，
  命中测试仍按布局位置。重播前先 `aui_anim_reset`，否则相同目标的
  第二次调用会保留进度、不会重新开始。
- 页面转场只在 push/pop/reset 时触发，转场期间新页面的点击会被丢弃；
  如果页面里有一进页面就要响应的操作，请放在 build 或 `aui_invalidate`
  之后，不要依赖转场中间的用户输入。
- 库的全局符号全部导出，所以库内统一 `g_aui_` / `AUI_` 前缀。

## 启动轨迹（无 adb 时定位闪退）

`aui_android_attach` 会在应用外部数据目录写 `trace.txt`：

```
/storage/emulated/0/Android/data/<包名>/files/trace.txt
```

每行一个里程碑（单字母，或字母 + 8 位十六进制）：

| 行 | 含义 |
|---|---|
| `S` | 进入 attach（trace 文件已打开） |
| `V` + 版本 | trace 第二行：库版本（本版 `V000039D6` = 1.48.6；v1.48.5 是 `V000039D5`；v1.48.4 是 `V000039D4`；v1.48.3 是 `V000039D3`；v1.48.2 是 `V000039D2`；v1.48.1 是 `V000039D1`；v1.48.0 是 `V000039D0`；v1.47.0 是 `V0000396C`；v1.46.0 是 `V00003908`；没有这一行就是旧包；v1.45.0 是 `V000038A4`；v1.44.0 是 `V00003840`；v1.43.0 是 `V000037DC`；v1.42.1 是 `V00003779`；v1.41.0 是 `V00003714`，v1.40.0 是 `V000036B0`，v1.39.0 是 `V0000364C`，v1.38.0 是 `V000035E8`，v1.37.0 是 `V00003584`，v1.36.0 是 `V00003520`，v1.35.0 是 `V000034BC`，v1.34.0 是 `V00003458`，v1.33.0 是 `V000033F4`，v1.32.1 是 `V00003391`，v1.32.0 是 `V00003390`，v1.31.0 是 `V0000332C`，v1.30.1 是 `V000032C9`，v1.30.0 是 `V000032C8`，v1.28 是 `V00003200`，v1.27 是 `V0000319C`，v1.26.2 是 `V0000313A`，v1.26.1 是 `V00003139`，v1.26 是 `V00003138`，v1.25 是 `V000030D4`，v1.24 是 `V00003070`，v1.23 是 `V0000300C`，v1.22 是 `V00002FA8`，v1.21 是 `V00002F44`，v1.20 是 `V00002EE0`，v1.19 的包会显示 `V00002E18`，文档曾误写为 `V00002E7C`） |
| `O` + sdkVersion | `ANativeActivity.sdkVersion`（低 16 位）；API 35+ 才启用 edge-to-edge 安全区估算 |
| `d` + density | AConfiguration 读取完成（attach / resume / 配置变化，Q16.16） |
| `u` + night | `AConfiguration_getUiModeNight` 返回值：0 = ANY，1 = NO，2 = YES |
| `m` + 0/1 | `aui_set_dark` 实际改变了主题（0 浅 / 1 深） |
| `q` + 毫秒 | 转场帧耗时：泵线程一帧的绘制 + present（只在转场中写） |
| `w` + 毫秒 | `ANativeWindow_lock` 的等待时间（v1.48.4 起每帧都写，含等空闲缓冲） |
| `C` + 毫秒 | 光栅耗时：`draw_cmds` 从第一条命令到最后一条（v1.48.4） |
| `t` + 毫秒 | 提交耗时：`ANativeWindow_unlockAndPost`（v1.48.4） |
| `X` + 打包值 | 局部呈现实际重画宽高（v1.48.4，仅局部帧）：`宽 << 12 \| 高`；`X00000000` = Surface 拒绝局部，整屏重画 |
| `I` | 应用 `init` 完成（`aui_set_font` 等） |
| `K` | NativeActivity 回调表装好 |
| `W` | 窗口创建回调进入 |
| `r` / `s` + 像素 | 窗口宽 / 高（窗口创建与 resize 时） |
| `i` / `j` / `o` / `p` + 像素 | 内容区 left / top / right / bottom（`onContentRectChanged`） |
| `E` + 打包值 | edge-to-edge 估算生效时写一次：高 16 位 = 上内缩像素，低 16 位 = 下内缩像素（如 `E000300030` = 48/48 px）；`E00000000` = 估算关闭 |
| `A` + 0/1 | 进入输入队列回调时线程是否已有 NDK looper（1 = 有） |
| `B` | `forThread` 为空，已调用 `ALooper_prepare` |
| `Q` + 返回值 | `AInputQueue_attachLooper` 的结果（0 = 成功） |
| `T` + action | 收到触摸：0 = DOWN，1 = UP，2 = MOVE |
| `x` / `y` + 坐标 | 触摸像素坐标（来自 `AMotionEvent_getX/Y` 的 float 桥） |
| `v` + 偏移 | 滚动偏移变化（Q16.16 px，拖动/惯性时每次变化一行） |
| `g` + 速度 | fling 开始，初速度 Q16.16 px/s（正 = 偏移增大） |
| `h` + 0 | fling 结束（自然减速 / 撞边界 / 被按下打断） |
| `k` + keycode | 收到按键 DOWN；v1.8 只处理 BACK（4），动作在 UP 执行 |
| `n` + route | 路由变化（push/pop/reset 之后的新 route） |
| `J` + 0/1/2 | 帧泵（v1.12）：0 = 线程就绪；1 = `pipe2` 失败；2 = `pthread_create` 失败（后两种此后一律直切） |
| `a` + 状态 | 转场启动：0 = 已启动并在跑；2 = 帧泵不可用；5 = 快照池满；6 = 已降级，直接切换；7 = 首帧还没出来 / 帧泵不可用，本次直切 |
| `e` + 原因 | 转场收尾：1 = 帧泵跑完；2 = 输入看门狗超时收尾；3 = 绘制路径发现已超时；4 = 被取消（新导航/暂停/恢复） |
| `Z` + 帧数 | 本次转场实际出了多少帧（只有真正启动过转场才写；12~15 = 240 ms 正常） |
| `Y` + 0/1/2 | 帧泵 present：0 = 首帧成功（每台新窗口一次）；1 = 首次窗口锁失败；2 = 连续失败约 2 s，永久直切 |
| `b` | 根页面按 BACK，准备结束 Activity（`ANativeActivity_finish`） |
| `N` + 节点数 | 构建树完成 |
| `L` | 布局完成 |
| `P` + 命令数 | 绘制列表拍平完成 |
| `F` | `present`（lock → 光栅 → unlockAndPost）完成 |
| `R` | 重绘回调进入 |
| `X` | 正常销毁 |

文本输入不新增轨迹字母：一次有效按键（焦点/字符/退格/模式切换/收起）会触发
一次 `N L P F`，按 `T`/`x`/`y` 定位到具体触点即可。

进程闪退后最后一行就是崩溃/卡住的位置。实现只用 `openat/write` 原始系统调用
（无 Java、无 JNI），打不开文件时静默跳过。

`probe1` 不经过 AsterUI，自己写一份更早的轨迹：

```
/storage/emulated/0/Android/data/dev.aster.probe1/files/p1.txt
```

另有更早的一层：`__aster_init`（INIT_ARRAY，`dlopen` 成功后、onCreate 之前）
写 `p1boot.txt`，内容 `B`。因此：

- 连 `p1boot.txt` 的 `B` 都没有 = 仍卡在 `dlopen`；
- 有 `B` 没有 `p1.txt` 的 `A` = `.so` 已加载、init 已运行，崩溃在两者之间；
- `A` = onCreate 已进入、`K` = 回调表装好、`W` = 窗口创建、
  `F` = 首帧已提交、`R` = 重绘。

## 诊断 APK

- `probe1-red.apk`（`dev.aster.probe1`）：裸 NativeActivity，打开即整屏纯红，
  同时写 `p1.txt`。红屏 + `A K W F` = 打包 / `.so` 加载 / 回调表 / 窗口锁全部正常。
- `probe2-text.apk`（`dev.aster.probe2`）：AsterUI 最小界面，深灰底两行浅色字。
  有字 = AsterUI 核心（布局 / 光栅 / 字体）正常。

两者与主包不同包名，可共存。

## 实现要点

- 固定池：节点 4096 × 96 B、命令 4096 × 64 B，全部在 `.bss`，无堆、无 mmap。
- 文本（v1.16）：UTF-8 逐码点遍历；主字体查不到时查回退字体
  `g_aui_font2`，两套字体各带缩放（拉丁 8x8 × 2、CJK 16x16 × 1）。
  字形宽度 1–8 px 每行 1 字节，9–16 px 每行 2 字节，光栅器按 `w/h`
  选择行字节数；行高与字形高度取两套字体的较大者。`aui_text_append`
  按 UTF-8 写 1–4 字节，退格删掉整个码点；文本池仍是 63 字节/槽。
- 布局：Q16.16 定点；column/row/stack、`pad/gap/weight/align`、文本换行（按字符边界）。
- 绘制：先拍平成 64 B 命令数组（含裁剪矩形），再一次遍历软件光栅；光栅入口统一
  Q16.16 → 像素；支持 RGBA_8888 / RGBX_8888 / RGB_565。
- 抗锯齿（v1.23）：`fill_rect` 的圆角带按像素中心到圆心的距离求覆盖率
  （1/16 px 步进，1 px 线性过渡），左右边界像素用 `blend_px` 混合，
  中间整行仍是不透明写入；覆盖率先乘颜色 alpha。只在半径 > 0 时生效，
  直边与整屏底色填充保持原路径。
- 输入：主线程 looper 上挂 `AInputQueue`；`AINPUT_EVENT_TYPE_MOTION = 2`（不是 KEY 的 1）；
  坐标经 `lrintf` 桥取整，按 key 命中与按压。
- 滚动：`aui_scroll` 是视口；内容整体上移 `scroll_y`，偏移按 key 存在 64 槽表里
  （每帧重建树也不会丢），拖动超过 8 dp 才进入滚动并取消按压态；子树所有绘制
  命令带上视口裁剪矩形，光栅阶段丢弃越界像素。
- 惯性：`MOVE` 的 `dy/dt`（`clock_gettime(CLOCK_MONOTONIC)`）产生速度，低通后
  在 `UP` 时启动；`timerfd` 按 16 ms 触发，经 `ALooper_addFd` 回到 UI 线程调
  `aui_frame`，速度每 16 ms 衰减 15/16，撞边界或低于阈值即停。按下立即打断。
  计时器创建失败时直接放弃 fling，不影响滚动本身。
- 滚动条：内容超出视口时在右侧 3 dp 宽轨道上画不透明灰色滑块，长度按
  `视口/内容` 比例、最小 24 dp，位置随偏移等比移动；不参与命中测试。
- 分页（v1.24）：节点类型 21（容器）/ 22（页），偏移按 key 存在 32 槽表
  里，与 scroll 的 64 槽表分开（滚动偏移要 clamp 且带惯性，分页要允许
  指尖超界并回弹）。布局把每页排成视口宽、横向错开 offset；绘制时
  kind 21 追加容器裁剪命令。方向锁在 MOVE 里做：8 dp 内不动作，超过后
  比较 |dx|/|dy|，横向则取消 scroll 候选并更新 offset，纵向则让 scroll
  继续。松手提议只读相邻页，200 ms ease-out 由 `pager_step` 驱动，动画
  期间置 need_layout/need_paint，与 fling/页面转场共用帧泵。命中测试对
  kind 21 只下钻 selected 页，邻页露出的边缘不会误触。
- 页面栈：`g_aui_nav_stack[8]` 存 i32 route，`g_aui_route_key` 是当前路由；
  push/pop/reset 清键盘焦点、写 `g_aui_need_build` 并同步重建树。
- 系统内容区：`onContentRectChanged`（回调偏移 104）保存原生像素矩形；
  布局时把根节点排进内容区，记录四边 Q16.16 内缩；绘制时若存在内缩，
  先追加一条全屏底色命令填状态栏/导航栏区域，再画根节点。命中测试从
  根节点开始，所以内容区外的触点自然不会命中控件。
- edge-to-edge（v1.14）：`calc_insets()` 在 build 前和布局前各算一次，
  综合内容区、`sdkVersion >= 35` 的 24 dp 上下估算、`aui_set_insets`
  的应用下限，取较大者；`aui_edge_to_edge(1)` 只关估算、不清应用下限。
  内缩之和超过窗口时整体归零，避免内容区被挤成负数。估算状态变化时写
  一条 `E` 轨迹；`aui_safe_*` 从 `g_aui_inset_*` 取本帧值。
- 系统栏条带（v1.15）：API 35+ 有安全区时先铺一条全屏
  `AUI_COLOR_SYSTEM_BAR`，再在内容区铺 `AUI_COLOR_BG`，让系统栏的浅色
  图标落在深色上；`aui_set_system_bar(color)` 改条带色，0 = 跟随主题。
  这条路径只增加两条矩形命令，不影响布局与命中。
- 旋转/分屏：`onNativeWindowResized`（偏移 64）重新读窗口宽高并整树重建
  （应用可能在 build 里按宽高分支）；`onWindowCreated` 也一样，并清掉旧
  内容区等新回调。
- 密度/深色：attach、`onResume` 与 `onConfigurationChanged`（偏移 112）时用
  `AConfiguration_new/fromAssetManager/getDensity/getUiModeNight` 读取；密度换成
  Q16.16（dpi/160），night 返回 2（`NIGHT_YES`）即深色。注意 NDK **没有**
  `AConfiguration_getUiMode`，且 `AConfiguration_fromAssetManager` 返回 void，
  不能检查返回值。构建门禁会拒绝前者这类不存在的导入。
- 主题：12 个公共角色（0..11）集中在 `theme_color(role)`，组件内部
  （按钮、字段、提示、按压、滚动条、键盘）全部走角色；应用自定义背景用
  `aui_theme_color`。`aui_set_dark` 只改库内调色板并触发整树重建。
- 安全区 API：`aui_safe_left/top/right/bottom` 返回 dp（向下取整），即本帧
  布局实际使用的内缩；没有内容区回调且未启用估算、也没有应用下限时返回 0。
- 动画：64 槽按 `(key, prop)` 存 alpha/tx/ty，与滚动一样跨 rebuild 保留；
  `paint_node` 把值乘进 `g_aui_paint_alpha`、加进 `g_aui_paint_dx/dy`，
  `cmd_add` 统一叠加到命令上，子树自动继承。`fill_run` 在 alpha=255 时
  仍走整行写入，半透明才逐像素 `blend_px`；文字/图片按命令 alpha 缩放。
  帧与 fling 共用同一个 16 ms timerfd，两者都空闲才停表。
- 页面转场：导航时把当前 64 B 命令数组复制到 2048 条快照池（`g_aui_page_pool`），
  文字命令逐条深拷贝到 48 KB 文本池（新 build 会覆盖节点文本池）；绘制时先铺
  不透明底色，再按 `1-(1-t)^2` 计算旧/新两层 alpha（各 0..255）与水平位移
  （20 dp），旧页 op 用快照、新页用当前列表；`page_step` 到时清标志并停表。
  输入层在 `handle_motion`/`handle_key` 最前面检查 `g_aui_page_on`。
- 按键：`AInputEvent_getType == 1` 走 `AKeyEvent_getAction/getKeyCode`；
  只消费 BACK（4）：DOWN 只记轨迹，UP 才做焦点 → pop → finish 三级决策
  （避免长按重复 DOWN 连跳多页），其他键返回 0 且
  `AInputQueue_finishEvent` 的 handled 传 0，交还系统。
- 文本字段：节点类型 10，文本存 32 槽池（key → 63 B UTF-8），聚焦时底部
  2 dp 主色线 + 2 dp 光标；提示文字在为空时显示。键盘是普通节点类型 11，
  每键一个 2 字节标签槽（`g_aui_kb_glyphs`，槽号 = key − 9000），避免所有
  键共用同一缓冲区导致字母串台。QWERTY 行 9000–9049、`DEL` 9029、
  底部 `123/ABC` 9060、`SPACE` 9061、`DONE` 9062；`SHIFT` 只影响字母大小写。
- 开关 / 进度条（v1.17）：节点类型 12 / 13，都是叶子。开关固定 44×24 dp，
  `aux` 存开/关（应用每帧传入），绘制两条圆角矩形（轨道 + 滑块，滑块直径
  18 dp、内缩 3 dp，开时靠右）；进度条高 8 dp、`aux` 存千分比 0..1000，
  绘制轨道 + 已完成段，填充宽度用 64 位中间量 `i64(w) * v / 1000` 计算
  （Q16.16 的宽度直接乘 500 会溢出 i32），非零时至少一个圆角直径。
  两者都走普通命中测试，开关的 `cb(user)` 在抬起时调用。
- PNG 解码：`png_begin` 只读头并定位 IDAT（≤32 段），`png_run` 逐行推进——
  `png_next_byte` 跨段取位、`png_inflate`（stored/fixed/dynamic）把字节同时
  写进 32 KB 回溯环和当前行，行满后 `png_unfilter`（0..4，Paeth 用 32 位中间
  量避免溢出）原地还原、`png_expand_row` 按色型与 `tRNS` 展开成 RGBA、拷到
  `prev` 供下一行 Up/Average/Paeth 使用。Huffman 用 puff 式 counts+symbols
  表（MSB-first 逐位累积），距离附加位按 RFC 1951 生成（码 0..3 无附加位，
  之后 `i/2-1`）。所有缓冲都是 `.bss` 固定数组，无堆分配。
- 呈现：`ANativeWindow_lock` 写入后 `unlockAndPost`；全量重绘。
- 离屏：`aui_headless_init` + `aui_headless_render`，不需要 Android 宿主。
- 轨迹：`openat/write` 原始系统调用写外部数据目录，无 adb 也能定位崩溃阶段。

## 已验证 / 未验证

已验证：编译、链接、打包、签名校验、无 dex、16 KB 对齐补丁前后对比；
`tools/check_so.py` 对十个 `.so` 的加载期审计（GLOB_DAT 0 条、函数地址
全部是 RELATIVE、无悬空 VERNEED）；`tools/check_input_bridge.py` 对坐标桥的
结构检查；qemu-user 上跑通离屏渲染与整条 NativeActivity 回调路径（含字体、
图片、按钮、首帧呈现、销毁），并导出 720×1280 帧缓冲目视确认；probe1 的
`A/K` 轨迹在 qemu 下落盘成功；假输入队列下的「DOWN/UP → 命中 → 回调 →
计数 +1」通过，且用旧的 `typ == 1` 编译会返回 5（回归测试有效）。
v1.5 追加：`scroll_test`（偏移 / 最大值钳制 / 视口裁剪 / 滚动后命中）与
`list_harness`（真实 `ui_list` 拖 300 px 后点按钮）在 qemu 上通过，
命令数组扩到 64 B 后四个 `.so` 的 RELACOUNT 仍与 RELATIVE 数量一致。
v1.6 追加：`fling_test` 覆盖减速停点、两端钳制、向外/微速拒绝与滚动条像素；
用假宿主渲染 `ui_list` 前后两帧，确认滑块在右侧裁圆内、拖动后随偏移下移。
v1.7 追加：`text_test` 覆盖聚焦线、字母/大写/退格/数字模式/收起/清空；
`form_harness` 跑真实 `ui_form` 的键盘显隐与文本回显；导出 720×1280
表单帧确认字段光标、键盘四行与逐键标签；五个 `.so` 仍是 4 条 DT_NEEDED
（`libandroid/liblog/libm/libc`），GLOB_DAT 为 0。
v1.8 追加：`nav_test` 覆盖初始 route/depth、push/pop/reset、8 层上限、
超限拒绝、根页 pop 返回 -1、push 清焦点；`nav_harness` 跑真实 `ui_nav`，
按钮 push 到 2/3、长按 BACK（DOWN/DOWN/UP）只 pop 一次、系统 BACK 逐级
pop、reset 回根、根页 BACK 触发 `ANativeActivity_finish`；`form_harness`
追加「键盘打开时 BACK 只收键盘、文本保留、界面不退出」。
v1.9 追加：`system_test` 覆盖内容区根节点内缩、子节点偏移、`aui_safe_*`
dp 值、全屏底色命令、安全区内点击、深色背景/角色色与恢复全屏；`system_harness`
跑真实 `ui_system`，覆盖 720×1280→1280×720 旋转、内容区回调、density
420→160 与 night=2 的配置变化、深色像素和按钮切回浅色。七个 `.so` 的
静态门禁保持通过（六个带 AsterUI 的库仍是 4 条 DT_NEEDED，probe1 只有
libandroid）。
v1.9.1 修复：v1.9.0 的 `config_refresh()` 导入了 NDK 不存在的
`AConfiguration_getUiMode`，真机 `dlopen` 直接失败、连 `trace.txt` 都不会
创建；改为 `AConfiguration_getUiModeNight`（0/1/2，2 = 深色），测试替身与
假配置同步改名/改值，`check_so.py` 增加不存在符号黑名单，七个 APK 以
versionCode 10 / 1.9.1 重打包。
v1.10 追加：64 槽动画系统（alpha/tx/ty、linear/ease-out/smoothstep），
`paint_node` + `cmd_add` 在绘制阶段叠加、子树继承；`fill_run` 半透明走
逐像素混合，文字/图片按命令 alpha 缩放；帧与 fling 共用 16 ms timerfd，
前后台停表/恢复。`anim_test` 用注入时钟验证 alpha 0→128→255、TX
30→15→0、像素混合、动画期间 build 不变、64 槽上限；`ui_anim.apk` 演示
两张卡片淡入上滑与 Replay。`aui_version()` 11000，八个 APK 以
versionCode 11 / 1.10.0 重打包，qemu 测试 14 项全过。
v1.11 追加：页面转场采用命令快照（2048 × 64 B）+ 文字深拷贝（48 KB），
push/pop 双向位移 + 交叉淡入、reset 纯淡入，默认关闭（`aui_nav_transition`），
`ui_nav` 开启 240 ms；转场期间点击与 BACK 被吞、到时自动停表。
`nav_transition_test` 验证起/中/终三帧像素、旧页文字深拷贝、pop 反向、
reset、关闭与超容量退化；`nav_transition_harness` 跑真实 `ui_nav` 验证
输入吞噬与自动结束。`aui_version()` 11100，八个 APK 以 versionCode 12 /
1.11.0 重打包，qemu 测试 16 项全过。
v1.11.1 修复：真机 `uinav` 点一下切换后卡死（转场把输入锁住，但 16 ms 帧
定时器一帧都没回调，`page_on` 永远不归零，后续触摸只有 `T/x/y`）。现在
`frame_timer_arm()` 按失败阶段返回 -1..-4，`page_begin()` 拿不到帧驱动就
放弃转场直接切页；输入路径新增 `page_refresh()` 看门狗：到点立即结束转场
并放行这一次点击/BACK；连续一次转场期间一帧都没来且已超时 250 ms，则判定
该设备帧源不可用，此后导航永久直切。新增 `e`（结束原因）与 `a`（启动状态）
轨迹标记，`nav_watchdog_test` 在“定时器全程不回调”下验证不锁死、不丢输入。
`aui_version()` 11101，八个 APK 以 versionCode 13 / 1.11.1 重打包，qemu
测试 17 项全过。
v1.11.2 追加：真机复测的 trace 里没有 `a`/`e`，说明跑的还是旧包，于是给
trace 第二行加 `V` + 版本号（`V00002B5E`），旧包/新包一眼可分；同时把
“第一次导航”也兜住——输入队列挂上 looper 后先自动点一帧做帧源自检，
进程内定时器从未回调过的设备第一次导航直接切页（`a7`），不会停在旧页
上、要再点一下才动；只要之后真来了一帧，下次导航自动恢复转场。
`aui_version()` 11102，八个 APK 以 versionCode 14 / 1.11.2 重打包，qemu
测试 17 项全过。
v1.11.3 追加：真机 trace 显示帧源只在“looper 因为别的事件醒着”时才会
送一帧（启动阶段的自检因此误判通过，第一次导航仍停在旧页，直到下一次
触摸触发 e2 才收尾）。自检改为要求连续两帧、且两帧之间没有输入、没有
别的呈现，排除“被输入/重绘顺手唤醒”的假回调；这类设备从此不会通过
自检（每次导航 a7 直接切页），第一次切换也不再停顿。`aui_version()`
11103，八个 APK 以 versionCode 15 / 1.11.3 重打包，qemu 17 项全过。
v1.12.0 追加：v1.11.3 的真机 trace（`V00002B5F`，30 次导航全部 `a7`、
零 `e`、零 `a0`）确认了根因判断——`timerfd` 只能在该 looper 已经醒着时
被顺手读到，永远唤不醒空闲的 UI 线程，所以自检永远过不了、转场永远
直切。这个版本不再和 looper 较劲，改用**自唤醒帧泵**：native 线程 +
非阻塞 `pipe2` 唤醒 + `poll` 16 ms 节拍，从自己的线程里
`ANativeWindow_lock/unlockAndPost`，用一把 mutex 与输入/窗口生命周期
串行化。帧泵可用时恢复真正的 240 ms 分层转场动画（`Z` 报告最后一帧
序号）；`pipe2`/`pthread_create` 失败或首帧尚未落地时仍然 `a7` 直切，
行为只会更好不会更差。`aui_version()` 11200，八个 APK 以 versionCode 16 /
1.12.0 重打包，qemu 17 项全过。
v1.12.1 追加：帧泵原先只要“调过 `aui_frame`”就计一帧，如果泵线程拿不到
窗口锁（present 失败），首帧门会被骗过、看门狗也以为帧源正常，转场仍会
停在旧页 240 ms。现在只认 `present` 成功（`g_aui_paint_seq` 有变化）的帧，
失败帧不计入、下一拍重试，连续约 2 s 失败即永久直切；trace 用 `Y1`
（首次 present 失败）与 `Y2`（判定不可用）区分。`aui_version()` 11201，
八个 APK 以 versionCode 17 / 1.12.1 重打包，qemu 17 项全过。
v1.12.2 追加：1.12.1 的真机 trace（`V00002BC1`，`J0` 就绪、30 次导航
仍全部 `a7`、无 `Y`）暴露出首帧门永远过不了：启动时 UI 线程的
`aui_invalidate` 已经把 need_* 清掉，帧泵拿到锁时既无动效也无脏帧，于是
一直“无事可做”，`g_aui_pump_frames` 永远是 0。修复：新泵的第一帧
**无条件 present 一次**（trace `Y0`），之后才按 active/dirty 出帧；
`g_aui_pump_frames` 每次新建泵都从 0 开始。`aui_version()` 11202，
八个 APK 以 versionCode 18 / 1.12.2 重打包，qemu 17 项全过。

v1.12.3 追加：1.12.2 的真机 trace（`V00002BC2`，`J0`/`Y0` 正常、每次
导航 `a0`）暴露出新的瓶颈：转场确实启动了，但 240 ms 里只出 1~2 帧
（`e2 Z1`），动画等于没有。原因在 `draw_frame` 的旧转场路径：每帧先把
主题底色、旧页快照、新页命令各做一次全屏逐像素混合（1216×2688 三个
满屏，每次混合两次乘法加除法），单帧在真机上要 100 ms 以上；同时输入
线程在分发导航事件时持锁同步 present，又白画 1~2 帧，和泵抢同一把锁。
修复两条：
（1）合成快路径——两页命令列表开头都是“同色、不透明、满屏”的底色时
（`aui_root` 页面的常态），把两层底色按 `a_old`/`a_new` 解析地压成一个
颜色，整屏只做**一次不透明填充**，再画旧内容（alpha 乘 `1-a_new` 衰减）
和新内容；不是这种页面时自动回退旧路径，视觉效果不变（离屏渲染
start/end 帧与 1.12.2 逐字节一致，中间帧仅混色舍入差 ≤ 11/255）。
（2）转场期间 UI 线程不再同步绘制：`aui_invalidate` 只标脏并唤醒帧泵，
锁和帧全部交给泵线程。
离线基准（720×1280，qemu）：转场帧 210 ms → 47 ms，普通整页帧 13.5 ms。
另外新增 trace `q`（每帧耗时毫秒）与 `w`（窗口锁等待毫秒），转场帧数
应当从 1~2 升到 10 以上。`aui_version()` 11203，八个 APK 以 versionCode
19 / 1.12.3 重打包，qemu 17 项全过。

v1.13.0 追加：原生 PNG 解码（不依赖 zlib / libpng）。zlib 头校验、stored /
fixed / dynamic 三种 deflate、32 KB 回溯环、5 种行过滤器、IDAT 跨段位流、
五种色型与 `tRNS` 全部自己实现，输出 RGBA8888；`aui_png_decode` 写入调用方
缓冲，`aui_png_decode_pool` 从库内 1 MiB 池分配。`png_test` 用确定性生成的
13 张图（7 张成功 + 6 个反例）覆盖上述路径（含 2048×2048 超限、截断、
坏过滤器），并断言 48×48 图标解码结果与原裸 RGBA 逐字节一致；`ui_hello`
改为启动时解 `assets/icon48.png`、失败退回裸 RGBA。`aui_version()` 11300，
八个 APK 以 versionCode 20 / 1.13.0 重打包，qemu 18 项全过。

v1.14.0 追加：Android 15（API 35）edge-to-edge 适配。1.13.0 的真机 trace
（`V00002C24`）里内容区是 `i0 j0 o1216 p2688`（整窗），截图显示标题与图标
压在状态栏下。系统从 targetSdk 35 起强制 edge-to-edge，而 NDK **没有**
WindowInsets 查询接口、本项目又不用 JNI，于是库采用保守估算：`sdkVersion
>= 35`、内容区等于整窗、应用未调用 `aui_edge_to_edge(1)` 时，上下各留
24 dp 系统栏；应用可用 `aui_set_insets(l,t,r,b)` 指定更大的最小安全区
（刘海/挖孔/三键导航），最终取系统内容区、估算值、应用下限三者的较大者。
`aui_safe_*` 改为返回本帧实际使用的内缩；attach 读取
`ANativeActivity.sdkVersion` 并写 trace `O`，估算状态变化时写 `E` +
打包的上下像素。`system_test` 追加 6 个断言（估算 24/24、edge-to-edge
关闭估算、应用下限 40 dp、两者取较大、清空恢复）。`aui_version()` 11400，
八个 APK 以 versionCode 21 / 1.14.0 重打包，qemu 18 项全过。

v1.15.0 追加：系统栏条带。1.14.0 的真机 trace（`V00002C88`、
`O00000024`、`d00034000`、`E004E004E`）证明 24 dp 估算生效（上下各
78 px），截图里内容已避开状态栏；但状态栏的时间/电量是白色，压在浅色
背景上几乎看不见。NDK 没有控制系统栏图标明暗的接口，项目又不用 JNI，
所以在有安全区时先铺一条深色系统栏条带（浅色主题 `0xFF1B1B1F`、深色
主题 `0xFF050507`），再把内容区铺回主题底色；应用可用
`aui_set_system_bar(color)` 换色，传 0 跟随主题，传
`aui_theme_color(AUI_COLOR_BG)` 可关掉条带。`system_test` 追加条带
像素、命令数与覆盖 API 的断言。`aui_version()` 11500，八个 APK 以
versionCode 22 / 1.15.0 重打包，qemu 18 项全过。

v1.16.0 追加：CJK 回退字体与 UTF-8 文本。1.15.0 的真机 trace
（`V00002CEC`、`P0000000F`）和截图确认条带生效：顶部/底部是深色，
时间、电量、手势条清晰，内容区仍是浅色。这一版补上中文：新增
`aui_set_fallback_font(font, scale)`，主字体缺字时查 16x16 1bpp 回退
字体；字体由 `tools/gen_cjk_auf.py` 从 Noto Sans CJK SC 生成，覆盖
GB2312 6763 字 + CJK 标点/全角共 6931 字形（325 KB，OFL）。光栅器
支持每行 2 字节的 9–16 px 字形，行高/字形高度取两套字体较大者；
`aui_text_append` 按 UTF-8 写入，退格删整个码点。`cjk_test` 覆盖
`中文`/`A中`/`中文界面` 的宽度、墨迹、关闭回退与 UTF-8 编辑；
`ui_hello` 的副标题、计数标题和重置按钮改为中文。`aui_version()`
11600，八个 APK 以 versionCode 23 / 1.16.0 重打包，qemu 19 项全过。

v1.17.0 追加：开关与进度条。节点类型 12 / 13，`aui_switch(key, on, cb, user)`
与 `aui_progress(key, value)`；开关状态和进度值都由应用每帧传入，库不持有。
开关 44×24 dp，开轨道 `PRIMARY`、关轨道 `SCROLLBAR`、滑块 `SURFACE`，
按下换成 `PRIMARY_DARK` / `HINT`；进度条高 8 dp，轨道 + `PRIMARY` 已完成段，
`value` 是千分比 0..1000（越界夹紧）。修复了 Q16.16 宽度直接乘千分比导致
i32 溢出、填充只有 12 px 的问题（改用 `i64` 中间量）。新增
`aui_debug_node_count()` / `aui_debug_cmd_count()` 供测试断言；
`controls_test` 覆盖开/关两态、点按回调、点标签不触发、50% 双色像素与
0/1000 夹紧。`ui_hello` 增加“提醒”开关与 65% 进度卡片。
`aui_version()` 11700，八个 APK 以 versionCode 24 / 1.17.0 重打包，
qemu 20 项全过。

v1.18.0 追加：字体放大到可读尺寸并改为比例排版。用户反馈 v1.17 真机上
字体偏小、看着不舒服，实测 8×8 字体即使放大 2 倍也远小于系统正文。这一版
新增 24px 源字体（`font_latin24.auf` / `font_cjk24.auf`，按 2 倍绘制），
拉丁字形带真实 advance 与 xoff/yoff，不再等宽；光栅器补齐 17–24 px 的
3 字节行读取；`draw_glyph` 修正了 xoff/yoff 记录偏移（原先读成 +8/+9，
把 yoff/flags 当成位置，字母整体错位）。文本换行改为按词折行，
`layout_text()` 同时服务测量与绘制，避免“测量按一种断行、绘制按另一种”
造成的溢出。示例统一换用 24px 字体；`ui_form` 的字段区放进滚动区、
Clear/Focus 固定在键盘上方，小屏 720×1280 也能点到 DONE 和按钮；
`list_harness` 改为按实际矩形计算拖动距离，`font24_test` 覆盖比例步进与
3 字节行。键盘上的 SHIFT / DEL 在 48 px 下宽 130 / 88 px，超过窄窗口
一个键的宽度，会压到相邻键上；改为按键高 1/3 生成的像素图标
（上箭头 / 带 × 的退格五边形），shift 打开时图标用主色。
`aui_version()` 11800，八个 APK 以 versionCode 25 / 1.18.0
重打包，qemu 21 项全过。另外修正了交付截图的通道顺序：缓冲一直是
RGBA（测试断言字节 0 是红色），旧转换脚本把 R/B 对调，截图里的主色
看起来是橙色，设备上实际是蓝色 `0xFF3A6DF0`。

v1.19.0 追加：解决“字大了之后有点发虚”。v1.18 的 48 px 是 24px 1bpp
字形按 2 倍画出来的，笔画台阶和拐角都是 2 个物理像素，CJK 的细横在
2 倍后还会断成虚线，所以看起来发虚。这一版改为**原生 48px 图集、1 倍
绘制**：`font_latin48.auf`（95 字形，11 KB）与 `font_cjk48.auf`
（6932 字形，2.0 MB），字形高度仍是 48 px，台阶降到 1 px；行高从
52 变成 60，布局位置与 v1.18 基本一致。光栅器不再用 i32 行字的移位
（48px 一行 6 字节，超过 32 位），`draw_glyph` 改为逐字节取位：按
`ceil(w/8)` 装载，每个字节覆盖 8 个像素，最左像素在行内最后一个字节
（行字是小端整数）。第一版逐字节实现按大端索引取字节，文字被读成竖条，
`font48_test` 的“L 左竖笔 / 右上角无墨”和“W 右端有墨”三个断言就是
用来卡这个错误。`gen_latin_auf.py` 新增可选 baseline 参数，latin48 用 46
与 cjk48 的 47 对齐（v1.18 的 24×2 混排汉字比拉丁低 6 px，现在约 1 px）。
六个示例改为 `aui_set_font(g_font, 1)`；`ui_hello` 副标题改为
“v1.19 中文界面”，`ui_nav` 改为“v1.19 page transitions”。
`aui_version()` 11900，八个 APK 以 versionCode 26 / 1.19.0 重打包，
uihello.apk 2,386,590 字节（主要增量是 CJK48 图集），qemu 22 项全过。

v1.20.0 追加：按 HuxerUI 的 `toggle.cpp` / `slider.cpp` 补齐选择类控件。
新增节点类型 14 / 15 / 16（复选 / 单选 / 滑块），`AuiNode` 的 `aux2`
存放勾选态（0/1）或滑块步长（千分比），`aux` 存滑块初值；构造器
`aui_checkbox` / `aui_radio` / `aui_slider` 与应用持有状态的约定与
`aui_switch` 相同。几何照搬 HuxerUI：复选 20 dp 见方、圆角 4 dp、
2 dp 边框，单选 20 dp 圆环 + 10 dp 圆点，滑块高 32 dp、轨道 4 dp、
拇指 16 dp（按下 18 dp）、轨道两端内缩 9 dp；复选/单选在纵向容器里
自动铺满整行，行高 `max(20dp, 文字行高)+pad*2`，按下时整行有
`PRESSED` 状态层。光栅器没有描边原语，边框和圆环用「外圈色 + 内缩
底色」两层图形拼出来，为此绘制阶段新增 `g_aui_paint_bg` 记录当前
节点底色（根取主题 `BG`，子节点取自己的 `bg`），卡片里的复选框
内部因此是卡片色而不是页面色。滑块手势在 `handle_motion` 里完全
接管（DOWN 取值、MOVE 实时更新、UP/CANCEL 结束），不会触发外层
scroll 拖动；吸附四舍五入到 `step` 倍数且 0/1000 始终可达；新增
`aui_slider_value(key)`，拖动中与普通查询都能读到当前值。新示例
`ui_settings.ast`（第 9 个 APK，`dev.aster.uisettings`）含两张开关卡、
深浅色单选项、亮度/音量两个滑块与 Reset；新增 `select_test`，用 45 个
返回码断言几何、勾选/圆点/边框像素、整行点击、单选互斥、滑块点击与
拖动实时值、`step=0` 与端点。另外修正 v1.19 源码里 trace 版本号误写 11800 的问题（与
`aui_version()` 11900 不一致，v1.19 包实际显示 `V00002E18`；文档里
写的 `V00002E7C` 并未在包上出现过），本版为 `V00002EE0`。`aui_version()` 12000，九个 APK 以 versionCode 27 /
1.20.0 重打包，uihello.apk 2,403,854 字节，qemu 23 项全过。

v1.21.0 追加：按 HuxerUI 的 `segmented_button.cpp` 与
`SegmentedButtonStyle` 默认值补分段控件。新增节点类型 17（容器）/ 18（段），
`aui_segmented(key, selected, cb, user)` + `aui_segment(key, text)` +
`aui_segmented_value(key)`；`aux` 存选中下标，`aux2` 由 arrange 写入段下标。
外观：`SURFACE` 底、8 dp 圆角、1 dp `HINT` 边框，选中段 `PRIMARY` 胶囊
（按下 `PRIMARY_DARK`）、未选段按下 `PRESSED` 胶囊，胶囊四周内缩 2 dp、
圆角 6 dp，标签选中用 `ON_PRIMARY`。等宽分配直接用 Q16.16 除（最后一段
吃余数），段高 `max(文字行高+14dp, 32dp)`、段宽最少 48 dp；纵向容器里
铺满，row/stack 里保持固有宽度。段复制容器的回调，UP 时先写
「容器 key + 下标」再回调，点已选中段也会回调。`ui_settings` 增加
Climate 卡（cm/in 分段切换，Height 175 cm ↔ 69 in），同时修正 v1.20
示例里漏掉的一个 `aui_end()`——Climate 卡片没闭合，把 Reset 按钮和
底部说明都吞进了卡片，卡片实测高 761 px、分段控件被滚动视口裁掉
底边；修复后卡片高 321 px，胶囊四边内缩都是 5 px（2 dp @2.625）。
新增 `segmented_test`（52 个断言）覆盖几何、边框/内衬/胶囊像素、标签
颜色、按下态、回调与下标回读、行内固有宽度。`aui_version()` 12100，
九个 APK 以 versionCode 28 / 1.21.0 重打包，qemu 24 项全过。

v1.22.0 追加：按 HuxerUI 的 `tabs.cpp` 与 `TabsStyle` 默认值补标签页。
新增节点类型 19（容器）/ 20（页），`aui_tabs(key, selected, cb, user)` +
`aui_tab(key, text)` + `aui_tabs_value(key)`；`aux` 存当前页下标，`aux2`
由 arrange 写入页下标。外观：背景透明、无分隔线，选中页文字 `PRIMARY`、
其余 `TEXT`，当前页底部 2 dp `PRIMARY` 指示条（宽度 = 页宽、圆角 1 dp）；
`item_padding` 12×8 dp 落到页测量（宽 +24 dp、高 +16 dp），页宽最少 48 dp、
页高最少 36 dp。页按固有宽度从左排列、不摊剩余宽度（`expand_items=false`），
纵向容器里容器铺满；绘制时给容器加裁剪，超出容器的页被裁掉。UP 时先写
「容器 key + 页下标」再回调；容器本身的空白区域不触发回调。新示例
`ui_tabs.ast`（第 10 个 APK，`dev.aster.uitabs`）三个页签 Feed / Stats /
More 各有独立内容（可刷新的 Feed、属性行与进度条的 Stats、复选/开关的
More），并可切换深色主题。新增 `tabs_test`（47 个断言）覆盖几何、文字
颜色、指示条像素、点按回调与下标回读、点已选中页、空白不回调、行内固有
宽度。`aui_version()` 12200，十个 APK 以 versionCode 29 / 1.22.0 重打包，
qemu 25 项全过。

v1.23.0 追加：形状抗锯齿。此前所有圆角都用整数 `inset` 逐行内缩，
density 3.25 下按钮、卡片、开关、单选圆环与标签页指示条的弧边能看到
明显的台阶。这一版在 `fill_rect` 里按面积覆盖率做 1 px 过渡：像素
中心到圆心的距离换算成 1/16 px，`128 + (r*16-d)*16` 给出 0..255 的
覆盖率，边界两侧各 0.5 px 从底色过渡到前景色；直边仍是整数像素对齐，
中心整行仍走 `fill_run`。圆角带里的左右边界由像素中心行的圆方程求得，
完全覆盖的中间段整行写入，左右各一个边界像素用 `blend_px` 混合；颜色
自身的 alpha（按压态、动画）先与覆盖率相乘，避免二次混合。修了一处
左右圆心串用：右边界最初用左圆心算覆盖率，导致右圆角完全没有过渡
（`shape_aa_test` 返回码 25 的已选复选框角）。文本仍是 1bpp 位图、
不参与 AA（灰度 CJK 图集会把 2.0 MB 变成约 8 MB，也会重新引入 v1.19
的“发虚”）。新增 `shape_aa_test`（32 个断言）：胶囊/圆/描边/圆角块/
2 dp 指示条的中间色计数、直边与角外像素的精确颜色。`aui_version()`
12300，十个 APK 以 versionCode 30 / 1.23.0 重打包，qemu 26 项全过。
顺带把 ui_hello 的副标题从“v1.19 中文界面”改成“v1.23 中文界面”：
此前副标题一直没跟着版本走，真机截图只看画面分不出装的是哪一版，
现在截图与 trace 第二行可以互相核对。

v1.24.0 追加：按 HuxerUI 的 `pager.cpp` 补横向分页。新增节点类型 21
（容器）/ 22（页），`aui_pager(key, selected, cb, user)` + `aui_page(key)` +
`aui_pager_value(key)`；所有页并排，偏移按 key 存在 32 槽表里，首帧直接
落到 selected，之后 selected 变化或松手用 200 ms ease-out 吸附。手势先
8 dp 方向锁：横向占优由分页接管并取消滚动，纵向占优交给页内 scroll；
松手速度 ≥ 600 px/s 或位移 ≥ 35% 页宽时只提议相邻页，只调一次回调，
应用用 `aui_pager_value` 读目标页；CANCEL/轻点回弹且不回调。绘制阶段给
容器加裁剪，命中只下钻当前页，邻页露出的部分不会误触。新增
`ui_pager.ast`（第 11 个 APK，`dev.aster.uipager`）把 Tab 与分页共用一个
选中值：点 Tab 自动吸附、横滑让 Tab 跟着高亮，每页内部仍可纵向滚动。
新增 `pager_test`（46 个返回码，26 留空；最后两段验证速度阈值与
纵向拖动不误点）与 `pager_harness`（真实宿主路径：左滑翻页、Tab 吸附、版本号）。
顺带修正“刚点/刚松手”提案值的生命周期：`aui_root` 重建时清掉 tab/pager
的提案缓存，之后 `aui_tabs_value` / `aui_pager_value` 回读到应用保存的
真实选中页（此前点 Tab 后读 pager 会拿到上一次滑动的旧提案）。
`aui_version()` 12400，十一个 APK 以 versionCode 31 / 1.24.0 重打包，
qemu 28 项全过。

v1.25.0 追加：按 HuxerUI 的 `presentation.cpp` 补模态对话框。新增节点
类型 23（遮罩）/ 24（卡片），`aui_dialog(key, open, cb, user)` 只在
`open != 0` 时创建，子项全部放进卡片；`aui_dialog_reason()` 返回本次
关闭原因（1 遮罩 / 2 BACK）。对话框是游离层：不挂根树、不参与页面/
滚动/分页布局，绘制在整棵树之后；遮罩覆盖整窗 `0x99000000`，卡片在
内容区居中，宽 `min(内容宽 − 48dp, 320dp)`、高按内容测量并夹到
`内容高 − 48dp`，默认 `pad 24dp / gap 12dp / radius 16dp / SURFACE`。
打开期间 `hit_test(root)` 整体转到对话框，底层收不到点击；卡片空白
不关闭、按钮优先命中。BACK 在焦点/导航之前处理，回调后应用把 `open`
置 0；只支持一层，且暂不支持对话框内文本字段。新增 `ui_dialog.ast`
（第 12 个 APK，`dev.aster.uidialog`）：列表页 + 删除确认，Cancel /
Delete / 遮罩 / BACK 四条路径都会更新状态行。新增 `dialog_test`
（16 个返回码）与 `dialog_harness`（真实宿主路径：打开、遮罩、BACK、
Cancel、版本号）。`aui_version()` 12500，十二个 APK 以 versionCode 32 /
1.25.0 重打包，qemu 30 项全过。

v1.26.0 追加：按 HuxerUI 的 `dropdown.cpp` 补下拉选择。新增节点类型
25（select 容器）/ 26（option），`aui_select(key, selected, open,
placeholder, cb, user)` + `aui_option(key, text)`；选项始终作为子项
参与 build（节点数恒定），只有 `open != 0` 时才由 `select_layout` 摆进
锚定浮层。浮层宽度跟触发器、下方 4 dp，放不下翻上方、再夹进内容区；
行高 48 dp、上下 padding 6 dp、左右 8 dp 边距，一屏放不下只摆前面几行，
无内部滚动。选中项 TINT 底 + PRIMARY 文字，触发器 1 dp HINT 描边 +
10 dp 圆角、右侧 3 行三角。展开期间是模态层：命中只到触发器/浮层/选项，
其余返回 -1（外部关闭）、浮层 padding 返回 -2（吞掉）；底层按钮、
滚动、分页全部屏蔽。`aui_select_reason()` 返回 0 触发器 / 1 选项 /
2 外部或触发器再点 / 3 BACK；`aui_select_value(key)` 读刚点中的下标。
新增 `ui_select.ast`（第 13 个 APK，`dev.aster.uiselect`）：三个下拉 +
实时回显 + 深色切换。新增 `dropdown_test`（离屏几何/像素/命中/原因码）
与 `select_harness`（真实宿主：展开、选中、外部、BACK、深色、420 dpi
上翻、节点数不变）。`aui_version()` 12600，十三个 APK 以 versionCode 33 /
1.26.0 重打包，qemu 32 项全过。

v1.26.1 追加（真机反馈修复）：文本命令的裁剪高度从字高改成行高。
48 px 拉丁字体的 g/y/p 下伸部会超出 em 框（字高 48、行高 60），原来按
48 px 裁剪会把 “English” 的 g 勾切平；现在 `emit_text_lines`、输入框、
键盘键、复选/单选标签，以及下拉触发器/选项的显式裁剪都用
`text_line_h()`，垂直居中仍按 `text_glyph_h()`，布局和行距不变。
`select_harness` 增加回归采样：触发器里 g 的下伸部第 35 行必须是文字色。
同版把 `ui_select` 的语言列表从 “Japanese” 换成 “中文”，示例同时
嵌入 48 px 汉字图集并 `aui_set_fallback_font`（APK 因此增大约 2 MB）；
摘要行选中第 3 项时也回显 “中文”。`aui_version()` 12601，十三个 APK
以 versionCode 34 / 1.26.1 重打包，qemu 32 项全过。

v1.26.2 追加（真机 trace 修复）：下拉手势改为以下按位置为准。真机 trace
里 `x000002F9 y000003CB` 按下“中文”、`x000003A3 y000002A3` 抬起在
“English”上，旧逻辑按 UP 位置判成点击，误选了 English；另一组从浮层外
按下、在 Dark 上抬起也直接选中。现在 DOWN 记录命中与坐标，MOVE 位移
超过 8 dp（`g_aui_select_drag`）即判定拖动，UP 一律不选中/不关闭；
未拖动时按 DOWN 的目标决定（选项回调、触发器/外部关闭、padding 吞掉），
只有没有 DOWN 的补发 UP 才退回按 UP 位置判断。同时把
`g_aui_select_press` 从 `aui_root()` 的每帧重置里移除——它属于输入状态，
之前 DOWN 触发的重建会立刻清掉按下下标，选项的 PRESSED 底色从未出现；
现在由 DOWN/UP/CANCEL/BACK 清除。`select_harness` 新增三条回归：选项
DOWN 后重建仍有 PRESSED 底色（返回 36）、选项间拖动不选中（35）、
浮层外拖进选项不选中（37）。`aui_version()` 12602，十三个 APK 以
versionCode 35 / 1.26.2 重打包，qemu 32 项全过。

v1.27.0 追加：按 HuxerUI 的 `tooltip.cpp` 补工具提示。API 是修饰器
`aui_tooltip(text, side, align)`：挂在最近创建的节点上；如果刚 `aui_end()`
关闭了容器，则挂到那个容器（和 `pad/gap/weight` 的修饰目标一致）。
`side` 取 `AUI_ANCHOR_ABOVE/BELOW/RIGHT/LEFT`，`align` 取
`AUI_TIP_ALIGN_START/CENTER/END`，越界回落到上方/居中。登记表每帧重建、
最多 32 条，文本指针与锚点矩形在 DOWN 时快照，后续 rebuild 不影响显示。
按住不动 500 ms 才出现；按住期间一直显示；移动超过 8 dp 取消；松手后
再停留 1.5 s（多 0.1 s 让最后一批帧画完）。长按显示后的抬起不再触发
按钮点击（`g_aui_pressing` 清零），短按照常点击。气泡不进节点树：深色底
`#1F2328` 94% 不透明、白字、内边距 8/4 dp、圆角 4 dp、最小高 24 dp、
最大宽 320 dp；默认锚点上方居中，放不下翻到对侧，最后整体夹进内容区
并留 8 dp 边距。同一时刻只有一个气泡；新的 DOWN、BACK、导航切换、
打开对话框/下拉都会先收起。`tip_tick()` 挂在 `pump_ui` 每帧起点，
待定/停留期间帧泵保持 16 ms 节拍。新增 `ui_tooltip.ast`（第 14 个 APK，
`dev.aster.uitooltip`）：四方向按钮 + 容器 + 底部提示，实时 Clicks 计数
验证短按点击、长按不点击。新增 `tooltip_test`（离屏几何/像素/状态机/
四方向/翻边/BACK）与 `tooltip_harness`（真实宿主路径：长按显示、不点击、
停留、容器、end 对齐、BACK）。气泡绘制修正了一个多行换行缺陷：测量
按最大文本宽换行、绘制却按“最长行宽”重新换行，恰好满行后跟空格时会
多折一行，末行被气泡高度裁掉；现在布局把最大文本宽存进
`g_aui_tip_tw`，绘制沿用同一宽度，并新增
`aui_debug_tooltip_lines()` 供测试断言“气泡高 = 行数 × 行高 + 8”。
`tooltip_test` 场景 3 覆盖该回归（返回 26，旧实现上确认失败）。
`ui_tooltip` 的 Clicks 状态文案同步缩短为 “no click” / “button tap”。
`aui_version()` 12700，十四个 APK 以 versionCode 36 / 1.27.0 重打包，
qemu 34 项全过。

v1.28.0 追加：按 HuxerUI 的 `date_time_picker.cpp` 补日期选择。API 是
`aui_date_picker(key, y, m, d, cb, user)`：每次 build 传入当前值，库内按
key 记住可见年月与月/年模式。值变化（或越界被夹紧）时自动回中到该月；
`aui_date_min/max` 设置范围（默认 1-1-1..9999-12-31），
`aui_date_week_start(1)` 可改成周一开头，`aui_date_selected(key, out)`
回读 `[y,m,d]` 三 i32。日期用 Hinnant civil-days 算法在纪元日之间换算，
闰年/大小月/跨世纪都对；2 月 31 日这类输入会归一化成 2 月 29/28 日。
布局：内边距 12 dp、表头 44 dp、格宽 = (宽 - 6×2 dp)/7 且不超过 36 dp，
高 = 表头 + 格×7 + 间隙×6；年视图 4×5 与月视图顶部对齐（整体垂直居中）。
表头左右箭头换月/换 20 年，点标题在月/年视图间切换；范围外的年份和
日期置灰且不可点，整月超出范围时箭头点击无效。月份/星期名与箭头字符写在运行期
初始化的全局字节表里，库内没有字符串字面量（否则 `link-obj` 的
`__aster_string_N` 会与示例撞符号）。手势：DOWN 记录目标，移动超过
8 dp 取消激活并把拖动让给滚动/分页，只有同一目标上的 UP 才选中；
选中日真的变化才回调（导航、切年视图、重复点都不回调）。新增
`ui_date.ast`（第 13 个应用 APK，`dev.aster.uidate`）：标题栏深色开关、
Travel date 卡片（2024-2027 范围）、实时 Selected 回显。新增
`date_picker_test`（网格/像素/换月/年视图/范围/周一开头/夹紧/归一化/
手势取消）与 `date_picker_harness`（真实宿主：换月、年视图、选日、
重复点、深色）。`aui_version()` 12800，十五个 APK 以 versionCode 37 /
1.28.0 重打包，qemu 36 项全过。

v1.29.0 追加：按 HuxerUI 的 `date_time_picker.cpp` 补时间选择。API 是
`aui_time_picker(key, hour, minute, cb, user)`：每次 build 传入应用侧
当前时刻（越界夹紧），库内按 key 记住选时/选分、12/24 小时制与步长。
`aui_time_step(n)` 只接受 1..60 且整除 60 的分钟数（否则 -1），
`aui_time_12h(1)` 打开 12 小时制；二者作用于最近创建的选择器，需紧跟
在 `aui_time_picker` 之后调用。受控值不强制吸附——step=15 时传 10:07
仍原样显示，只有点/拖表盘才按步长量化。表头 52 dp（64 dp 时/分字段 +
16 dp 冒号，12 小时制再加 8 dp 间距 + 44 dp AM/PM 组），表盘直径至多
208 dp；24 小时制外圈 1..12、内圈 00/13..23（0.78R / 0.52R），分钟
表盘每 5 分钟一个标签。没有画线原语，手柄用 128 个 2 dp 圆点连成，
选择点在对齐 5 分钟标签时是 14 dp 主色圆 + 最小 28 dp 的胶囊标签，其余分钟改为 5 dp 圆头手柄（v1.29.1：1 分钟粒度下 14 dp 圆会盖住相邻标签）；角度用 12 个 Q16.16
单位向量 + 八分区 atan 查表，满圈 3,932,160。开发中修掉了奇数八分区
把 45° 加反方向的问题（10 分位置曾被算成 75 分）。手势：表盘按下即
取值、拖动连续更新并阻止父滚动，选时松手自动进选分；头部字段/AM/PM
只有同一目标上松手才切换。新增 `ui_time.ast`（第 14 个应用 APK，
`dev.aster.uitime`）：标题栏深色开关、Meeting time 卡片（12h/15m
两个开关）、实时 Selected 回显。新增 `time_picker_test`（字段/像素/
拖动/内外圈/12h/步长/双卡/深色）与 `time_harness`（真实宿主：选分/
拖动/自动进分/12h/步长/深色）。`aui_version()` 12900，trace 第二行
`V00003264`，十六个 APK 以 versionCode 38 / 1.29.0 重打包，qemu 38 项全过。

v1.29.1 修复：真机选择 20:23/20:24/20:25 时反馈“有偏移”。根因是
14 dp 选中圆在 208 dp 表盘、1 分钟粒度下约占 3 分钟弧长：23/24 分时
圆会压住相邻的 25 分标签，看起来像选中了 25。现在只有正好落在 5 分钟
标签上才画 14 dp 圆（与 28 dp 胶囊重合），其余分钟只画 5 dp 圆头
手柄，圆心仍严格对准所选角度；`time_picker_test` 增加 23/24/25 分
角度回读与手柄像素断言，`time_harness` 同步验证。另修 `ui_time`
示例的选项行：`aui_weight(1)` 原本作用在 12h 开关上，把它拉长到约
78 dp 并把 15m 组挤到右边；改为 `aui_spacer` 占位后两个开关同宽
（48 dp）、15m 右对齐，测试断言两者矩形一致。`aui_version()` 12901，
trace 第二行 `V00003265`，十六个 APK 以 versionCode 39 / 1.29.1
重打包，qemu 38 项全过。

v1.30.0 追加：按 HuxerUI 的 RefreshBox 补下拉刷新。API 是
`aui_refresh_box(key, refreshing, cb, user)`：内容是唯一子节点，滚动
偏移与普通 `aui_scroll` 共用同一张表；内容在顶部时继续下拖的部分不写进
偏移，而是按 0.45 阻尼变成内容下移，最大 96 dp。松手不足 68 dp 吸附回 0；
超过则回调一次，收进 52 dp 的刷新位并开始旋转。`refreshing` 由应用
持有：置 1 保持旋转，置 0 后 200 ms 吸附回顶部；即使应用没有定时器、
回调后立刻回到 0，指示圈仍会转满 700 ms 再收起。指示器是 36 dp surface
圆、20 dp 轨道 / 3 dp 笔画，轨道用 `on_surface` 16% alpha；不定量弧线
占 28%，900 ms 一圈，和表盘手柄一样用 36 个圆点拼出。容器不进入点击
目标（`find_clickable` 跳过 kind 29），刷新期间点行按钮照常生效。
开发中修掉一个定点溢出：淡入比例原先写成 `disp * 65536 / size`，
Q16.16 位移乘 65536 在 0.5 px 以上就溢出，整圈 alpha 变 0（表现是
拖出空白但看不到指示圈）；现在先降到像素再算比例，弧长同理。测试也
从“只看背景亮度”改为扫描主色弧线像素，避免深色背景掩盖漏绘。
帧泵把刷新动画并入 `refresh_busy()`，与翻页/转场/惯性共用同一套
激活/停帧判定。新增节点类型 29、`refresh_test`（阻尼/上限/阈值/
52 dp/700 ms/应用 refreshing/滚动/深色/弧线像素）与 `refresh_harness`
（真实宿主：下拉、回调、相位、滚动、深色、弧线像素）。新增
`ui_refresh.ast`（第 15 个 APK，`dev.aster.uirefresh`）：24 行列表 +
刷新计数 + 行点击 + 深色。`aui_version()` 13000，trace 第二行
`V000032C8`，十七个 APK 以 versionCode 40 / 1.30.0 重打包，
qemu 40 项全过。

v1.30.1 修复：用户真机 trace（V000032C8，1216×2688 / density 3.25）
显示长距离下拉时位移出现负值（R 从 R0134B333 跳到 RFEC30A3E）。
根因是 `rd = (0 - rdes) * 45 / 100`：`rdes` 是 Q16.16，手指下拉超过
约 728 px 后乘法溢出 i32，`rd` 变负，指示圈瞬间消失，松手还会被当成
fling 去滚动列表。现在先算 `rm = 0 - rdes`，再 `rm / 100 * 45`，最大
仍夹在 96 dp。`refresh_test` 增加 dy=1000 px 的回归（位移必须落在
90..96 dp 且只回调一次），`refresh_harness` 的触发用例改为 dy=900 px
（420 dpi 下同样越过 728 px 溢出边界）。`aui_version()` 13001，trace
第二行 `V000032C9`，十七个 APK 以 versionCode 41 / 1.30.1 重打包，
qemu 40 项全过。

v1.31.0 追加：按 HuxerUI 的 Chip 补标签片。API 是
`aui_chip(key, text, selected, cb, user)`：`selected != 0` 画主色胶囊 +
`on_primary` 文字，否则 surface 底 + `on_surface` 24% 的 1 dp 描边 +
`on_surface` 文字；按下未选换 pressed 内层，选中按下主色加深。尺寸是
固有宽（文字 + 左右各 16 dp），高 = max(28 dp, 行高 + 8 dp)，圆角
14 dp；在行里并排，在列里保持固有宽左对齐（不像复选框那样撑满整行）。
控件本身不持有状态：点按只调 `cb(user)`，应用翻转自己的 `selected`
再 `aui_invalidate()`，与开关/复选/单选一致。新增节点类型 30、
`chip_test`（固有尺寸、列内不拉伸、选中主色、1 dp 24% 描边、
按下态、文字色、单/多选切换、深色、未知 key）与 `chip_harness`
（真实宿主：筛选切换、多选位、列内固有宽、深色）。新增
`ui_chip.ast`（第 16 个 APK，`dev.aster.uichip`）：单选筛选 +
多选标签 + 列内标签片 + 实时回显。`aui_version()` 13100，trace 第二行
`V0000332C`，十八个 APK 以 versionCode 42 / 1.31.0 重打包，
qemu 42 项全过。

v1.32.0 追加：按 HuxerUI 的 ProgressCircle 补环形进度。API 是
`aui_progress_circle(key, value, size)`：`value` 是千分比 0..1000，从
12 点起顺时针铺弧；`value < 0` 为不确定进度，固定 28% 的弧、900 ms 转
一圈，由现有帧泵自动驱动，应用不需要定时器。直径 `size` dp（0 → 24 dp，
夹在 8..240），描边 = max(1, size/8) dp，轨道 = `on_surface` 16% 压到
当前背景色后的不透明色（72 个点相互重叠，半透明叠加会越叠越深），
指示色 = primary。环用 72 个圆点拼成，12 个锚点之间做线性插值后按
`isqrt` 归一化向量，避免出现 12 边形拐点。控件是固有正方形，不接收
点击；列里用 `aui_align(1/2)` 居中/右对齐。新增节点类型 31、
`progress_circle_test`（0/25/100%、弧起点、450 ms 相位、默认 24 dp、
96 dp、越界夹紧、深色、未知 key）与 `progress_circle_harness`
（真实宿主：三个 48 dp 并排、受控值 +25%、不确定旋转相位、默认尺寸、
深色）。新增 `ui_progress_circle.ast`（第 17 个 APK，
`dev.aster.uiprogress`）：并排 25/60/100% + 受控 +25% 按钮 +
Loading 旋转 + 默认 24 dp。`aui_version()` 13200，trace 第二行
`V00003390`，十九个 APK 以 versionCode 43 / 1.32.0 重打包，
qemu 44 项全过。

v1.32.1 修正：v1.32.0 的环是 72 个圆点沿圆周铺的，相邻圆点的抗锯齿
边缘被混合两次，轨道上出现周期性波纹（真机 520 dpi 下 24 dp / 40 dp
尤其明显），而且每个环每帧要发 144 条命令。现在光栅器新增 op 4 解析
圆环：一条命令给出外接正方形、内半径和“起点 | 跨度”，逐像素按到圆心
的距离求内外半径覆盖率、按角度求圆弧两端覆盖率，三者相乘后只混合
一次；整圈跳过角度计算。弧两端仍各补一个直径 = 描边的圆点做圆头，
与 v1.32.0 的观感一致。`progress_circle_test` 增加命令数上限（12..40，
防止退回点阵），`progress_circle_harness`、`refresh_test` /
`refresh_harness`（下拉刷新指示器也换成同一原语）全部通过。
`aui_version()` 13201，trace 第二行 `V00003391`，十九个 APK 以
versionCode 44 / 1.32.1 重打包，qemu 44 项全过。

v1.33.0 新增树视图（HuxerUI `TreeViewStyle`，受控组件）：`aui_tree(key)`
是固定行高 32 dp 的滚动容器（节点类型 32），`aui_tree_item(key, text, depth,
flags, cb, user)` 是单行条目（节点类型 33），`depth` 夹在 0..32，缩进
8 + 20 dp/级，展开指示是 24 dp 槽里的 12 dp 三角形（`AUI_TREE_BRANCH` /
`EXPANDED` / `SELECTED` / `DISABLED`）。选中行铺 14% primary、按下 8%
primary（圆角 8 dp），禁用行文字 38% alpha；三角由光栅器新增的 op 5 用逐行
覆盖率绘制，右指/下指都不出锯齿。滚动沿用 scroll 表（滚动条、拖动、fling
都复用现有实现），可见行由应用按展开位自己决定，符合受控组件用法。
新增 `tree_test`（离屏 320×240：几何/缩进/标志位/选中底色/三角方向/点按/
滚动/禁用/版本）、`tree_harness`（真实宿主 720×1280@420：展开收起、滚动、
深色）与 `ui_tree.ast`（第 18 个 APK，`dev.aster.uitree`：20 行目录树 +
选中/展开状态回显）。`aui_version()` 13300，trace 第二行 `V000033F4`，
二十个 APK 以 versionCode 45 / 1.33.0 重打包，qemu 46 项全过。

v1.34.0 新增 Toast / SnackBar（对照 HuxerUI `presentation.h`）：
`aui_toast(text, duration_ms)` 是不挂树的底部浮层，底部居中、最多 4 条
（新的在下、旧的按 8 dp 间距向上叠），深色 `#1F2328` 94% 底 + 白字、
16/12 dp 内边距、8 dp 圆角、最大 480 dp，触摸直接穿透到底层；
`aui_toast_dismiss(handle)` 手动收起。`aui_snackbar(key, text, action,
duration_ms, cb, user)` 是窗口内唯一的可交互浮层：新调用替换旧的，
底边留 24 dp、最大 600 dp，动作文字 `#79C0FF`、最小 48 dp，点消息表面
吞掉点击、按住动作暂停倒计时，松手先收起再回调。两者都走现有帧泵，
没有宿主定时器也能自动到期（`present_tick`），时长 0 = 默认
2000/4000 ms、<0 = 常驻。新增 `toast_test`（离屏 320×240：几何/堆叠/
穿透/到期/暂停/回调/无效参数）、`toast_harness`（真实宿主 720×1280@420：
穿透/堆叠/UNDO/到期/深色）与 `ui_toast.ast`（第 19 个 APK，
`dev.aster.uitoast`：单条/两条/常驻/UNDO + 状态回显）。`aui_version()`
13400，trace 第二行 `V00003458`，二十一个 APK 以 versionCode 46 /
1.34.0 重打包，qemu 48 项全过。

v1.35.0 新增菜单（对照 HuxerUI `MenuStyle`）：`aui_menu(key, anchor_key,
open, cb, user)` / `aui_menu_at(key, px, py, open, cb, user)` 打开一层不挂
树的浮层（节点类型 34），`aui_menu_item(key, text, flags, cb, user)` 与
`aui_menu_separator(key)` 声明条目（35/36），`aui_end()` 结束。默认贴锚点
下方 4 dp，放不下翻到上方，最后夹在内容区 8 dp 边距内；屏幕点菜单用
Q16.16 左上角。白底（深色主题为深色表面）、8 dp 圆角、1 px 描边 +
偏移半透明近似阴影、内容内边距 4 dp、条目 12/8 dp、最小宽 180 dp、
最小高 36 dp；有勾选条目时保留 18+8 dp 状态列，勾选标记用新的抗锯齿
粗线段原语（op 6）画两笔。`AUI_MENU_CHECKED` / `AUI_MENU_DISABLED`；
关闭原因 `aui_menu_reason()`（1 条目 / 2 外部 / 3 BACK）与
`aui_menu_item_key()`；点条目时先关菜单、先调菜单回调，再调条目回调。
内容超高时菜单内部可拖动滚动（8 dp slop）。菜单是内容层模态浮层，
输入优先于 SnackBar 与页面，BACK 先关菜单。新增 `menu_test`（离屏
320×240：几何/配色/勾选/禁用/选择顺序/外部/BACK/溢出滚动/屏幕点/翻上）、
`menu_harness`（真实宿主 720×1280@420：锚定/选择/禁用/外部/BACK/屏幕点/
滚动/翻上/深色）与 `ui_menu.ast`（第 20 个 APK，`dev.aster.uimenu`：
锚定 / 屏幕点 / 超长菜单 / 底部翻上 + 状态回显）。`aui_version()` 13500，
trace 第二行 `V000034BC`，二十二个 APK 以 versionCode 47 / 1.35.0
重打包，qemu 50 项全过。

v1.36.0 新增图标与图标按钮（对照 HuxerUI `Icon` / `IconButton`）：22 个
内置矢量图标（`AUI_ICON_PLUS/MINUS/CHECK/CLOSE/CHEVRON_*/ARROW_*/SEARCH/
MORE/MENU/PLAY/PAUSE/STAR/TRASH/EDIT/HOME/SETTINGS/CALENDAR/DOWNLOAD`），
不加载位图，任意 dpi 下按几何重画。`aui_icon_button(key, icon, size_dp,
flags, cb, user)` 是 40 dp 触控方块（可 24..96 dp）、图形为边长一半
（默认 20 dp）、4 dp 按下指示层（边长 4/5，浅色 `PRESSED`），
`AUI_ICONBTN_DISABLED` 只置灰（alpha 97）且不派发点击；`aui_icon(key,
icon, size_dp)` 是只读图形（默认 20 dp，8..96 dp），背景透明，可放进
行/列/滚动容器。图形统一按“半格 = 1000”归一化：`icon_px` 用 i64 换算，
描边半宽 = 边长/20，圆点半径 = 边长/14；加号/减号/勾/叉/箭头/菜单/编辑/
主页/设置/日历/下载用圆头粗线段（op 6），搜索用圆环（op 4）+ 手柄，
播放用三角形（op 5），暂停/星形/垃圾桶由多条线段拼成。调试接口
`aui_debug_icon_button`（x,y,w,h,icon,disabled,size_px）与
`aui_debug_icon`（x,y,w,h,icon,size_px）。顺带修复播放/暂停在 ≥48 dp
时 `s * 720` 的 i32 溢出。新增 `icon_test`（离屏 320×240：几何/笔画/
禁用/按下/尺寸/深色）、`icon_harness`（真实宿主 720×1280@420：工具条/
点击/禁用/22 图标/尺寸行/滚动/深色）与 `ui_icon.ast`（第 21 个 APK，
`dev.aster.uiicon`：工具条 / 图标网格 / 尺寸 / 深色 + 状态回显）。
`aui_version()` 13600，trace 第二行 `V00003520`，二十三个 APK 以
versionCode 48 / 1.36.0 重打包，qemu 52 项全过。

v1.37.0 新增流式布局与分隔线（对照 HuxerUI `Flow` / `Divider`）：
`aui_flow(key)` 是节点类型 39 的换行容器，`aui_flow_align(AUI_FLOW_START/
CENTER/END/SPACE_BETWEEN)` 设定**每一行**主轴的排列方式（默认 START）。
量测按“先量孩子，放不下（严格大于）才换行”累积行宽/行高，行高取该行
最高孩子，行间距与列间距共用 `aui_gap`，总高 = 上下 pad + 各行高 +
行间距；宽度在给定可用宽时铺满，否则取最宽行。排布分两遍：第一遍确定
每行的成员与总宽，第二遍按剩余空间算居中/贴边偏移或均分间隔
（SPACE_BETWEEN），有 `aui_weight` 的孩子按权重瓜分该行剩余宽度；交叉
轴 `aui_align` 支持起/中/末/拉伸。`aui_divider(key)` 为 1 dp 细线
（可 `aui_bg` 覆盖颜色、`aui_pad` 控制内缩），默认颜色是文字色 12%
alpha 的 surface 混合，深浅色主题下都自动可见；`aui_divider_v(key)`
为竖线，默认 `align=3` 拉满父行高度。绘制顺序在容器背景之后、子节点
之前，分隔线本身不接输入。调试接口 `aui_debug_flow`（x,y,w,h,行数,
对齐）与 `aui_debug_divider`（x,y,w,h,方向,厚度）。新增 `layout_test`
（离屏 320×320：换行边界/行高/居中/space-between/权重/竖直与自定义
分隔线/深色）、`layout_harness`（真实宿主 720×1280@420：标签片换行点按、
五种对齐、图标 5+2 换行、图标按钮、分隔线墨迹与深色）与 `ui_layout.ast`
（第 22 个 APK，`dev.aster.uilayout`：换行标签片 / 对齐模式 / 分隔线 /
深色 + 状态回显）。`aui_version()` 13700，trace 第二行 `V00003584`，
二十四个 APK 以 versionCode 49 / 1.37.0 重打包，qemu 54 项全过。

v1.38.0 新增底部弹层（对照 HuxerUI `presentation.h` 的 `BottomSheet`）：
`aui_sheet(key, open, cb, user)` 在 `open != 0` 时创建两个游离节点——
类型 41 的全屏遮罩（键 `-key`）与类型 42 的贴底表面（键 `key`）。表面
宽 = 内容宽 − 32 dp（上限 640 dp），高按内容测量并夹在内容高的 85%，
内部 `pad 20dp`、`gap 12dp`、顶部圆角 14 dp、底部直角；顶部中央
32×4 dp 手柄可用 `aui_sheet_handle(0)` 隐藏（仍保留 32 dp 抓取区）。
打开时从屏底滑入 240 ms ease-out，滑入后 280 ms 吞掉向下事件；顶部
抓取区向下拖动时表面跟随，松手阈值 `max(高/4, 96dp)`，未过回弹、超过
关闭。关闭原因 `aui_sheet_reason()`：1 遮罩、2 BACK、3 下拉；与 dialog
互斥、只允许一层，绘制在 dialog 之后、命中在 dialog 之前。关闭为即时
移除（HuxerUI 有 180 ms 退出动画，本实现每帧重建节点、关闭后不留节点）。
调试接口 `aui_debug_sheet`（x,y,w,h,拖拽_px,flags）。新增 `sheet_test`
（离屏 320×320：贴底/遮罩/圆角/命中/手柄/回弹/下拉关闭/遮罩/BACK/深色）、
`sheet_harness`（真实宿主 720×1280@420：滑入中点、几何、滑块、Confirm、
下拉阈值、遮罩、BACK、手柄隐藏、深色）与 `ui_sheet.ast`（第 23 个 APK，
`dev.aster.uisheet`：打开 / 滑块 / Cancel/Confirm / Hide handle / Dark +
状态回显）。`aui_version()` 13800，trace 第二行 `V000035E8`，二十五个
APK 以 versionCode 50 / 1.38.0 重打包，qemu 56 项全过。

v1.39.0 新增锚定浮层（对照 HuxerUI `presentation.h` 的 `Popup`）：
`aui_popup(key, anchor_key, open, cb, user)` 在 `open != 0` 时创建一个
类型 43 的游离节点（不挂进页面树），`aui_popup_at` 以屏幕点为锚点。
宽度默认 = 孩子最宽 + 32 dp（最少 96、最多 360 dp，或
`aui_popup_width` 固定），高度按内容测量并夹在内容区；首选方向与
交叉轴对齐由 `aui_popup_place` 设置，放不下自动翻边并夹到 8 dp 边距。
底板是 1 dp 描边 + 12 dp 圆角的 surface，内部 `pad 16dp`、`gap 12dp`。
点外部 reason=1、BACK reason=2、`aui_popup_dismiss` reason=3；与
dialog / sheet / menu / select 互斥，只允许一层，命中在页面之前。
调试接口 `aui_debug_popup`（x,y,w,h,side,align,reason）。新增
`popup_test`（离屏 320×320：锚定/翻边/夹取/四方向/对齐/外部/BACK/
dismiss/互斥/深色）、`popup_harness`（真实宿主 720×1280@420：打开、
滑块、Apply、外部、BACK、Above/Right/Left、Center、深色）与
`ui_popup.ast`（第 24 个 APK，`dev.aster.uipopup`：四方向 / 三对齐 /
滑块 / Cancel/Apply / 深色 + 状态回显）。`aui_version()` 13900，
trace 第二行 `V0000364C`，二十六个 APK 以 versionCode 51 / 1.39.0
重打包，qemu 58 项全过。

v1.40.0 新增顶部应用栏（对照 HuxerUI `navigation.h` 的 `TopAppBar`）：
`aui_top_bar(key, title, leading_icon, cb, user)` 创建类型 44 的容器。
最小高 48 dp，左右内边距 8 dp（`aui_pad` 可覆盖）；leading 是 40 dp
图标按钮，贴左并垂直居中，标题从 leading 右侧 4 dp 开始（无 leading 时
从左边距 + 16 dp 开始），到动作区左侧 4 dp 结束。标题单行绘制、按区间
裁剪，粗体用偏移一次的重绘模拟；栏高 = max(48 dp, 最高子项高度)。
`aui_top_bar_align(0/1)` 选起始/居中，`aui_top_bar_divider(0/1)` 画底部
1 px 提示线；动作按自身高度垂直居中并从右往左排布。调试接口
`aui_debug_top_bar` 输出 16 个整数。新增 `top_bar_test`（离屏 320×320：
高度/内边距、leading/动作、标题区间、居中、提示线、撑高、嵌套、深色）、
`top_bar_harness`（真实宿主 720×1280@420：leading/动作回调、居中、
提示线、长标题、深色）与 `ui_top_bar.ast`（第 25 个功能 APK、
`dev.aster.uitopbar`：leading / 动作 / 居中 / 提示线 / 长标题 / 深色 +
计数回显）。`aui_version()` 14000，trace 第二行 `V000036B0`，二十七个
APK 以 versionCode 52 / 1.40.0 重打包，qemu 60 项全过。

v1.41.0 新增底部导航栏（对照 HuxerUI `navigation.h` 的 `NavigationBar`）：
`aui_nav_bar(key, selected, cb, user)` 创建类型 45 容器，子项
`aui_nav_item(key, icon, label, flags)` 是类型 46 叶子。栏高至少 64 dp，
子项等宽平分（余数给最后一项）；每项 56×32 dp 指示胶囊 + 24 dp 图标 +
一行文字，选中胶囊主色 12%。选择由应用控制：点未选中项先记录
`(栏 key, 下标)` 再回调，回调里 `aui_nav_value` 读取；点已选中项和禁用项
不回调。`aui_nav_labels(0/1)` 隐藏/显示未选中项文字。调试接口
`aui_debug_nav_bar` / `aui_debug_nav_item` 共 15 个整数。新增 `nav_bar_test`
（离屏 320×320：等宽、指示胶囊、选中回读、已选/禁用不回调、隐藏文字、
越界、单项、列内缩进、深色）、`nav_bar_harness`（真实宿主 720×1280@420：
贴底 168 px、4×180、选中切换、隐藏文字、禁用、深色）与 `ui_nav_bar.ast`
（第 26 个功能 APK、`dev.aster.uinavbar`：4 项 / 隐藏未选中 / 禁用 Star /
深色 + 状态回显）。`aui_version()` 14100，trace 第二行 `V00003714`，
二十八个 APK 以 versionCode 53 / 1.41.0 重打包，qemu 62 项全过。

v1.42.0 新增侧边导航栏（对照 HuxerUI `navigation.h` 的 `NavigationPane`）：
`aui_nav_pane(key, selected, expanded, cb, user)` 创建类型 47 容器，子项
`aui_nav_pane_item(key, icon, label, flags)` 是类型 48 叶子。宽度固定为
收缩 72 dp / 展开 256 dp，项高 48 dp、等宽，横向内边距默认 8 dp，纵向
内边距与项间距沿用 `aui_pad` / `aui_gap`。指示胶囊收缩 56×32 dp、展开
铺满项宽，半径 16 dp；展开态在图标右侧绘制文字并裁剪到项右缘 8 dp 内。
选择与底部导航栏共用请求槽：点未选中项先记录 `(栏 key, 下标)` 再回调，
`aui_nav_value` 读取；已选中/禁用项不回调。调试接口 `aui_debug_nav_pane` /
`aui_debug_nav_pane_item` 共 16 个整数。新增 `nav_pane_test`（离屏
320×320：收缩/展开宽度、项高、胶囊、选中回读、已选/禁用不回调、越界、
行内缩进、文字裁剪、深色）、`nav_pane_harness`（真实宿主 720×1280@420：
收缩 189×1280、项 147×126，展开 672、项 630，选中切换、禁用、文字、
深色）与 `ui_nav_pane.ast`（第 27 个功能 APK、`dev.aster.uinavpane`：
侧边栏 + 内容列 / Expanded / Disable Star / Dark theme + 状态回显）。
`aui_version()` 14200，trace 第二行 `V00003778`，二十九个 APK 以
versionCode 54 / 1.42.0 重打包，qemu 64 项全过。

v1.42.1 修复侧边栏展开后收不回去（示例布局问题）：v1.42.0 把三个开关放在
内容列里，展开后内容列只剩约 48 px，开关跑到屏幕外，Expanded 再也点不到。
本版把 Expanded / Disable Star / Dark theme 移到行下方、整宽的一栏（273 px），
侧边栏展开时开关仍完整可见、可点；库代码不变，仅 `aui_version()` 14201、
trace 第二行 `V00003779`，二十九个 APK 以 versionCode 55 / 1.42.1 重打包，
qemu 64 项全过。`nav_pane_harness` 增加「展开后再次点 Expanded 收回 189 宽」
的断言。

v1.43.0 新增可编辑组合框（对照 HuxerUI `view.h` 的 `ComboBox`）：
`aui_combo(key, hint, open, cb, user)` 创建类型 49 的文本触发器，复用
`text_field` 的按键文本池与键盘，空文本画 hint 与右侧下三角；建议项
`aui_combo_suggestion(key, text)` 是类型 50，`open != 0` 时进入锚定浮层
（宽跟触发器、48 dp 行、6 dp 内边距、上下 4 dp 间距，放不下翻上）。
浮层是半模态：命中测试仍放行屏幕键盘，DOWN/UP 只在非键盘命中时走
组合框分支，所以展开时能边打字边看前缀过滤结果。回调 reason 分四种，
`aui_combo_value` 回读当前建议下标，新增 `aui_combo_pick_key()` 回读
建议 key（过滤后下标会变，用 key 映射选项更稳）。新增 `combo_test`
（离屏 320×320：触发器 320×72 / 浮层与建议几何 / 点按展开 / 过滤 /
选择回读 / 外部与 BACK / 深色）、`combo_harness`（真实宿主
720×1280@420：触发器 636×189、浮层 [42,424,636,283]、键盘输入 b 过滤出
Banana/Blueberry、BACK、选建议写回、外部关闭、Clear、深色）与
`ui_combo.ast`（第 28 个功能 APK、`dev.aster.uicombo`：输入过滤 / 建议 /
Clear / Dark + 状态回显）。`aui_version()` 14300，trace 第二行
`V000037DC`，三十个 APK 以 versionCode 56 / 1.43.0 重打包，qemu 66 项全过。

v1.44.0 修两个文本问题，都来自真机截图反馈：

1. **占位符占住了光标位**。`paint_combo`（以及同构的 `paint_field`）先取
   真实文本长度，空文本时把 `s/tlen` 换成占位符继续画，之后算光标宽度
   用的还是这个“占位符长度”，于是光标被顶到 “Type a fruit name...” 的
   末尾。改为保留 `real`（真实长度）单独判断：`real == 0` 时光标宽度记 0，
   停在 `x + pad` 首位；同时把占位符右移 4 dp（`tshift`），光标不再压住
   首字母。有正文时行为不变（含超宽文本 `text_fit_start` 截头后的行尾）。
2. **文字发毛发虚**。拉丁图集一直是 1bpp 阈值位图（`THRESHOLD = 100`），
   48 px 下笔画边缘只有“有/无”两档，细笔画会出现锯齿和断续，和系统
   UI 字体差得很远。`.auf` 的 flags 第 0 位本来就约定为 8bpp alpha，但
   生成器一直写 1 却输出 1bpp；这一版把约定落实：
   - `gen_latin_auf.py` 增加 `bpp` 参数（默认 8），8bpp 时每行 `w` 字节、
     逐像素写 Pillow 的覆盖度；advance 与墨迹包围盒的算法一字未改，
     所以**所有布局尺寸与 v1.43 完全一致**（`combo_harness` 的 636×189、
     浮层 283 等断言原样通过）。
   - `font_latin48.auf` 11,342 → 69,480 字节，`font_latin24.auf`
     4,415 → 19,088 字节；旧的 1bpp 图集（`font_latin.auf`、三套 CJK）
     把文件头 flags 修正为 0（原来误写 1），`gen_cjk_auf.py` 同步改。
   - `draw_glyph` 先读字形记录 `+9` 的 flags，bit0 命中就走新增的
     `draw_glyph_aa`：覆盖度 × 颜色 alpha 后 `blend_px`，支持 scale 与
     裁剪；1bpp 仍走原来的按字节取位路径，两种编码可以在同一行里混排。
   - 汉字仍用 1bpp 48 px 图集：6932 字形转 8bpp 会把每个带 CJK 的 APK
     撑大 10 MB 以上，收益不如代价，作为已知边界保留。

回归补强：`combo_test` 新增返回码 14，断言空文本聚焦时 `(pad, 中线)` 是
2 dp 主色光标、`pad + 2` 处是白底（占位符确实让开了）；`select_harness`
的“English 的 g 下伸部”检查原来按纯色 `0x1A1A1E` 采样，AA 后墨迹内部
不再是纯色，改成 3×3 邻域取最小 luma < 128（裁剪回归仍有效）。
`aui_version()` 14400，trace 第二行 `V00003840`，三十个 APK 以
versionCode 57 / 1.44.0 重打包，qemu 66 项全过；截图里
“Type a fruit name...” 与键盘字母都有灰阶过渡，光标停在输入框首位。

v1.45.0 新增虚拟列表（对照 HuxerUI `list.h` 的 `VirtualList`）：

1. **只建窗口内的行**。`aui_vlist(key, count, item_dp, on_bind, on_tap, user)`
   创建类型 51 容器，行高固定为 `item_dp`，内容总高 = `count × 行高`；
   `on_bind` 里用 `aui_vlist_row(index)` 建类型 52 的行，
   `aui_vlist_first()` / `aui_vlist_last()` 给出当前窗口（闭区间）。窗口按
   “当前偏移 + 上一帧视口高”计算，上下各多一行；视口高按 key 跨帧保留，
   首帧用 480 dp 保守估计，布局后发现视口不同或窗口没盖住可见区就置
   `need_build`，下一拍自动补齐（不在 arrange 里递归 pump）。5000 行示例
   的节点数仍只有窗口规模（`vlist_harness` 断言 ≤ 200）。
2. **超长列表的偏移改用整数像素**。原滚动表是 Q16.16 px，最大只能表示约
   32768 px；5000 行 × 168 px = 840,000 px 会直接溢出。本版给虚拟列表
   单独存 `off/max`（i32 像素），`scroll_get/set/max/store_max` 按 key
   分派；普通 `aui_scroll` 仍保持 Q16.16。拖动位移、惯性步长对虚拟列表
   不再乘/除 65536，而是按 px 直接换算；滚动条比例、`aui_debug_scroll_max`
   返回真实像素（示例 max = 839008）。
3. **行点击与复用**。`on_tap` 挂到每一行，点击时先记录
   `(容器 key, 行下标)` 再回调；回调里用 `aui_vlist_tap_index()` /
   `aui_vlist_tap_key()` 读取。行内容与选中态完全由应用在 `on_bind` 里按
   下标现场生成，库不持有数据。行宽铺满内容区，行高固定；裁剪、滚动条、
   拖动与惯性复用 `aui_scroll`（kind 51 已加入 find_scroll / clip /
   scrollbar 等全部相关列表）。
4. **接口**：`aui_vlist_scroll(key)` 读偏移（px），
   `aui_vlist_scroll_to(key, px)` 程序化滚动并触发窗口重建；
   `aui_debug_vlist(key, out)` 输出 `[x,y,w,h,count,first,last,offset_px]`，
   `aui_debug_vlist_row(key, index, out)` 输出行矩形（不在窗口返回 -1）。

实现中踩到两个 Aster 编译器细节，已写进注释：大十进制字面量会被当成 i64
（赋给 i32 字段报 `TypedIR MISMATCH`，改用 `32760 << 16`），i64 的 `>> 16`
也不能直接套 `i32()`（改用 `/ 65536`）。新增 `vlist_test`（离屏 320×240：
版本号、窗口 0..8、行几何、选中回读、滚动 320 px 后窗口 9..18、最大偏移
31760、末行位置、节点数 < 120、惯性 200 帧后窗口跟随）、`vlist_harness`
（真实宿主 720×1280@420：列表 [0,144,720,992]、行高 168 px、窗口 0..6、
点第 4 行写回、中段 400000 px、滚到底末行 y=968、节点数 ≤ 200、深色）与
`ui_vlist.ast`（第 31 个功能 APK、`dev.aster.uivlist`：5000 行 / 固定
64 dp 行高 / 点行选中 / 深色 + 状态回显）。`aui_version()` 14500，trace
第二行 `V000038A4`，三十一个 APK 以 versionCode 58 / 1.45.0 重打包，
qemu 68 项全过；截图 `vlist-v1450-0..4.png` 依次是顶部（选中第 2 行）、
点中第 4 行、中段 400000 px、滚到底（末行 4999 贴底）与深色滚到底。

v1.48.6 让滚动帧只搬像素，不再整屏重画：

v1.48.5 之后滚动帧已经不再重建、不再 measure，但每帧仍然把整棵命令表
重放一遍：720×1280 的软件光栅每帧约 92 万像素，拖动时输入线程和绘制
线程都压在这一次全屏填充上，实测仍有掉帧。滚动本身只改变一个偏移，
画面里绝大多数像素只是整体平移。

本版加入持久帧缓冲与“纯滚动直搬”：

1. **持久帧缓冲**。库内固定 BSS 分配 4 MiB（`i32[1048576]`，720×1280
   RGBA 正好 3.6 MiB；Aster 全局数组上限 1,048,576 元素，所以按像素计，
   更大分辨率自动退回旧路径）。每次整屏绘制后保存滚动视口、偏移和整张
   画面；帧缓冲与窗口几何不一致时视为失效。
2. **纯滚动帧只搬移 + 补边**。满足“本帧仅滚动偏移变化（轻布局）、无
   build/动画/波纹/弹层/转场、视口与上次完全相同、位移是整像素且小于
   视口”时，纵向滚动按行 `mem_copy` 平移视口内容，只重放新暴露的一条
   横带；再重放视口顶部 4 px 与底部 4 px 固定装饰，以及视口右侧条带。
   横向滚动（hlist）按列搬移，同理补左右暴露带与上下固定条。命令层面
   用 `fb_cmds_ok` 再确认：视口子树外的命令与上一张快照逐字节一致、子树
   之后没有浮层压住视口、紧邻视口上方必须是不透明直角底色（纯色整块
   搬移是恒等操作）。任一条件不满足就整屏重画，结果永远与全量重绘等价。
3. **亚像素与首帧回退**。普通 `aui_scroll` 的小数偏移、视口带圆角、
   波纹/惯性/刷新/Toast/工具提示在动、列表窗口跨行重建等，都直接走原
   路径；直搬只是快路径，不是新语义。

**回归手段**：`vlist_harness` 新增 G 段。先用 6 步整像素滚动收集帧，
断言至少 3 帧走了直搬且最后一帧仍是直搬；把整屏 3,686,400 字节快照
到四个 `u8[921600]` 全局数组（单个数组上限 1,048,576），再强制
`aui_debug_full_repaint()` 全量重绘同一偏移，逐字节对比整屏。直搬结果
与全量重绘完全一致（返回 0），证明搬移、补边、覆盖判定没有漏像素。
调试入口另有 `aui_debug_frame_blit()`（本帧是否直搬）、
`aui_debug_blit_off(v)`（强制关闭，对比用）、`aui_debug_fb_bad(out)`
（帧缓冲坏像素计数）。

`aui_version()` 14806，trace 第二行 `V000039D6`；三十四个 APK 以
versionCode 67 / 1.48.6 重打包，qemu 74 项全过；五张截图与
v1.48.1–1.48.5 逐像素一致。

v1.48.5 修“每个滚动帧都重建虚拟列表”：

v1.48.4 的轻布局只有在“本帧没有 build 请求”时才生效。设备轨迹
（v1.48.3，`V000039D3`）里每个滚动事件后面仍紧跟 `N`：

    vFFFFF... N00000031 L P0000002F F

`N` 就是 `need_build`，说明滚动路径每次偏移变化都要求重建。根因在
`vlist_touch / vgrid_touch / hlist_touch`：它们无条件置
`g_aui_need_build = 1`，而拖动与惯性每一帧都会调用。于是每个滚动帧都
“build + measure + arrange + 画”，轻布局被完全抵消。

本版改动：

1. **滚动不再强制 build**。拖动 `MOVE` 与 `fling_step` 只
   `mark_scroll_dirty()`；`*_touch` 仅保留给程序化 `*_scroll_to`。
   虚拟列表的窗口需要变化时，`arrange_vlist / arrange_vgrid / arrange_hlist`
   自己检测并置 `need_build`，下一拍走完整 build（一拍内用旧窗口绘制），
   不会出现空白行或错位。
2. **构建窗口留两行余量**。build 时的可见区间由 `±1` 行放宽到 `±2` 行，
   抵消“窗口判定晚一拍”的影响；arrange 的判定仍用 `±1`，窗口推进逻辑不变。
3. **滚动一开始就清掉残留波纹**。`ripple_step()` 在拖动或惯性期间无条件
   `ripple_clear()`，按压被滚动取消时不再有淡出扫描带。

测试侧新增 `aui_debug_build_count()`：`vlist_harness` 里一次 4 步拖动
（720×1280@420，行高 168）断言 build 增量 ≤ 1 且偏移确实减小，把
“每帧重建”钉死为回归。qemu 驱动对比：修复前拖动 40 步 build 45 次，
修复后 8 次（只在行窗口跨越时 build）。

`aui_version()` 14805，trace 第二行 `V000039D5`；三十四个 APK 以
versionCode 66 / 1.48.5 重打包，qemu 74 项全过；五张截图与
v1.48.1–1.48.4 逐像素一致。

v1.48.4 把滚动本身做快（轻布局 + 单帧节拍 + 光栅宽写）：

v1.48.3 的轨迹证据只解决了“同一帧画两遍”，滚动帧自身仍然是
“measure 整棵树 + arrange + 全屏重画”。手指拖动时每个 MOVE（最高 120 Hz）
都会同步走一遍，输入线程被绘制占住，帧间隔自然抖动。本版四处改动：

1. **滚动跳过 measure**。滚动只改偏移，节点尺寸/内容高度都没变；
   `mark_scroll_dirty()` 置“轻布局”，`pump_ui` 只 arrange 不再 measure。
   虚拟列表 arrange 发现窗口不够时会自己置 `need_build`，下一拍仍走完整
   build + measure，窗口纠正逻辑不变。
2. **拖动期间输入线程不画帧**。`draw_defer_to_pump()` 增加
   `g_aui_dragging != 0`：拖动 MOVE 只标脏并唤醒泵，由泵按 16 ms 节拍出帧。
3. **泵的唤醒节流**。输入事件会通过管道把泵叫醒；若离上一帧开始不足
   16 ms，这次唤醒只保留脏标志、不画，等到下一拍再画。120 Hz 触摸不会变成
   120 次呈现。
4. **不透明整行填充一次写 4 像素**。`fill_run` 的 RGBA8888 路径用两次
   64 位存、RGB565 用两次 32 位存，循环开销降到 1/4。全屏底色/卡片/列表行
   这种大面积填充在滚动帧里占主要光栅时间。

同时把每帧耗时拆开写进轨迹（见下表）：`w` 等窗口锁、`C` 光栅、`t` 提交、
`X` 局部重画宽高。下一份轨迹可以直接判断卡在等缓冲、CPU 还是合成器。

`aui_version()` 14804，trace 第二行 `V000039D4`；三十四个 APK 以
versionCode 65 / 1.48.4 重打包，qemu 74 项全过；五张截图与 v1.48.1–1.48.3
逐字节一致。

v1.48.3 修滚动卡顿（波纹取消 + 去重复呈现）：

设备轨迹（v1.48.1，1216×2688）里每个触摸帧都是成对的：

    N L P00000116 F      <- 输入线程：build/layout 后自己呈现
    P00000116 F          <- 帧泵：同一画面又画一遍（无 N/L）

也就是说波纹活着的 540 ms（320 ms 扩散 + 220 ms 淡出）内，每次滚动 MOVE
都要画两遍整屏，并且波纹扫描带把每帧命令数从 44 条抬到 278/161 条。两个
修正：

1. **拖动/滚动立即清除波纹**。`ripple_release_now()` 按“本批输入里有没有
   UP”区分：有 UP 才淡出（正常点按），没有 UP 说明按压被拖动/滚动取消，
   直接 `ripple_clear()` 并叫醒帧泵；`ripple_step()` 里再加一道
   `g_aui_dragging != 0` 的兜底。列表一开始滚，波纹就消失，滚动帧不再为
   它绘制。
2. **有动效时输入线程不再自己画帧**。`draw_defer_to_pump()` 从“只对页面
   转场生效”扩展到转场/惯性/波纹/属性动画/分页/刷新：输入只标脏并唤醒
   帧泵，同一个 16 ms 周期里只有泵画一帧，不再“输入一帧 + 泵一帧”。

`ripple_harness` 新增 G3 段：按住行后上拖 60 px（超过 8 dp slop），不喂帧
直接断言 `aui_ripple_active() == 0`；改回旧逻辑该断言失败（返回 35）。
五张截图与 v1.48.1/1.48.2 逐字节一致。`aui_version()` 14803，trace 第二行
`V000039D3`；三十四个 APK 以 versionCode 64 / 1.48.3 重打包，qemu 74 项
全过。

v1.48.2 补齐帧泵节拍（v1.48.1 的 tick 记错了位置）：

v1.48.1 想把“画完再睡 16 ms”改成“按上一帧 + 16 ms 等”，但把
`g_aui_pump_tick` 记在了帧**结束**，于是等待仍是完整的 16 ms，实际周期
仍是“绘制耗时 + 16 ms”，真机上没有改善。本版把 tick 记在帧**开始**，
并允许 timeout 到 0：

    el = now − tick_start;  timeout = max(0, 16 − el)

画 10 ms 就只等 6 ms，周期约 16 ms；画超过 16 ms 则下一拍立即重画。
其余（线性扩散、松手当拍淡出、1–2 px 扫描带）与 v1.48.1 相同。

v1.48.2 同时给波纹帧加了**局部呈现**。设备轨迹里一帧仍要铺满 1216×2688
的根底色（约 327 万像素），仅缩短帧间隔并不能让软件光栅变快。现在只有
“波纹是唯一变化”的帧才启用局部：

- `pump_ui` 记录本帧是否 build/layout；`ripple_paint` 记录实际绘制到的
  节点矩形。没有 build/layout、没有转场/惯性/分页/刷新/提示层时，
  `present_now` 只重画这一块，并把 `ANativeWindow_lock` 的 `inOutDirty`
  也设成这块，让 Surface 把未重画部分从上一帧拷回新缓冲；
- 锁之后按 Surface **返回**的矩形重画（它可能因内容不可用而扩大，最坏
  全屏；返回空矩形则保守整屏），不盲信自己的 damage；
- 每张整屏帧结束保存一份命令快照。局部帧比较快照的前缀/后缀，波纹命令
  条数变化按起止下标平移对齐；只要波纹之外有任何命令变化（Toast 消失、
  输入框文字更新等）就退回整屏。因此“只改波纹”是每帧验证出来的，不靠
  调用方自觉；
- 一条 1216 宽的列表行 damage 约 28 万像素，比整屏少一个数量级。

假宿主是单缓冲，5 张波纹截图与 v1.48.1 的整屏渲染逐字节一致；
`ripple_harness` 新增“旧行淡出时按新行”段，验证旧波纹被清掉、新行出现
波纹。`aui_version()` 14802，trace 第二行 `V000039D2`；三十四个 APK 以
versionCode 63 / 1.48.2 重打包，qemu 74 项全过。

v1.48.1 修正按压水波纹的卡顿感（接口与默认行为不变）：

1. **扩散改线性**。v1.48.0 用 `1-(1-t)^2`，半径在前 1/3 时间就跑完一半，
   后 200 ms 几乎不动，看起来像“冲一下又停住”。HuxerUI `RippleEffect`
   默认就是 `expansion = 320 ms, Linear`，本版改为线性，速度均匀。
2. **帧泵不再固定睡 16 ms**。旧线程是“画完再 `poll(..., 16)`”，实际周期 =
   绘制耗时 + 16 ms，软件光栅在 720p 上很容易掉到 30 fps。v1.48.1 尝试
   记录时刻后补足 16 ms，但 tick 记在了帧结束，实际仍是画完睡满 16 ms；
   v1.48.2 把 tick 改记在帧开始，才真正变成“开始后 16 ms 出下一帧”。
3. **松手当拍进入淡出**。按住超过 320 ms 后扩散已结束、帧泵会停；旧实现
   要等 `ripple_step` 在下一帧比对 `g_aui_pressing`，最坏等 250 ms 兜底
   才出帧。现在 `aui_on_input` 处理完一批事件后调用 `ripple_release_now()`，
   UP/拖动取消都立即记松手时间、置相位 2 并叫醒帧泵。
4. **圆边细化到 1–2 px 一条扫描带**。旧实现按 `r/96` 分带，420 dpi 上可达
   7 px，圆边有明显台阶；现在带高封顶 2 px，典型行内半径下就是 1 px。

验证同步加强：`ripple_test` 断言 UP 之后**不喂帧**时相位已是 2、alpha 仍
为 31；`ripple_harness` 新增“按住超过 320 ms 再松手”段，验证半径已到
`max_r` 后松手仍立即淡出并恢复纯白。`aui_version()` 14801，trace 第二行
`V000039D1`，三十四个 APK 以 versionCode 62 / 1.48.1 重打包，qemu 74 项
全过；截图按新节奏重出（hold80 的圈比旧版小，因为线性扩散不再前冲）。

v1.48.0 新增按压水波纹（对照 HuxerUI `indication.h` / `indication.cpp`
的 Indication 状态层）：

1. **不改节点模型**。波纹是按下状态的行为层，不新增节点类型，`AuiNode`
   仍是 96 B；`paint_node()` 在画完节点自身内容、进入子树之前调用
   `ripple_paint()`。状态由 `g_aui_ripple_*` 一组全局量持有：触点、开始/
   松手时间、当前半径与 alpha、最远角半径、虚拟项身份。默认关闭，
   `aui_ripple(1)` 打开，所有既有截图与像素断言保持不变。
2. **几何与服务端**。按下时在通用 `find_clickable` 路径里记录触点并求出
   到四角的最远距离；扩散用 ease-out，alpha 从 31 开始，松手后 220 ms
   线性淡出。`ripple_allowed()` 排除对话框、弹层、浮层、下拉、组合框、
   日期/时间、分页等自带按压手势的容器（kind 1/19/21..25/29/41/42/49/
   51/53/55）。
3. **逐行扫描与裁剪**。`ripple_paint()` 以 `step = r/96` 扫描圆，再与
   节点矩形、圆角内缩、当前 `g_aui_clip_*` 求交，每条行生成一个矩形命令
   （颜色 = `(alpha<<24) | primary`）。虚拟项没有 key，用
   `(kind, aux2, 父容器 key)` 匹配，列表重建或滚动后仍跟随原项。
4. **帧泵**。`ripple_busy()` 加入 `aui_frame` 的时钟条件、
   `pump_frame_once` 的活跃判定、帧定时器 arm/sync 与空闲检查；按住时
   只扩散阶段出帧，松手后到淡出结束都需要 16 ms 节拍。`aui_ripple(0)`
   立即清零。`aui_ripple_active()` 返回相位，`aui_debug_ripple()` 输出
   `[key,x,y,rad_px,alpha,phase,max_r,elapsed_ms]`（按下至今毫秒数由
   `ripple_step` 记录）。

新增 `ripple_test`（离屏 320×240：默认关闭时按住无波纹、打开后 80 ms
半径/alpha/颜色、相邻行保持纯白、松手 220 ms 淡出恢复、关闭立即清除、
按钮 key 50 与水波纹 key 一致、命令/节点上限）、`ripple_harness`
（真实宿主 720×1280@420：按住行半径随帧增长、旁边行不染色、松手恢复、
按钮 key 正确、Toggle 关闭后不再出现波纹、Tap 计数）与 `ui_ripple.ast`
（第 34 个功能 APK、`dev.aster.uiripple`：20 行 / 按住扩散 / Toggle /
深色与状态回显）。`aui_version()` 14800，trace 第二行 `V000039D0`，
三十四个 APK 以 versionCode 61 / 1.48.0 重打包，qemu 74 项全过；截图
`ripple-v1480-top/hold80/hold240/fade/dark.png` 依次是顶部、按住 80 ms、
按住 240 ms、松手后 120 ms 淡出与深色按住。

v1.47.0 新增横向虚拟列表（对照 HuxerUI `VirtualList.ScrollAxis(
Axis::Horizontal)` 与 `examples/horizontal_virtual_list`）：

1. **只建窗口内的项**。`aui_hlist(key, count, item_w_dp, item_h_dp, on_bind,
   on_tap, user)` 创建类型 55 容器；`on_bind` 里用 `aui_hlist_item(index)`
   建类型 56 的项，`aui_hlist_first()` / `aui_hlist_last()` 给出当前窗口
   （闭区间）。窗口按“当前偏移 + 上一帧视口宽”换算，左右各多一项；视口宽、
   实测间距按 key 跨帧保留，首帧用 480 dp 保守估计，布局后发现视口宽或
   间距不同就置 `need_build`，下一拍自动补齐。1000 项示例的节点数仍只有
   窗口规模（`hlist_harness` 断言 ≤ 250）。
2. **固定项宽、可选固定项高**。项宽固定 `item_w_dp`；`item_h_dp > 0` 时
   项高固定，传 0 则项高撑满容器内容高（项内列容器按此高度排列）。
   项按绝对下标定位：`x = 内容左 + idx×(项宽+间距) - 偏移`，项间距复用
   `aui_gap`。测量与布局使用同一个项宽，文本换行与最终位置一致。
3. **横向拖动与惯性**。拖动会话新增 `g_aui_drag_axis`（0 纵向 / 1 横向）：
   按下命中 hlist 时记录 x 起点，MOVE 用 dx 判 8 dp 阈值并调用
   `drag_sample_x`（速度写入同一个 `g_aui_vel`），松手沿用原有 fling 路径；
   偏移按整数像素存，横向内容可达 44 万 px 而不受 Q16.16 上限约束。
   滚动条改为底部横条（宽度按视口/内容比例，最小 24 dp），裁剪、背景、
   `find_scroll/find_scrollable`、点击映射等列表全部加入 kind 55/56。
4. **点项与接口**。`on_tap` 挂到每一项，点击时先记录
   `(容器 key, 项下标)` 再回调；`aui_hlist_tap_index()` /
   `aui_hlist_tap_key()` 读取。`aui_hlist_scroll(key)` 读偏移（px），
   `aui_hlist_scroll_to(key, px)` 程序化滚动并触发窗口重建；
   `aui_debug_hlist(key, out)` 输出 `[x,y,w,h,count,first,last,offset_px]`，
   `aui_debug_hlist_item(key, index, out)` 输出项矩形（不在窗口返回 -1）。

实现细节：内容宽、最大偏移用 i64 中间量；`flags` 存项高（Q16.16，0 =
撑满），不增加节点尺寸（AuiNode 仍是 96 B）。新增 `hlist_test`（离屏
320×240：版本号、窗口 0..5、项 0 为 80×240、项 3 x=240、点项回读、
滚动 480 px 后窗口 5..11、最大偏移 79680、末项 x=240、节点数 < 200、
惯性后窗口跟随；固定项高 48 / 项宽 100 / 间距 8 时窗口 0..3、项 2
x=216、最大偏移 107672）、`hlist_harness`（真实宿主 720×1280@420：
列表 [0,144,720,992]、420 px 项宽 / 21 px 间距 / 992 px 项高、窗口 0..2、
点第 0 项写回、中段 50000 px 窗口 112..116、滚到底最大偏移 440259、
末项 x=300 贴右、节点数 ≤ 250、深色）与 `ui_hlist.ast`（第 33 个功能
APK、`dev.aster.uihlist`：1000 卡 / 项宽 160 dp / 横滑 / 点项选中 /
深色与状态回显）。`aui_version()` 14700，trace 第二行 `V0000396C`，三十三个
APK 以 versionCode 60 / 1.47.0 重打包，qemu 72 项全过；截图
`hlist-v1470-0..4.png` 依次是顶部（选中第 1 项）、点中第 0 项、中段
50000 px、滚到底（末项 999 贴右）与深色滚到底。

v1.46.0 新增虚拟网格（对照 HuxerUI `containers.h` / `containers.cpp` 的
`VirtualGrid`）：

1. **只建窗口内的格子**。`aui_vgrid(key, count, cols, min_cell_dp, row_dp,
   on_bind, on_tap, user)` 创建类型 53 容器；`on_bind` 里用
   `aui_vgrid_cell(index)` 建类型 54 的格子，`aui_vgrid_first()` /
   `aui_vgrid_last()` 给出当前窗口（闭区间，格子下标而非行号）。窗口按
   “当前偏移 + 上一帧视口高”换算成行，再乘以列数；上下各多一行。视口高、
   实测列数、间距按 key 跨帧保留，首帧用 480 dp / 1 列保守估计，布局后
   发现视口、列数或间距不同就置 `need_build`，下一拍自动补齐。1000 格示例
   的节点数仍在两百以内（`vgrid_harness` 断言 ≤ 250）。
2. **固定列与自适应列**。`cols > 0` 固定列数；`cols <= 0` 时
   `cols = (内容宽 + 间距) / (min_cell_dp + 间距)`。格宽 = `(内容宽 -
   间距×(cols-1)) / cols`，测量与布局用同一个格宽，文本换行与最终位置
   一致；行/列间距统一复用节点的 `gap`（`aui_gap`）。格子按
   `row = idx / cols`、`col = idx % cols` 绝对定位，
   `x = 内容左 + col×(格宽+间距)`，`y = 内容顶 + row×(行高+间距) - 偏移`。
3. **超长内容继续用整数像素**。网格复用 v1.45 的按 key 分派：
   `g_aui_vgrid_off/max` 以像素存，`scroll_get/set/max/store_max` 新增
   vgrid 分支；拖动位移、惯性步长与 `aui_debug_scroll*` 的“是否像素”判断
   统一走 `virtual_key()`（列表或网格任一命中）。滚动条内容高对网格按
   `行数 × 行高 + 行间距 + 内边距` 计算，裁剪、拖动、惯性、滚动条与
   `aui_scroll` 完全一致（kind 53 已加入 find_scroll / clip / scrollbar
   等全部相关列表）。
4. **点格与接口**。`on_tap` 挂到每个格子，点击时先记录
   `(容器 key, 格子下标)` 再回调；`aui_vgrid_tap_index()` /
   `aui_vgrid_tap_key()` 读取。`aui_vgrid_scroll(key)` 读偏移（px），
   `aui_vgrid_scroll_to(key, px)` 程序化滚动并触发窗口重建；
   `aui_debug_vgrid(key, out)` 输出
   `[x,y,w,h,count,cols,first,last,offset_px]`，
   `aui_debug_vgrid_cell(key, index, out)` 输出格子矩形（不在窗口返回 -1）。

实现细节：格子宽高、列数与内容高都用 i64 中间量，避免 `count × 行高`
在 i32 溢出；`flags` 低 16 位存请求列数、高 16 位存最小格宽（dp），
不增加节点尺寸（AuiNode 仍是 96 B，完整占据 4096 节点池）。新增
`vgrid_test`（离屏 320×240：版本号、4 列、窗口 0..27、格子几何、点格
回读、滚动 480 px 后窗口 36..67、最大偏移 11760、末格 y=192、节点数
< 200、惯性 200 帧后窗口跟随、`cols=0` 自适应 3 列与格宽 106 px）、
`vgrid_harness`（真实宿主 720×1280@420：网格 [0,144,720,992]、3 列 /
315 px 行高 / 21 px 间距 / 226 px 格宽、点第 4 格写回、中段 50000 px、
滚到底末格 y=821 贴底、节点数 ≤ 250、深色）与 `ui_vgrid.ast`（第 32 个
功能 APK、`dev.aster.uivgrid`：1000 格 / 3 列 / 行高 120 dp / 点格选中 /
深色 + 状态回显）。`aui_version()` 14600，trace 第二行 `V00003908`，
三十二个 APK 以 versionCode 59 / 1.46.0 重打包，qemu 70 项全过；截图
`vgrid-v1460-0..4.png` 依次是顶部（选中第 2 格）、点中第 4 格、中段
50000 px、滚到底（末格 999 贴底）与深色滚到底。

真机确认（v1.7）：用户提供的 `trace.txt` 里点击字段后节点数从 11 涨到 49、
命令数 12 → 81，按键持续触发 `N L P F`；`DONE` 后回到 11；再次点字段
键盘能重新打开；中途窗口重建（`W`）后仍正常，无崩溃。即文本池、逐键
标签、焦点与键盘布局在真机上可用。

真机确认（v1.4）：用户提供的 `trace.txt` 里 `A00000001` / `Q00000000`
说明 UI 线程有 looper 且 `attachLooper` 成功；每次触摸都有 `T/x/y`，
坐标与按钮位置一致；命中按钮的 `ACTION_UP` 之后出现**两次** `N L P F`
（一次来自 `on_add/on_dec/on_reset` 的 `aui_invalidate()`，一次来自
`handle_motion` 末尾），按钮外的触点则没有多余重建。即触摸派发、命中
测试、回调执行和 `s0` → `lrintf` 坐标桥都已在真机上验证。

真机确认（v1.5）：用户提供的滚动 `trace.txt` 里 `d00034000`（density 3.25）、
`N00000051`（81 节点）/ `P00000050`（80 命令）；拖动时 `v` 从 0 连续增大到
`0x2738000`（627.5 px，正好是内容减视口的上界）后钳住，回拖一路回到 0
且不出现负值；滚动结束后点列表按钮仍出现两次 `N L P F`，全程无崩溃。
即真机上的滚动偏移、clamp、裁剪重建和滚动后命中都已确认。

真机确认（v1.6）：用户提供的 fling `trace.txt` 里 `g` 初速度约
2178 / −2375 / 2421 / 835 / −1329 / 960 / −890 px/s，随后 `v` 逐帧递减
并在 `0x2738000` 钳住，`h` 正常结束；多次抛掷与反向抛掷都能停在边界，
抛掷后点按钮也仍然命中。即 timerfd → looper → `aui_frame` 的惯性路径在
真机上可用。

真机确认（v1.8，按钮导航）：用户提供的 `trace.txt` 里每次点页面按钮后
都出现 `n` + 新路由，序列为
`n2 → n3 → n2 → n1 → n3 → n1 → n2 → n1 → n2 → n1 → n2 → n1`；
节点数 `N0000000E`（14）稳定，命令数 `P0000000F` / `P00000010`（15/16），
全程无崩溃。说明 push/pop/reset 的按钮导航、页面重建和输入派发在真机
可用。该次 trace 里没有 `k` / `b`，系统 BACK 与根页 finish 没有被触发，
仍需单独确认。

真机确认（v1.14，edge-to-edge）：用户提供的 `trace.txt` 里
`V00002C88`、`O00000024`（Android 16）、`d00034000`（density 3.25）、
`E004E004E`（上下各 78 px = 24 dp），内容区仍是整窗
`i0 j0 o1216 p2688`；截图里标题、图标与计数卡片已经整体避开状态栏，
点击 +/-/Reset 仍能触发 `N L P F`，节点数稳定 15、命令数 14。说明
`sdkVersion` 读取、24 dp 估算、根布局内缩和输入派发在真机上同时成立；
剩下的问题是系统栏图标本身是浅色，在浅色背景上对比度不足（v1.15 的
条带就是针对这一点）。

真机确认（v1.15，系统栏条带）：用户提供的 `trace.txt` 里
`V00002CEC`、`O00000024`、`E004E004E` 与上一版一致，命令数从 14 变成
`P0000000F`（15），节点数仍是 15；截图顶部和底部各是一条深色条带，
时间、电量与手势条都是浅色，落在深色上清晰可见，内容区仍是浅色。
多次点击 `-`/`+`/`Reset` 仍每次触发 `N L P F`，坐标与按钮位置一致。
说明条带绘制、命令数与布局、命中测试在真机上同时成立。

真机确认（v1.16，中文界面）：用户提供的 `trace.txt` 里
`V00002D50`、`O00000024`、`E004E004E`、`N0000000F`、`P0000000F`
与 v1.15 一致；截图里副标题“v1.16 中文界面”、卡片标题“计数”和
“重置”按钮都是汉字，计数变为 2，顶部/底部深色条带与浅色内容区正常。
说明 16x16 CJK 回退字体、UTF-8 字面量、两套字体混排和中文按钮在
density 3.25 的真机上清晰可用，字体体积（325 KB）也没有影响启动。

真机确认（v1.20，选择控件）：用户提供的 `trace.txt` 里 `V00002EE0`
（12000）、`O00000024`、`d00034000`、`E004E004E`、`N0000001F`（31 节点）、
`P0000007C`（124 命令）。两个复选框都选中时命令数是 124；点掉一个后
降到 82/83，再点掉另一个降到 40/41——每个对勾由约 42 条步进矩形拼成
（`paint_line` 逐点 stamp），所以命令数随勾选数量线性变化，也说明
选中态的绘制路径确实在跑。点深色单选项后出现 `m00000001`，点浅色
`m00000000`，整个调色板同帧切换；Reset 后画面回到默认值；最后
`k00000004 b X` 是根页面按 BACK 正常结束。截图里复选框对勾、单选
圆环/圆点、两条滑块与 Reset 都渲染正确，卡片内控件底色是卡片色。
说明 20 dp 控件、2 dp 边框、46 条对勾命令、滑块手势与主题切换在
density 3.25 的真机上同时成立。

未验证（v1.17）：开关与进度条只在 qemu 离屏渲染上验证（44×24 胶囊、
8 dp 轨道、开/关配色、65% 填充）。真机需要确认：density 3.25 下开关
滑块边缘与圆角是否干净、进度条 8 dp 是否太细、点开关后状态文字与
开关同帧更新、以及 `N00000018` / `P00000018`（设备上含系统栏条带两条
命令；qemu 假宿主无安全区，所以是 `P00000016`）。GB2312 之外的汉字、
emoji、系统 IME 输入仍空白。
未验证（v1.18）：按词换行、ui_form 滚动布局目前只在 qemu 离屏
（720×1280，density 2.625）和假宿主上验证。真机需要确认：按钮内单行文字
是否仍有截断、长标签按词换行的观感、键盘弹出时 ui_form 的字段是否仍完整
可见、以及 `N` / `P` 计数变化（ui_hello 仍应为 `N00000018` / `P00000018`，
命令数含系统栏两条）。SHIFT / DEL 像素图标（键高 1/3）已在 720×1280@2.625
和 1080×970@3.25 的离屏帧里确认不压键；24px 文字的发虚问题由 v1.19 处理。
未验证（v1.19）：48px 原生图集把笔画台阶从 2 px 降到 1 px，效果只在 qemu
离屏帧上与 24×2 做过并排对比（720×1280@2.625、1080×970@3.25）。真机需要
确认：density 3.25 下汉字细横不再断线、发虚感消失、混排时汉字与拉丁的
基线差（约 1 px）看不出来；uihello.apk 增大到 2,386,590 字节后安装与首启
时间可接受；trace 第二行按源码应为 `V00002E18`（11800，v1.19 的
字面量没跟上 aui_version 11900；v1.20 已修正）。旧 `font_latin.auf` /
`font_cjk.auf` / 24px 字体只保留兼容与回归测试，不再用于主示例。
未验证（v1.20）：复选 / 单选 / 滑块与 `ui_settings` 只在 qemu 离屏
（720×1280@420dpi，浅色与深色两张帧已目视确认）和 `select_test` 上
验证。真机需要确认：density 3.25 下 2 dp 边框与 10 dp 圆点是否干净、
20 dp 方框里的对勾是否可辨、卡片内复选框内部是否为卡片色（不应出现
页面底色或白色补丁）、滑块拇指 16/18 dp 切换与 4 dp 轨道在真机上的
观感、拖动滑块时不误触外层滚动；`ui_settings` 里深色单选项应在同一帧
切换整个调色板，trace 第二行应为 `V00002EE0`（12000，已在后续真机确认），节点/命令数
会比 v1.19 的 `N00000018` / `P00000018` 更大（`ui_settings` 是全新
包名，首次安装即可）。滑块的键盘/无障碍与系统 IME 仍未涉及。
未验证（v1.21）：分段控件与 `ui_settings` 的 Climate 卡只在 qemu 离屏
（720×1280@420dpi，浅色/深色/滚动/选中四帧已目视确认）和 `segmented_test`
上验证。真机需要确认：density 3.25 下 1 dp 边框与 2 dp 胶囊内缩是否
干净、8 dp 外圆角与 6 dp 胶囊圆角是否协调、选中段深色文字
（`ON_PRIMARY`）是否清晰、cm/in 切换后 Height 数字与单帧内同步更新、
点已选中段不出现闪烁；`ui_settings` 的节点/命令数会比 v1.20 的
`N0000001F` / `P0000007C` 更大（新增 Climate 卡与分段控件），trace
第二行应为 `V00002F44`（12100）。
真机确认（v1.22，标签页）：用户提供的 `trace.txt` 第二行 `V00002FA8`
（12200），`O00000024` / `d00034000` / `E004E004E`，点 Feed / Stats /
More 后页面内容与指示条同步切换，最后 `k00000004 b X` 正常退出；
`N` / `P` 随页面变化，说明页内容确实按当前下标重建。2 dp 指示条与
1 dp 圆角的 1:1 像素观感仍未放大确认。
真机确认（v1.23，形状抗锯齿，部分）：`trace.txt` 第二行 `V0000300C`
（12300），`O00000024` / `d00034000` / `1216×2688` / `E004E004E`，
`N00000018` / `P00000018` 在四次点按 + 区域、一次重置、两次提醒
开关、两次拖动与一次窗口重建（`W`，随后 `J0` / `Y0` 与 `N L P F`）
期间完全不变——AA 只改像素，不改布局与命令数。截图里副标题为
“v1.23 中文界面”，卡片 16 dp 圆角、按钮、开关轨道/拇指与 65% 进度条
端点的过渡自然，没有发灰或毛边，文字仍是 1 px 台阶；窗口重建后界面
恢复正常，没有崩溃。受聊天截图缩放限制，开关拇指/卡片角的 1:1 像素
对比、`ui_settings` 的 1 dp 边框与 `ui_tabs` 的 2 dp 指示条仍未在
真机上放大确认。
v1.8 的系统 BACK 路径只在 qemu 假宿主里验证过（UP 单次触发、
长按不连跳），真机上需要确认不同 ROM 的 action 序列（DOWN/UP）、长按
重复、手势导航，以及根页 `ANativeActivity_finish` 之后的生命周期。
v1.9 的内容区/安全区/旋转/深色也尚未上真机：不同 ROM 的
`onContentRectChanged` 时机与数值、边到边/手势导航的内缩、night 枚举
是否随系统深浅色及时更新，都需以 `trace.txt` 的 `r/s/i/j/o/p/u/m`
为准。v1.14 的 24 dp 只是经验值：不同 ROM 的状态栏/手势条高度、横屏、
刘海/挖孔、三键导航都可能不同，需要真机 `O`/`E` 与 `i j o p` 对照截图
确认；需要精确值时由应用用 `aui_set_insets` 补偿。深色调色板只覆盖
自绘区域，系统状态栏图标颜色无法在不用 Java 的前提下控制；v1.15 的
深色条带只是把浅色图标垫高对比度，`V00002CEC` 的截图已确认时间/电量/
手势条清晰，但刘海/挖孔、横屏、深色主题下条带是否合适仍需更多机型。
如果 ROM 用深色图标，条带反而降低对比度，应用应传
`aui_theme_color(AUI_COLOR_BG)` 关掉条带。v1.7 的
按键手感、density 取整与长文本滚动仍以真机为准；
真实 BufferQueue 行为、16 KB 设备安装同理。真机问题请先看 `trace.txt` /
`p1.txt` 或系统日志。

未验证（v1.30）：下拉刷新只在 qemu 离屏（360×700@density 160）和
720×1280@420dpi 假宿主上验证。真机需要确认：520 dpi 下 3 dp 轨道与
20 dp 环的清晰度、900 ms 一圈的观感、深色下 16% `on_surface` 轨道是否
可见、下拉时列表是否跟手且松手回弹不抖、刷新期间点行是否与系统
列表的行为一致。示例的 700 ms 反馈窗口结束即收起，接入真实网络请求时
应由应用在完成后再把 `refreshing` 置 0。

未验证（v1.45）：虚拟列表只在 qemu 离屏（320×240）与 720×1280@420dpi
假宿主上验证，截图 `vlist-v1450-0..4.png` 已目视确认顶部/选中/中段/
滚到底/深色五个状态。真机需要确认：快速 fling 时窗口重建是否跟得上
（当前是“改变偏移 → 下一拍重建窗口”，理论上会晚一帧）、行高不是整数
像素时窗口边界是否多取/漏取一行、5000 行下滚动条长度与位置的比例观感、
点行与滚动手势的冲突（超过 8 dp 才判定滚动）、以及深色下选中行
`0xFFDCE7FF` 是否过亮。虚拟列表也尚未实现可变行高、粘性分组头、
下拉刷新/分页组合与滚动到指定行（目前只有像素偏移的
`aui_vlist_scroll_to`）。

未验证（v1.47）：横向虚拟列表只在 qemu 离屏（320×240）与 720×1280@420dpi
假宿主上验证，截图 `hlist-v1470-0..4.png` 已目视确认顶部/点项/中段/
滚到底/深色五个状态。真机需要确认：快速横滑时窗口重建是否跟得上
（与虚拟列表相同，改变偏移后下一拍才重建窗口）、项宽不是整数像素时
右边界是否有一像素级差、旋转或分屏导致视口宽变化时窗口重排是否闪一帧、
横向拖动与分页容器（pager）的手势竞争（当前 pager 仍先登记，hlist 应
避免放进 pager 页内）、点项与横向手势的冲突（超过 8 dp 才判定滚动）。
横向虚拟列表尚未实现可变项宽、粘性分组头、按项定位（目前只有像素偏移
的 `aui_hlist_scroll_to`）、RTL 反向布局以及下拉刷新/分页组合。
未验证（v1.48）：按压水波纹只在 qemu 离屏（320×240）与 720×1280@420dpi
假宿主上验证，截图 `ripple-v1480-*.png` 已目视确认顶部/按住 80 ms/
按住 240 ms/淡出/深色五个状态。真机需要确认：60/120 Hz 下 320 ms 扩散
与 220 ms 淡出的观感、快速点按（短于 16 ms）是否来得及出第一帧、长列表
行滚动时按住与 fling 的手势竞争、12% 主色在深色 surface 上是否足够明显、
以及按压态本身（PRESSED 叠色）与波纹叠加后的亮度。波纹尚未实现
“从控件中心扩散”的配置、键盘/焦点触发的 indication、RTL 或自定义颜色。

未验证（v1.46）：虚拟网格只在 qemu 离屏（320×240）与 720×1280@420dpi
假宿主上验证，截图 `vgrid-v1460-0..4.png` 已目视确认顶部/点格/中段/
滚到底/深色五个状态。真机需要确认：快速 fling 时窗口重建是否跟得上
（与虚拟列表相同，改变偏移后下一拍才重建窗口）、格宽不是整数像素时
右边界是否有一像素级差、旋转或分屏导致列数变化时窗口重排是否闪一帧、
自适应模式首帧按 1 列构建造成的短暂空白、点格与滚动手势的冲突
（超过 8 dp 才判定滚动）。虚拟网格尚未实现可变行高、跨列/跨行
（HuxerUI `ItemSpans`）、粘性分组头、按项定位（`ScrollOffsetForItem`，
目前只有像素偏移的 `aui_vgrid_scroll_to`）以及下拉刷新/分页组合。

## 尚未实现

key 协调（每帧重建树，状态/滚动偏移按 key 存）、硬件键盘/系统 IME、
共享元素、颜色/尺寸/弹簧动画、深链、导航状态保存/恢复、
预测性返回、多栈/嵌套导航、光标闪烁、文本选区/长按、多行编辑、
GB2312 之外的汉字、emoji、复杂文本整形（v1.16 已支持 GB2312 6763 字，
但不接系统 IME）、
语义/无障碍、damage 区域、16 位 / 隔行 PNG（8 位、非隔行已支持）、
scroll 内 `weight` 分配（当前按固定高度排列）、fling 的过冲/回弹、
语言/区域切换、系统字体缩放（需要 float）、状态栏/导航栏**图标**配色
（v1.15 只提供背景条带，图标明暗仍由系统主题决定，NDK 无接口）、
刘海/挖孔/三键导航的精确检测（NDK 无 WindowInsets，当前只能 24 dp 估算，
再用 `aui_set_insets` 手动补偿）、每控件单独配色、内容区动画过渡。
