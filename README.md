# AsterUI

AsterUI 是用 Aster 语言自身编写的原生 UI 框架：`NativeActivity` +
自绘软件光栅，**没有 dex / Java / Kotlin**。首目标是 Android
（NativeActivity，不走 GameActivity、不带 dex），无窗口 headless
测试是主要验证方式：写好 test case 就免于手测。

## 这是什么

本仓库是 AsterUI 的独立仓库，由编译器仓库
[Aster](https://github.com/inaniby/Aster.git)（`@ e729840`，含
2026-11-15 scale 1 统一落定后的状态）拆分而来。内容是当时已落地的
整包底座 + 运行时系统字体引擎：

- 底座：v1.48.6 参考实现整包采用（`src/aui.ast` 公共头 +
  `src/aui_impl.ast` 单体实现：系统适配 / 主题 / 页面栈 / 动画 /
  转场 / PNG 解码 / edge-to-edge 安全区 / CJK 回退字体 / 全部
  控件），见 `docs/AsterUI-design.md`。
- 运行时字体引擎：`src/font_runtime.ast` + `src/render/truetype.ast` /
  `src/render/text.ast`（TrueType/CFF/CFF2 光栅化，读设备系统字体或
  用户指定路径的自定义字体；APK 里不带任何字体文件）。
- 旧的编译器侧树 `asterui/`（76 文件：旧版框架、示例、后端、
  工具）**不在本仓库**，仍留在编译器仓库里；本仓库只含新底座。

旧底座自带的 README（v1.48.6 原文，2959 行，含文件清单与各测试
说明）原样保留在 `docs/README-adopted-base.md`；其中出现的
`stdlib/asterui/...` 路径是拆分前的旧布局，读时按本 README 的
新布局换算（`stdlib/asterui/X` → `src/X`，框架源码在 `src/` 下）。

## 布局

```
src/             aui.ast aui_impl.ast font_runtime.ast aster_std.ast（框架源码）
src/render/      truetype.ast text.ast（字体引擎）
assets/          embeds.ast + font8x8.bin strings_en/zh.txt
                 font_cjk16.auf cjk16.txt（@embed 数据）
examples/        全部示例（含 assets/icon48.png/.bin）
tests/           全部测试（含 fixtures、baseline）+ ui-checks.sh
docs/            AsterUI-design.md + README-adopted-base.md
```

`aster_std.ast` 是从编译器仓库 vendored 过来的标准库：1724 行、
零 include 的自包含文件。框架需要它才能独立编译（`font_runtime.ast`
等 include 它），而编译器仓库的 `stdlib/aster_std.ast` 与本仓库
的这份内容一致；vendored 而不是用子模块指回，是因为框架根
是 `src/`，编译时 include 路径必须在本仓库内解析。`src/render/` 与
`assets/` 同样来自编译器仓库旧树 `asterui/render/`、
`asterui/assets/`（字体引擎与 @embed 数据本就属于新底座，只是
当初落在旧树里），拆分时移入。

## 怎么编

用编译器仓库旁边的预编译 Aster 编译器（`../Aster-env/aster`，
找不到时用 `aster-fixed`；套件脚本自动这样找）：

```sh
# 单个对象（--pic 用于 .so / APK，缺省用于 headless 可执行文件）
aster build-obj --pic src/aui_impl.ast -o aui_impl.pic.o
aster build-obj --pic src/font_runtime.ast -o font_runtime.pic.o
aster build-obj --pic src/render/truetype.ast -o truetype.pic.o
aster build-obj --pic src/render/text.ast -o text.pic.o
aster build-obj --pic assets/embeds.ast -o embeds.pic.o
aster build-obj --pic src/aster_std.ast -o std.pic.o
aster build-obj --pic examples/ui_hello.ast -o ui_hello.pic.o

# 链接 .so（16K 页对齐）与 APK（见 tests/ui-checks.sh [27/27] 的完整配方）
aster link-so --soname libcounter.so --needed liblog.so --needed libandroid.so \
    --needed libc.so --needed libm.so --page-size 16384 \
    aui_impl.pic.o font_runtime.pic.o truetype.pic.o text.pic.o embeds.pic.o \
    std.pic.o ui_hello.pic.o -o libcounter.so
aster build-apk libcounter.so -o counter.apk --package com.example.asterui.counter \
    --libname counter --abi arm64-v8a --label "AsterUI Counter" \
    --min-sdk 24 --target-sdk 35 --page-size 16384 \
    --version-code 17 --version-name 2.6.2 --keystore-dir keys
aster verify-apk counter.apk
```

`build-obj` / `link-obj` / `build-so` / `link-so` / `build-apk` /
`verify-apk` / `doctor` 的完整用法见编译器 `aster --help`。

## 怎么跑套件

```sh
sh tests/ui-checks.sh
```

套件是双模式的（见 `tests/ui-checks.sh` 头部注释）：

- **独立模式**（本仓库单独检出）：只跑新底座 `[22/27]–[27/27]`
  （6/6）；旧树 `[1/27]–[21/27]` 不在本仓库里，打印 SKIP 行后
  跳过，不报错。`[27/27]` 里 IME 探针 APK 也跳过（探针源码只在
  旧树 `asterui/examples/ime-probe/`，不在本仓库布局内），
  Counter + Gallery 两个 APK 正常编。
- **挂载模式**（本仓库挂载在编译器仓库的 `stdlib/asterui/`
  位置，见下）：跑全套 28 行 PASS，`[1/27]–[21/27]` 21/21 +
  `[22/27]–[27/27]` 6/6。

编译器用哪个、预期结果是什么：

- `../Aster-env/aster-fixed`：全套件预期全绿（独立模式 6/6 +
  旧树 SKIP；挂载模式 28 行 PASS）。`[26/27]` link gate
  43/43 链接且 43/43 跑绿（含 `canvas_test`）。
- `../Aster-env/aster`（旧二进制）：预期停在 `[23/27]` H-3
  （`font_runtime_test` 链接，C-1 原文），`[22/27]` 通过。

## 与编译器的子模块关系

本仓库挂载在编译器仓库的 `stdlib/asterui/` 位置（git 子模块，
远端待定）。编译器侧的旧树 `asterui/`（76 文件）去留未定：
拆分后它仍是旧树测试 `[1/27]–[21/27]` 的唯一来源，删之前须先
把旧树测试迁到新底座或另行安置。

LICENSE 未定：本仓库暂不带 LICENSE 文件，遗留问题，留给用户定。

## 版本

当前状态：Canvas 自定义绘图节点 v2.6.2（Counter 17 / Gallery 16），
见 `ADOPTION-NOTES.md` 末尾三节。
