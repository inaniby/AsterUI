# AsterUI 架构设计

**Aster 的原生 UI 标准库 —— 没有 dex、没有 Java/Kotlin 壳、全部原生实现**

| 项目 | 内容 |
|---|---|
| 基线 | Aster `v0.23.54-dev`（本地构建验证） |
| 架构参考 | HuxerUI（保留其架构骨架，替换其 Java Canvas/浮点实现） |
| 日期 | 2026-10-27 |
| 状态 | 设计稿 v1，可进入 M0 |
| 交付形态 | `stdlib/asterui/` + 单 `.so` + NativeActivity APK（`hasCode=false`） |

---

## 0. 一页结论

AsterUI 是一个**保留树 + 立即声明 + 自绘**的 UI 运行时：应用在 `build` 回调里按顺序声明 UI，运行时按 `key` 复用节点，用 Q16.16 定点完成测量/布局，用位图字体完成文本，用软件光栅把显示列表画进 `ANativeWindow` 的 RGBA/RGBX/RGB565 缓冲区，输入从 `AInputQueue` 进入，帧从 `AChoreographer` 驱动。整个 APK 里没有 `classes.dex`，Activity 是系统框架自带的 `android.app.NativeActivity`，应用只提供一个 `lib*.so` 和 `ANativeActivity_onCreate`。

关键决策：

1. **不碰 Android View / Compose / appcompat**。任何 View 的构造与 inflate 都是 Java API，走这条路必然需要 dex 或 JNI 壳，违反硬约束。唯一干净的路线是 NativeActivity + 自绘。
2. **先软件光栅，后 GPU**。Aster 没有 float，EGL/GLES 的接口大量使用 float；软件光栅用整数即可完成，且被 `native_render.ast` / `icon_text_demo.ast` 证明可行。显示列表保留清晰的 GPU 后端接口，M4 以后再接。
3. **Q16.16 定点几何**。没有 f32/f64，布局、动画、命中测试全部用 Q16.16（i32，16 位小数），乘法用 i64 中间量。
4. **位图字体，不做 TTF/shaping**。字体是 `@embed` 进 `.so` 的位图图集（`.auf`），UTF-8 解码后按码点查表；不支持复杂文本整形、双向文本和任意字号。这是 v1 的明确边界。
5. **固定容量、零堆分配**。节点池、命令池、状态表全部是 `.bss` 里的静态数组；每帧不 malloc，不触发 GC（Aster 也没有 GC）。节点池用「i64 数组做 8 字节对齐后备存储、再视作结构体数组」的技巧，绕过「含 ptr 字段的全局结构体数组不能用字面量初始化」的限制（已编译验证）。
6. **公共 API 不暴露结构体**。节点句柄是 `i32`，用户状态是 `ptr`，字符串是 UTF-8 `ptr`。这不是语言限制（Aster 的 `include` 实际会共享 struct 定义，见 §2.2），而是 ABI 与演进策略：内部节点布局可以随时改，应用代码不受影响。
7. **v1 不需要修改编译器**。两个已知摩擦点都有局部绕法：i64 复合移位有 codegen bug（用临时变量绕开），`AMotionEvent_*` / `AKeyEvent_*` 不在 NDK 库映射表里（`link-so` / `build-so` 加 `--needed libandroid.so` 绕开）。真正值得上游修的是前者。

---

## 1. 目标、非目标与硬约束

### 1.1 目标

- 给 Aster 应用提供一套**开箱即用**的 UI：容器（column/row/stack/scroll）、文本、按钮、图片、焦点、点击/长按/滚动、主题、密度适配、动画。
- 以**标准库**形式随 Aster 分发：`include "asterui/aui.ast";` 并把 `aui_impl.o` 链入应用 `.so`，不引入外部包管理器。
- 产物是**单个 `.so`**，由 `aster build-apk` 打进 NativeActivity APK；APK 内无 dex、无 Java/Kotlin 代码、无 JNI。
- 在 AArch64 Android（API 24+，16 KB page）上可运行；同一套核心可在 headless 后端做确定性测试。

### 1.2 硬约束：什么叫「不用壳」

- APK 内**不出现 `classes.dex`**（构建后必须用 `unzip -l` 断言）。
- 不自带 Java/Kotlin 类；Activity 使用框架的 `android.app.NativeActivity`，manifest 写 `android:hasCode="false"`。
- 不通过 JNI 调用 Java 对象；不依赖 `native_app_glue`、GameActivity、Jetpack、Compose。
- 所有 UI 逻辑、布局、绘制、输入处理都在 Aster 代码里完成。

> 说明：Android 框架本身是 Java 实现的，`NativeActivity` 也是框架类。这是系统的一部分，不在应用 APK 里。「无 Java 壳」指的是**应用不携带、不编写、不绑定任何 Java/Kotlin 代码**，而不是让 Android 系统停止用 Java。Aster 已经支持这条路：`build-apk` 生成的 manifest 就是 `android.app.NativeActivity` + `hasCode=false`（本设计已实测打包并检查，见附录 A）。

### 1.3 非目标（v1 明确不做）

- 通用 2D 渲染引擎、Skia 替代品、矢量图形/路径填充。
- TTF/OTF 解析、字形整形（shaping）、连字、双向文本、复杂 emoji。
- TalkBack/无障碍服务桥接（没有 Java 壳就无法注册 `AccessibilityNodeProvider`）。
- 完整的输入法组合文本（候选词、composing region）、剪贴板、富文本编辑。
- 多窗口/多 Activity 单进程 UI、跨进程渲染。
- 热重载、动态资源包、运行时下载字体。

这些不是「以后顺手做」的列表，而是**由硬约束推导出的边界**；其中相当一部分在「无 Java 壳」前提下永远无法完整实现，文档会在对应章节明确标注。

---

## 2. Aster 的语言/运行时事实，以及它们对设计的硬性影响

这一节只列会改变架构的事实，全部以 `docs/language-reference.md`、`ARCHITECTURE.md`、`FEATURE_STATUS.md` 和本机编译结果为准。

### 2.1 类型与语法

| 事实 | 设计后果 |
|---|---|
| 有 `i32/u32/u8/u16/i64/u64/ptr/ptr<T>/bool/struct/fn`，**没有 f32/f64** | 几何、动画、透明度全部定点；不调用任何返回 float 的 NDK 接口（`AMotionEvent_getX` 用 `lrintf` 桥接） |
| **没有 `void`**，函数必须返回值 | 所有回调统一 `-> i32`；`0` 表示成功/未处理 |
| 没有 enum/union/const/typedef/namespace/generics/closures/methods | 用 `i32` 常量 + 全局数组 + 顶层函数；回调必须是有名字的顶层函数，**不能写匿名闭包** |
| 函数指针是一等类型，可作参数、返回值、结构体字段 | 事件回调、`build` 回调、按钮回调都直接传函数名 |
| `ptr` 可隐式转 `ptr<T>`，`ptr<T>` 也可赋给 `ptr` | 公共 API 用裸 `ptr` 做不透明句柄，库内转成 `ptr<AuiNode>` |
| 源码标识符限 ASCII；**字符串字面量可以含 UTF-8**（实测 `"你好"` 编成 7 字节 rodata） | 简单应用可以直接写中文文案；正式项目仍建议 `@embed` 文本表 |
| 移位/位运算已支持（`<<`、`>>`、`&`、`^`、`~` 等），但 i64 复合表达式移位有 codegen bug（见 §18.1） | 定点乘法先存临时变量再移位；提供 `auix_fx_mul` 封装，业务代码不直接写移位 |

### 2.2 `include` 的真实语义（重要更正）

Aster 的 `include` 是**链接期头文件机制**，不是文本拼接。实测与 `examples/include_demo_*` 的官方说明一致：

- `include "a.ast";` 之后，**包含方可以使用被包含文件里的 struct 定义**（`ptr<N>`、`p.a` 都合法）。
- 被包含文件的**函数体不会被编译进包含方**；`mergeIncluded` 只复制函数/全局的声明（`external=true`，`body.clear()`）。函数体必须由被包含文件**自己作为顶层源文件编译**成 `.o`，再链接进来。
- 被包含文件的全局变量只传「名字 + 类型」，初始化器留在原文件；原文件必须单独编译，否则符号未定义。
- 被包含文件看不到包含方在后面定义的 struct（按解析顺序）。
- 同一个 struct 重复定义报 `duplicate struct declaration`；同一个文件多次 include 只展开一次。
- 头文件里**不能写无函数体的原型**（`fn f() -> i32;` 报 `expected '{'`），必须写 `extern fn f() -> i32;` 和 `extern let g: i32;`（两者均已实测）。

结论：

- **公共头文件可以用 `extern fn` / `extern let` 干净地声明 API**，实现在另一个 `.o` 或 `.so` 里。
- **struct 可以出现在公共头文件里**（所有使用方都 include 同一个头文件即可）；AsterUI 仍选择不暴露内部节点结构体，理由是 ABI 稳定和封装，而不是语言限制。
- 不能用「把所有实现 include 进一个文件」的方式做 amalgamation；正确做法是**把实现文件分别编译成对象，再 `link-obj` / `link-so` 合进一个 `.so`**。

库的组织规则：

- `aui.ast`：公共头文件，只有 `extern fn` / `extern let` 声明、回调类型、常量、可选的 `AuiEvent` 小结构体。
- 实现文件（`tree.ast`、`layout.ast` 等）：各自包含 `aui.ast` 和一份私有头 `auix_internal.ast`（内部 `extern fn` / `extern let` 声明），分别 `build-obj --pic`，最后 `link-so`。
- 跨文件只传 `i32` / 裸 `ptr` / 标量；模块内部各自持有自己的 struct。这样每个实现文件的函数体都能独立编译。

### 2.3 栈、数组、结构体限制

| 限制 | 设计后果 |
|---|---|
| 每个函数固定 8 KiB 栈帧 | 树遍历**不用递归**：先产出前序数组，再正/反向迭代；递归只用于深度可控的小函数 |
| struct ≤ 1024 字节 | 节点 96 B、命令 64 B，远低于上限 |
| 局部数组 ≤ 1000 元素 | 遍历栈/临时数组用全局固定数组或 ≤ 1000 的局部数组 |
| 全局数组 ≤ 1,048,576 元素 | 节点池 4096、命令池 4096，余量充足 |
| 无堆/无 GC | 固定容量池 + 空闲链表；应用自己的动态数据由应用用 `mmap` 或静态数组解决 |

### 2.4 运行时与系统调用

- `mmap` / `brk` 可用，但**失败返回值是 `-errno` 编码在 `ptr` 里，Aster 无法把 `ptr` 转成整数**，因此无法可靠判断失败（现有 `examples/arena.ast` 只判断 null，不够）。
- 设计选择：**v1 核心不使用 `mmap`**。所有池都是 `.bss` 静态数组，容量编译期确定，启动即用。应用若需要大缓冲区（例如图片解码），自行承担 `mmap` 失败风险，或使用静态数组。
- `load_u8/store_u8/load_u16/store_u16/load_i64/store_i64/load_ptr` 是像素与二进制解析的基本工具；所有字体/图片/字符串 blob 都用这些函数按小端解析，避免未对齐的结构体读取。

### 2.5 APK 工具链事实（实测）

- `build-apk` 生成 `android.app.NativeActivity`、`hasCode=false`、二进制 AXML、`resources.arsc`、图标、v1+v2 签名。
- `build-apk` 接受 `.so` 或 `.ast`；但 **`--needed` 只属于 `build-so`/`link-so`**，`build-apk` 不接受（实测报 `unknown option --needed`）。因此正确流程是：先用 `build-so` 或 `link-so`（带 `--needed`）产出 `.so`，再 `build-apk app.so`。
- APK 内容实测只有：`AndroidManifest.xml`、`resources.arsc`、`res/drawable-nodpi/ic_launcher.png`、`lib/arm64-v8a/lib*.so`、`META-INF/*`，**没有 `classes.dex`**。
- `--page-size 16384` 可用，`targetSdk 35` 建议使用；`verify-apk` 通过。
- `ndkLibraryFor` 已映射 `ANativeActivity_`、`AConfiguration_`、`ALooper_`、`AInputQueue_`、`AInputEvent_`、`AChoreographer_`、`ANativeWindow_` 等；**没有映射 `AMotionEvent_` 和 `AKeyEvent_`**，它们会落到 `libc.so`。加 `--needed libandroid.so` 后，运行时从已加载的 libandroid 解析，实测 `DT_NEEDED` 为 `libandroid.so / libc.so / libm.so`。

---

## 3. 总体架构

### 3.1 分层

```
┌──────────────────────────────────────────────────────────────┐
│ 应用 (Aster)                                                  │
│   build(user) / 回调 / 应用状态                                │
├──────────────────────────────────────────────────────────────┤
│ 公共 API  aui.ast                                             │
│   aui_root/column/row/stack/scroll/pad/label/button/...       │
│   aui_android_attach / aui_invalidate / aui_state_*           │
├──────────────────────────────────────────────────────────────┤
│ 核心运行时 (Aster, 实现文件编译为 .o)                          │
│  session  会话、帧调度、失效标志、容量配置                       │
│  tree     节点池、构建器、key 复用、剪枝                         │
│  layout   Q16.16 测量/排列、dp→px、滚动                          │
│  text     UTF-8、位图字体 .auf、测量、换行                       │
│  paint    显示列表、裁剪、dirty rect                             │
│  raster   软件光栅：填充、圆角、alpha、字形、565 转换            │
│  input    指针会话、命中测试、手势、焦点、键盘                    │
│  anim     定点补间、帧时钟                                       │
│  semantics 语义记录（测试/未来无障碍）                            │
├──────────────────────────────────────────────────────────────┤
│ 平台适配层                                                     │
│  android/  ANativeActivity + ANativeWindow + AInputQueue +     │
│            AChoreographer + AConfiguration                    │
│  headless/ 内存缓冲区 + 脚本事件（CI）                          │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 线程模型

- **单 UI 线程**：`ANativeActivity_onCreate`、输入回调、Choreographer 回调都在 Android 主线程的 looper 上；AsterUI 不创建线程，不做锁。
- 所有状态（节点树、池、命令、焦点）只被 UI 线程访问。
- 如果未来要解码图片，另行开工作线程，只把结果指针交回 UI 线程；v1 不做。

### 3.3 打包形态

**v1：单 `.so`（推荐，已用两个对象验证链接）**

应用与 AsterUI 的实现文件分别编译成 PIC 对象，再由 `link-so` 合成一个 `.so`：

```
build-obj --pic app/main.ast            -> main.o
build-obj --pic stdlib/asterui/impl.ast -> aui_impl.o
link-so main.o aui_impl.o --needed libandroid.so ... -> libmyapp.so
```

没有跨 `.so` 符号问题，没有 `DT_NEEDED` 版本问题；Aster 的一次编译一个源文件、再链接对象的方式正好匹配这个模型。注意：**不能靠 include 把实现文件拼进 app.ast**——include 只带声明，函数体不会被编译（§2.2）。

**v2：`libasterui.so` + 应用 `.so`**

`build-so` 产出 `libasterui.so`（`--soname libasterui.so --needed libandroid.so`），应用 `link-so --needed libasterui.so`。APK 里仍无 dex，但 `build-apk` 目前只打包一个 `.so`，要支持第二个 native 库需要扩展打包器或手工重打包；因此 v2 不作为 v1 承诺。符号全部默认导出，靠前缀纪律避免冲突。

---

## 4. 公共 API

### 4.1 设计原则

- **句柄是 `i32`**：节点 id / 状态 key / 资源 id 都是 `i32`，不是指针。应用无法解引用内部结构。
- **用户状态是 `ptr`**：应用传自己的结构体指针，库只转交，不解引用。
- **字符串是 UTF-8 `ptr`**：NUL 结尾；另提供带长度的变体，支持 `@embed` 的非 NUL blob。
- **回调统一 `fn(ptr) -> i32`**：`ptr` 是声明时传入的 `user`。没有闭包，所以每个按钮要么有独立顶层函数，要么在同一个回调里靠 `user` 区分。
- **所有构建函数返回 `i32`**：返回节点 id 或 `0`；应用可以忽略返回值（Aster 允许裸调用语句）。
- **单位是 dp**：`pad/gap/radius/spacer` 等接收 dp 整数，库内用 density 转 Q16.16 px；布局结果永远是 Q16.16 px。

### 4.2 公共头文件（节选）

```aster
// aui.ast -- AsterUI public surface (v1)
// 只有 extern 声明；无内部 struct；句柄 i32；用户状态 ptr；字符串 UTF-8。

// ---- 会话 ----
extern fn aui_android_attach(activity: ptr, saved: ptr, saved_size: i64,
                             build: fn(ptr) -> i32, user: ptr,
                             init: fn(ptr) -> i32, flags: i32) -> i32;
extern fn aui_frame(now_ns: i64) -> i32;          // 手动泵帧（headless/自定义宿主）
extern fn aui_invalidate() -> i32;                 // 重建 + 布局 + 重绘
extern fn aui_invalidate_layout() -> i32;          // 只重新测量/排列 + 重绘
extern fn aui_shutdown() -> i32;

// ---- 构建（在 build 回调内按顺序调用）----
extern fn aui_root() -> i32;
extern fn aui_column(key: i32) -> i32;
extern fn aui_row(key: i32) -> i32;
extern fn aui_stack(key: i32) -> i32;
extern fn aui_scroll(key: i32) -> i32;
extern fn aui_pad(dp: i32) -> i32;                 // 修饰最近创建的节点
extern fn aui_gap(dp: i32) -> i32;
extern fn aui_weight(w: i32) -> i32;
extern fn aui_align(a: i32) -> i32;                // 0 start / 1 center / 2 end / 3 stretch
extern fn aui_bg(color: u32) -> i32;               // 0xAARRGGBB
extern fn aui_radius(dp: i32) -> i32;
extern fn aui_label(key: i32, text: ptr) -> i32;
extern fn aui_label_n(key: i32, text: ptr, len: i32) -> i32;
extern fn aui_text_i32(key: i32, value: i32) -> i32;
extern fn aui_button(key: i32, text: ptr, cb: fn(ptr) -> i32, user: ptr) -> i32;
extern fn aui_spacer(key: i32, dp: i32) -> i32;
extern fn aui_image(key: i32, rgba: ptr, w: i32, h: i32) -> i32;
extern fn aui_end() -> i32;

// ---- 状态（按 i32 key 存取的 256 个 i32 槽）----
extern fn aui_state_get(key: i32) -> i32;
extern fn aui_state_set(key: i32, value: i32) -> i32;

// ---- 焦点/文本 ----
extern fn aui_focus(key: i32) -> i32;
extern fn aui_text_value(key: i32) -> ptr;
```

说明：

- `aui_image` 接收裸 RGBA8888 像素（来自 `@embed`），不负责解码 PNG/JPEG。v1 需要应用离线转成 RGBA；M3 再考虑加一个最小的 PNG 解码器（需要 inflate，工作量大）。
- `aui_text_i32` 内部用 scratch 缓冲格式化十进制；不提供通用 `printf`。
- 没有 `aui_label_fmt`：Aster 没有可变参数，格式化由库内固定函数完成。
- `aui_state_*` 只保存 `i32`；复杂状态由应用自己持有，通过 `user` 指针访问。

### 4.3 最小应用

```aster
include "asterui/aui.ast";

struct App {
    count: i32
}

let g_app: App = App { 0 };

fn on_add(user: ptr) -> i32 {
    let a: ptr<App> = user;
    a.count = a.count + 1;
    aui_state_set(1, a.count);
    aui_invalidate();
    return 0;
}

fn app_build(user: ptr) -> i32 {
    let a: ptr<App> = user;
    aui_root();
    aui_column(1);
    aui_pad(24);
    aui_gap(12);
    aui_label(2, "AsterUI");
    aui_text_i32(3, a.count);
    aui_button(4, "Add one", on_add, user);
    aui_end();
    return 0;
}

fn app_init(user: ptr) -> i32 {
    return 0;
}

fn ANativeActivity_onCreate(activity: ptr, saved: ptr, savedSize: i64) -> i32 {
    return aui_android_attach(activity, saved, savedSize,
                              app_build, &g_app, app_init, 0);
}
```

要点：

- `ANativeActivity_onCreate` 必须由**应用**导出，`aui_android_attach` 负责写回调表。
- `&g_app` 是 `ptr<App>`，传给 `user: ptr` 合法（实测）。
- 回调里改完状态必须 `aui_invalidate()`，否则不会重画。
- `aui_end()` 必须与每个容器配对；调试构建可以检查深度并记录错误。
- 示例只 include 了头文件；构建脚本还必须把 `aui_impl.o` 链进来（§16.2），否则 `aui_*` 符号未定义。

### 4.4 构建器不变量

1. `aui_root()` 开始一次构建，重置构建深度与游标；之前的树进入「可复用」状态。
2. 每个 `aui_*` 容器/叶子都在**当前父节点**的尾部追加。
3. `aui_pad/gap/weight/align/bg/radius` 修饰**最近创建**的节点，必须紧跟在该节点之后、其子节点之前。
4. `aui_end()` 关闭最近打开的容器；根节点不需要 `aui_end`（或允许一次）。
5. 一次构建中未再出现的旧节点在构建结束后剪枝；剪枝顺序为后序，避免递归。
6. 构建期间不能调用 `aui_invalidate()` 之外的重入操作；构建函数本身不应递归调用 `build`。

---

## 5. 内存模型

### 5.1 固定容量

所有核心数据都是编译期固定容量，启动时清零，运行中不增长：

| 池 | 容量 | 单元素 | 占用 | 说明 |
|---|---|---|---|---|
| 节点池 | 4096 | 96 B | 384 KiB | 树节点、修饰符、回调 |
| 命令池 | 4096 | 64 B | 256 KiB | 显示列表 |
| 状态槽 | 256 | 4 B | 1 KiB | `aui_state_*` |
| 文本 scratch | 16384 | 1 B | 16 KiB | `aui_text_i32` / 编辑缓冲 |
| 遍历数组 | 4096 | 4 B | 16 KiB | 前序 id 数组 |
| 字体/字符串 | 由 `@embed` 决定 | — | 通常 < 512 KiB | 只读 rodata |
| **合计（不含字体）** | | | **≈ 673 KiB** | 单 `.so` 的 `.bss` |

超出容量的行为：`auix_alloc_node` 返回 `-1`，构建器丢弃该节点并置错误标志；不崩溃、不越界。调试构建可以在 logcat 打印 `node pool exhausted`。

### 5.2 BSS 池技巧（已编译验证）

Aster 不允许「含 `ptr`/函数指针字段的全局结构体数组」用字面量初始化：

```aster
struct N { a: i32, p: ptr }
let g: N[16] = N { 0, 0 };   // error: global struct field 'N.p' cannot be initialized by a constant
let g: N[16];                // error: expected '=' in global variable declaration
```

但**允许**先声明一个 8 字节对齐的 `i64` 数组，再把它视作结构体数组：

```aster
let g_pool: i64[49152] = 0;              // 384 KiB = 4096 节点 x 96 B
let g_nodes: ptr<AuiNode> = g_pool;      // 全局初始化，链接器重定位
```

这样内存是零初始化的（等价于所有 `ptr` 为 0），节点通过 `g_nodes + i * sizeof(AuiNode)` 访问。已用包含 `ptr` 与 `fn(ptr)->i32` 字段的结构体验证：编译、链接、字段读写、回调调用全部通过。这是 AsterUI 能做到「零堆」的关键技巧。

> 注意：`i64` 保证 8 字节对齐；不要用 `i32`/`u8` 数组做后备存储，否则指针字段可能未对齐（AArch64 通常允许非对齐访问，但不要依赖）。

### 5.3 为什么 v1 不用 `mmap`

- `mmap` 失败时返回 `-errno` 编码的指针值；Aster 无法把它转成整数，也无法与 `0` 之外的值可靠比较。应用会拿到一个非 null 的非法指针，首次访问即崩溃。
- 固定容量已经够用：4096 节点 ≈ 数百个屏幕控件；如果不够，应用应该分页/虚拟化列表，而不是扩大池。
- 不用 `mmap` 就没有「分配失败检测」这个编译器缺口，v1 的依赖面更小。
- 应用如果需要大图/大文本缓冲，可以自己 `mmap`，并接受「失败即崩溃」的边界；库不替应用分配。

### 5.4 节点布局（96 B）

```
kind        i32   节点类型（root/column/row/stack/scroll/label/button/image/spacer）
flags       i32   位标志：measured/arranged/visible/pressed/focusable/focused/clip...
key         i32   应用提供的稳定 key
parent      i32   父节点 id，-1 表示根
first_child i32   第一个子节点 id，-1 表示无
next_sibling i32  下一个兄弟 id，-1 表示无
x, y, w, h  i32   布局结果，Q16.16 px
pad         i32   内边距，Q16.16 px
gap         i32   子节点间距，Q16.16 px
weight      i32   行/列权重，Q16.16
align       i32   对齐方式
bg          u32   背景色 0xAARRGGBB
scroll_y    i32   滚动容器内容偏移，Q16.16 px
text_len    i32   文本字节数（-1 表示 NUL 结尾）
text        ptr   UTF-8 文本
cb          fn(ptr) -> i32   点击回调
user        ptr   回调 user
```

合计 17×4 + 4 B 对齐填充 + 3×8 = 96 B。`text_len = -1` 时用 `load_u8` 找 NUL，适合字面量与 `@embed` 文本；`aui_label_n` 设具体长度，避免扫描。

### 5.5 命令布局（64 B）

```
op     i32   fill_rect / round_rect / text / image / push_clip / pop_clip
flags  i32   保留
x,y,w,h i32  目标矩形（整数 px）
color  u32   颜色
aux    i32   圆角半径 / 字体 id / 图片格式
cx,cy,cw,ch i32  裁剪矩形（整数 px）
len    i32   文本字节数
data   ptr   文本指针 / 像素指针
```

命令池同样用 `i64` 后备数组 + 指针转型。每条命令自带裁剪矩形，光栅器不需要维护裁剪栈的状态机，逻辑更简单，代价是每条命令多 16 B。

---

## 6. 声明、协调与状态

### 6.1 一次构建的流程

```
aui_root()
  depth = 0
  root = alloc_or_reuse(0, key=0)
  stack_node[0] = root; stack_cursor[0] = root.first_child; epoch++
aui_column(key)
  node = take_child(current_parent, key)   // 复用或新建
  stack_node[++depth] = node
  stack_cursor[depth] = node.first_child
aui_label(key, text)
  node = take_child(current_parent, key)
  node.kind = LABEL; node.text = text
aui_end()
  depth--
构建结束
  prune_unseen(root)
  measure/arrange
  emit display list
```

`take_child(parent, key)`：

1. 从 `stack_cursor[depth]` 开始，最多向后看 32 个兄弟，找 `key` 相同且本轮未见过的节点。
2. 找到：复用，标记 `seen = epoch`，把游标移到它的下一个兄弟。
3. 找不到：从空闲链表取一个节点（或池尾分配），插到「本父节点最后一个已见节点」之后，标记 `seen = epoch`。
4. 返回节点 id。

这个策略对「顺序稳定、偶发插入/删除」的界面是 O(1) 摊销；对频繁重排的列表，最坏是 O(32n)。v1 接受这个上限，并在文档中要求：**同一父节点下，key 应保持相对顺序稳定**；需要排序时，key 用稳定 id（而不是索引）。

### 6.2 复用与剪枝

- 每个节点有 `seen` 标志（存放在 `flags` 的某一位）。
- 构建结束后，对每个父节点遍历子链表：`seen != epoch` 的节点从链表摘除，整棵子树进入空闲链表。
- 摘除子树用显式栈数组（≤ 128 深）后序遍历，避免递归和 8 KiB 帧叠加。
- 空闲链表是节点 id 的单链表（复用 `next_sibling` 字段），分配时优先取空闲节点，保证内存不碎片化。
- 复用节点保留：`cb/user/text/bg/scroll_y` 等应用数据；布局结果会在本轮重新计算并覆盖。
- 节点 id 在一次会话内稳定，但**不保证跨构建稳定**；应用不要把节点 id 存进业务状态。

### 6.3 状态归属

| 状态 | 存放位置 | 生命周期 |
|---|---|---|
| 业务数据（计数、列表、选中项） | 应用自己的 struct/global | 应用控制 |
| 简单整数 UI 状态 | `aui_state_*` 的 256 个槽 | 会话内；可序列化 |
| 滚动偏移 | 节点 `scroll_y` | 节点复用则保留 |
| 焦点 | 会话的 `focused` id | 跨构建保留（按 key 重定位） |
| 文本编辑缓冲 | 库的 scratch + 节点 key | 跨构建保留 |
| 动画 | 动画槽（M3） | 按 key 绑定 |

`aui_state_*` 的 key 是应用自定义的 `i32`，库不做命名空间管理；建议用常量文件集中定义。

### 6.4 与 HuxerUI 的对应

HuxerUI 的 `View`/`ViewSpec` + `RecomposeScope` + `MountedNode` 对应 AsterUI 的「构建器 + `aui_invalidate` + 节点池」：

- `ViewSpec` 是不可变描述，AsterUI 的构建调用序列就是描述。
- `RecomposeScope` 的失效传播，AsterUI 用**全局失效标志**替代：`aui_invalidate()` 置位，下一次 vsync 整棵树重建。v1 不做细粒度「只重建某个子树」；这是有意的简化，换来实现规模和可预测性。
- `MountedNode` 对应节点池里的 `AuiNode`，但 AsterUI 的节点同时承担布局与绘制数据，没有单独的 RenderNode 层。
- HuxerUI 用 `key` 做协调；AsterUI 同样用 `key`，但复用窗口限定为 32 个兄弟，超出即新建。

---

## 7. 布局

### 7.1 Q16.16 定点

```aster
fn auix_fx(v: i32) -> i32 { return v << 16; }

fn auix_fx_mul(a: i32, b: i32) -> i32 {
    let t: i64 = i64(a);
    let u: i64 = i64(b);
    let p: i64 = t * u;          // 先存临时变量：直接写 (t*u)>>16 会触发 codegen bug
    return i32(p >> 16);
}

fn auix_fx_div(a: i32, b: i32) -> i32 {
    let n: i64 = i64(a) * 65536;
    return i32(n / i64(b));
}

fn auix_fx_round(v: i32) -> i32 { return (v + 32768) >> 16; }
```

约定：

- 所有几何值非负；`auix_fx_round` 只对非负值做「加半再右移」，负数不参与布局。
- Q16.16 的 i32 范围约 ±32768 px，足够手机屏幕；乘法先升 i64，避免溢出。
- 不做「像素级亚精度保留」：布局阶段保留 Q16.16，排列阶段取整到整数 px（§7.5）。
- 动画同样用 Q16.16；透明度用 0..255 整数。

### 7.2 dp 与 density

```aster
// density 是 Q16.16 比例：160 dpi = 65536，420 dpi = 172032
fn auix_dp_to_fx(dp: i32) -> i32 {
    return auix_fx_mul(auix_fx(dp), g_density);
}
```

- `g_density` 在 attach 时从 `AConfiguration_getDensity` 读取（返回 DPI 整数），计算 `dpi * 65536 / 160`。
- 读不到时回退 160 dpi（比例 1.0）。
- 字体不按 density 缩放：字体图集是固定像素尺寸，按「最近档位」选择（12/16/24 px），保证字形清晰。
- `onContentRectChanged` 更新可用内容区；`onNativeWindowResized` 重新布局。

### 7.3 测量与排列：两遍、迭代

不使用递归，避免 8 KiB 帧叠加：

1. **前序收集**：从根开始，用显式栈把节点 id 填入 `g_order[0..n)`。子节点按兄弟链顺序入栈（逆序压栈以保持正序访问）。
2. **反向测量**：`i = n-1 .. 0`，此时所有子节点已测量。根据节点类型与可用宽度计算 `w/h`（Q16.16）。
3. **正向排列**：`i = 0 .. n-1`，父节点已确定位置，给每个子节点分配 `x/y/w/h`；容器负责内边距、间距、权重。
4. **emit**：正向再走一遍，产出显示列表。

复杂度 O(n)，内存是固定的 `g_order` 数组。

### 7.4 容器规则

| 容器 | 测量 | 排列 |
|---|---|---|
| column | 宽 = 可用宽；高 = pad*2 + Σ子高 + gap*(n-1) | 子节点纵向排列；`weight > 0` 的子节点瓜分剩余高度 |
| row | 高 = 可用高；宽 = pad*2 + Σ子宽 + gap*(n-1) | 子节点横向排列；`weight` 瓜分剩余宽度；交叉轴默认 stretch |
| stack | 默认取最大子节点尺寸；显式 `w/h` 可覆盖 | 所有子节点左上角对齐，后声明的在上层 |
| scroll | 宽 = 可用宽；高 = 可用高（视口） | 内容按 column 排列，超出视口部分裁剪；`scroll_y` 平移 |
| label | 宽 = 文本宽度（可换行时取 max 宽）；高 = 行数 * line_height | 按 `align` 在父容器内对齐 |
| button | 文本宽 + 2*pad_x；高 = line_height + 2*pad_y | 同 label，背景 + 圆角 |
| spacer | 宽/高 = 指定 dp | 占据空间，不绘制 |

`weight` 分配：

```
剩余 = 容器内空间 - 固定尺寸子节点总和 - gap 总和
每个 weight>0 的子节点得到 剩余 * weight_i / Σweight
最后一个子节点拿余数，避免累计误差
```

### 7.5 取整与像素对齐

- 排列阶段把 Q16.16 原点四舍五入成整数 px：`px = (fx + 32768) >> 16`。
- 子节点尺寸用「下一个原点的整数 px - 当前原点」计算，保证相邻子节点无缝、无 1 px 缝隙。
- 文本基线与行高用整数 px；字形 blit 不做亚像素偏移。
- 所有裁剪矩形也取整；避免半像素导致的接缝。

### 7.6 文本测量

- 位图字体每个字形有 `advance`（整数 px）与 `bitmap_w/h`。
- 单行宽度 = Σ advance；高度 = `line_height`。
- 换行：最大宽度约束下，按空格与 CJK 边界贪心断行；不做 hyphenation、不做双向文本。
- 文本节点缓存测量结果（节点 `w/h`），同一帧内不重复测量；跨帧复用时若文本指针/长度不变，可跳过重新测量（M2 优化）。

### 7.7 溢出与滚动

- `scroll` 容器的内容高度可以超过视口；绘制时用命令自带的裁剪矩形裁掉视口外部分。
- 命中测试要把点击坐标加上 `scroll_y` 再比较子节点。
- 滚动惯性（fling）用整数速度衰减：`v = v * 7 / 8` 每帧，低于阈值停止；不用 float。
- 边缘回弹 v1 不做；越界直接 clamp。

---

## 8. 文本与字体

### 8.1 为什么是位图字体

- TTF 解析 + 贝塞尔光栅化需要 float 或大量定点数学；Aster 没有 float，v1 不值得投入。
- Android 系统字体无法直接使用：`AConfiguration_getFontScale` 返回 float，不能从 Aster 调用；字体文件也不在 APK 内。
- 位图字体确定性强、渲染快、易做 golden test，且已有先例：`examples/icon_text_demo.ast` 用 `@embed` 的 8×8 字体画了三行文本。

### 8.2 `.auf` 格式（AsterUI Font）

小端、无外部依赖、可 mmap/嵌入：

```
偏移  大小  含义
0     4     magic "AUF1"
4     2     version = 1
6     2     flags（bit0: 8bpp alpha；否则 1bpp）
8     2     glyph_count
10    2     pixel_size（em 方框，px）
12    1     line_height（px）
13    1     baseline（px，从顶部算）
14    2     reserved
16    4     glyph_table_offset
20    4     bitmap_offset
24    4     bitmap_size
28    4     reserved
```

字形表每项 16 B：`codepoint: u32, advance: u8, w: u8, h: u8, xoff: i8, yoff: i8, flags: u8, reserved: u8, bitmap_off: u32, pad: u16`。字段用 `load_u8/load_u16` 手动解析，不依赖结构体对齐。

- 码点表按升序排列，二分查找。
- 1bpp 位图按行、MSB 优先；8bpp 是 alpha 覆盖度（行 `w` 字节）。
- **flags 的第 0 位是 1bpp/8bpp 的唯一判据**，文件头（@6）与字形记录
  （@9）必须一致。v1.44 之前生成器把 1bpp 文件头也写成 1，与这里的
  约定冲突；v1.44 已把四个 1bpp 图集改正为 0（D.54.3）。
- 缺字回退到 `?` 或空白框；不崩溃。

生成工具（离线，可用任意语言）把 BDF/PSF/自绘位图转成 `.auf`；AsterUI 只负责解析与绘制。

### 8.3 UTF-8 解码

```aster
// 伪代码签名（实现略）：
//   fn auix_utf8_decode(p: ptr, out_len: ptr) -> i32
// 返回码点；通过 out_len 指针写回消耗的字节数
```

- 支持 1–4 字节序列；非法序列返回 U+FFFD 并前进 1 字节。
- 文本遍历按字节指针前进，不建索引数组；测量与绘制各走一遍。
- 源码里的 UTF-8 字面量已经可用（实测），但正式本地化仍建议 `@embed("strings/zh.txt")`，便于替换语言。

### 8.4 换行

- 拉丁文本：在空格处断行；单词超宽时强制断字符。
- CJK：任意字符边界都可断行（简化规则，不做禁则处理）。
- `\n` 强制换行。
- 不做两端对齐、不做行首标点压缩。

### 8.5 字体与字符串资源

```aster
let g_font_latin: ptr = @embed("assets/font_latin.auf");
let g_font_cjk: ptr = @embed("assets/font_cjk.auf");
let g_strings_zh: ptr = @embed("assets/strings_zh.txt");
let g_strings_en: ptr = @embed("assets/strings_en.txt");
```

- `@embed` 上限 16 MiB/文件；字体子集通常 100–500 KiB。
- 中文常用 3500 字，16×16 1bpp ≈ 3500×32 B ≈ 112 KiB；24×24 8bpp ≈ 3500×576 B ≈ 2 MiB。v1 建议 16×16 1bpp + 2 档位（16/24 整数倍）。
- 字符串表用简单格式：`id<TAB>UTF-8 text<LF>`，或直接编译成 `i32 offset[]` 的数组；读取时按行扫描，不建哈希表。
- 语言选择：`AConfiguration_getLanguage(cfg, buf)` 把两个字母写入缓冲区（不是返回值），映射到字符串 blob；v1 支持中/英两套即可。

### 8.6 文本边界（必须写进用户文档）

- 不支持 TTF、OTF、可变字体、任意字号缩放；只有预生成的位图档位。
- 不支持阿拉伯文/印度语系的连写与重排。
- 不支持 emoji 彩色字体；最多画单色位图。
- 不支持系统字体回退；缺字显示 `?`。
- 文本编辑只支持「字符插入/删除」，不支持组合输入、候选词、剪贴板。

---

## 9. 绘制

### 9.1 显示列表

每帧构建结束后，把树「拍平」成命令数组：

- 背景填充（含圆角）
- 文本（字形逐个绘制，或整段交给光栅器）
- 图片（RGBA→目标格式）
- 裁剪（命令自带 clip 矩形，不需要 push/pop）

命令数组是固定池，`g_cmd_count` 记录本帧条数；超出容量时丢弃后续命令并置错误标志。

### 9.2 软件光栅

核心循环必须「按 span 批量写」，不能每个像素调用一个函数：

```aster
// 伪代码签名（实现略）：实心填充，按行、按 8 字节写（两个像素）
//   fn auix_fill_span(bits: ptr, x0: i32, x1: i32, y: i32,
//                     stride: i32, color: u32) -> i32
```

实现要点：

- 目标格式 1（RGBA_8888）与 2（RGBX_8888）：4 B/像素；颜色预打包成 `u32`。
- 格式 4（RGB_565）：2 B/像素；提供 `auix_blit_8888_to_565`。
- alpha 混合：`out = (src * a + dst * (255 - a) + 127) / 255`，i32 中间量足够（255×255=65025）。
- 圆角矩形：按扫描线计算左右边界，用整数圆方程 `x^2 + y^2 <= r^2` 的增量形式；或预生成 1/4 圆的 span 表（推荐，快且简单）。
- 字形：1bpp 时按位展开；8bpp 时直接取 alpha；颜色由命令给出。
- 图片：最近邻缩放（整数比例）；不做双线性（需要更多乘法，且 v1 图片多为图标）。
- 所有循环用局部变量缓存 `stride/bits/color`，避免每像素重复读全局。

### 9.3 `ANativeWindow` 交互

```aster
extern fn ANativeWindow_setBuffersGeometry(window: ptr, w: i32, h: i32, fmt: i32) -> i32;
extern fn ANativeWindow_lock(window: ptr, outBuffer: ptr, inOutDirty: ptr) -> i32;
extern fn ANativeWindow_unlockAndPost(window: ptr) -> i32;
```

- 创建窗口后调用 `setBuffersGeometry(window, 0, 0, WINDOW_FORMAT_RGBA_8888=1)`。
- `ANativeWindow_lock` 填充 `ANativeWindow_Buffer`：`width@0, height@4, stride@8, format@12, bits@16`（与 `native_touch.ast` 一致，已实测）。
- `stride` 可能大于 `width`，所有像素地址必须用 `stride` 计算。
- 只支持 format 1/2/4；遇到其他格式记录日志并跳过绘制，不崩溃。
- `unlockAndPost` 之后缓冲区失效，不能继续写。

### 9.4 全量重绘 vs damage

v1 默认**全量重绘**：

- BufferQueue 可能轮换多个缓冲区，局部更新的其余区域可能是旧帧内容；在没有确认 buffer age/单缓冲的情况下，damage 更新会导致撕裂或残影。
- 全量重绘的正确性最好保证；1080×2400 的 RGBA 填充用 8 字节写，预计 2–5 ms，简单界面可以接受。

M3 再评估 damage：

- 维护 CPU 后台缓冲，锁定时只把 damage 区域拷到窗口缓冲；但窗口缓冲的其余区域仍是未定义内容，除非确认缓冲区不被轮换。
- 或者请求单缓冲/双缓冲并验证设备行为；不同厂商差异大，必须逐设备验证。
- 在验证通过前，`aui_invalidate` 始终触发全量重绘。

### 9.5 16 KB page 与 ABI

- `targetSdk >= 35` 必须使用 `--page-size 16384`；Aster 的 `build-so`/`link-so`/`build-apk` 都支持。
- ABI 只支持 `arm64-v8a`（Aster 编译器只产 AArch64）。
- APK 里只有一个 `.so`；`--libname` 决定 `android.app.lib_name` 和文件名。

---

## 10. 输入与交互

### 10.1 接入 `AInputQueue`

```aster
fn on_input_queue_created(activity: ptr, queue: ptr) -> i32 {
    let looper: ptr = ALooper_forThread();
    return AInputQueue_attachLooper(queue, looper, 1, on_looper_input, g_null);
}
```

- `on_looper_input(ident, events, data)` 里循环 `AInputQueue_getEvent`，直到返回值 `< 0`。
- 先 `AInputQueue_preDispatchEvent`；返回非 0 表示事件被 IME 预取，**不要** `finishEvent`，继续取下一条（与 `native_touch.ast` 一致）。
- 处理完调用 `AInputQueue_finishEvent(queue, ev, 1)`。
- 事件类型：`AInputEvent_getType` 返回 1 = motion，2 = key。

### 10.2 坐标桥

`AMotionEvent_getX/Y` 在 C 里返回 float（s0 寄存器），Aster 声明成 `-> i32` 读的是 w0，拿不到值。沿用 `native_touch.ast` 的 `lrintf` 桥：

```aster
extern fn AMotionEvent_getX(ev: ptr, idx: i32) -> i32;   // 实际返回值在 s0
extern fn lrintf() -> i32;                               // 读 s0，返回 x0

fn auix_event_x(ev: ptr, idx: i32) -> i32 {
    let junk: i32 = AMotionEvent_getX(ev, idx);
    return lrintf();       // 两条调用必须紧邻，中间不能插入任何 Aster 调用
}
```

- 多指：对每个 pointer index 重复「getX + lrintf」。
- `AMotionEvent_getAction` 的低字节是动作，高字节是 pointer index；用 `/ 256` 和 `- (act / 256) * 256` 拆分，避免依赖位运算语义。
- 时间戳 `AMotionEvent_getEventTime` 返回 i64，可用于长按/双击判定（纳秒）。

### 10.3 命中测试

从根开始，按子节点**逆序**（后声明的在上层）深度优先：

- 跳过不可见/禁用节点。
- 点在裁剪矩形外 → 跳过。
- scroll 容器：把坐标加上 `scroll_y` 再递归子节点。
- 命中叶子后返回节点 id；没有命中返回 -1。
- 命中测试用整数 px；布局是 Q16.16，比较前先取整。

命中测试可以递归（深度 ≤ 128），但为避免 8 KiB 帧叠加，建议用显式栈数组迭代。

### 10.4 手势状态机

每个指针一个会话（v1 只跟踪主指针）：

```
IDLE
  DOWN(hit) → PRESSED(hit)      记录 down_x/down_y/time
PRESSED
  MOVE 超出 slop(8dp) → DRAGGING
  UP 在节点内 → 触发 click，回 IDLE
  UP 在节点外 → 取消，回 IDLE
  CANCEL → 取消
DRAGGING
  MOVE → 若是 scroll 容器，更新 scroll_y 并 invalidate
  UP → 结束；可按速度进入 FLING
FLING
  每帧 scroll_y += v; v = v*7/8; |v| < 阈值 → IDLE
```

- 长按：按下后超过 500 ms 且未移动 → 触发 long-press（按钮可选）。
- 点击 slop 用 8 dp 转 px；不同密度自适应。
- 手势仲裁：v1 只支持「一个滚动容器 + 按钮」的层级；子节点是按钮时优先点击，父节点是 scroll 时拖动滚动。嵌套滚动容器在 M3 再处理。
- 按压态：按下时按钮 `pressed=1`，抬起/取消清除；重绘由 `aui_invalidate()` 触发。

### 10.5 焦点与键盘

- 会话保存 `focused: i32`（节点 id）。点击可聚焦节点（按钮、文本字段）时更新。
- `AKeyEvent_getKeyCode`：`AKEYCODE_BACK=4`、`AKEYCODE_ENTER=66`、`AKEYCODE_TAB=61`、`AKEYCODE_DEL=67`。
- 文本输入：`AKeyEvent_getUnicodeChar` 返回字符码点；文本字段把码点编码成 UTF-8 追加到 scratch 缓冲。
- 物理键盘与软键盘都走 key 事件；软键盘的字符事件通常是 key down + unicode char。
- 返回键：有导航栈时先 pop；根页面时可以调用 `ANativeActivity_finish(activity)` 退出（或交回系统）。

### 10.6 IME 边界与自带键盘

- `ANativeActivity_showSoftInput(activity, flags)` / `hideSoftInput` 可用（NDK NativeActivity API），在聚焦文本字段时调用。
- **限制**：NativeActivity 的默认 InputConnection 只适合简单字符提交；中文输入法的候选词、组合文本、联想等大多不会以可用的形式到达 native 层。没有 Java 壳就无法实现完整的 `InputConnection`。
- **对策**：v1 提供一个 AsterUI 自绘的屏幕键盘（`aui_keyboard`），支持 ASCII、数字、常用符号；中文输入建议应用内置候选/拼音键盘或接受「仅英文输入」。
- 这不是可以靠努力绕过的工程问题，而是「无 Java 壳」的直接代价；必须在产品层面接受。

---

## 11. 动画与帧调度

### 11.1 帧来源

设计上有两条候选：

1. `AChoreographer`（对齐 vsync）：
   ```aster
   extern fn AChoreographer_getInstance() -> ptr;
   extern fn AChoreographer_postFrameCallback(cg: ptr, cb: ptr, data: ptr) -> i32;
   ```
   `AChoreographer_getInstance()` 必须在有 looper 的线程调用；回调签名是
   `void (*)(long frameTimeNanos, void* data)`，Aster 声明为
   `fn(t: i64, data: ptr) -> i32`，把函数名当 `ptr` 传入。每次回调处理完，
   如果还有动画或失效，重新 post 下一帧；空闲时不 post。

2. 与 fling 共用的 16 ms `timerfd`（`ALooper_addFd` 回到 UI 线程）。

v1.10 实际选 2：v1.6 的惯性滚动已经建好 timerfd → looper → `aui_frame`
链路，动画直接复用同一条表，不新增 NDK 导入，也不会出现两个帧源互相
抢 `unlockAndPost` 的问题。代价是帧不对齐 vsync；`AChoreographer`
留到需要精确 60/120 Hz 节拍时再替换，接口 `aui_frame(now_ns)` 不变。

动画与 fling 共用 `frame_timer_arm/disarm`：两者都空闲才停表；`onPause`
/`onStop` 停表并保留动画槽，`onResume` 重新同步。槽的开始时间用
`CLOCK_MONOTONIC` 纳秒，测试可用 `aui_debug_set_time` 注入。

### 11.2 定点补间

```aster
// 线性插值：t 是 0..65536 的 Q16.16 进度
fn anim_lerp(a: i32, b: i32, t: i32) -> i32 {
    let d: i64 = i64(b) - i64(a);
    let p: i64 = d * i64(t);
    let q: i64 = p + 32768;
    return a + i32(q >> 16);
}
```

- 缓动函数用整数多项式：linear、ease-out `1-(1-t)^2`、
  smoothstep `3t^2-2t^3`；不做 float、不做弹簧物理。
- 动画槽固定 64 个：`{ key, prop, from, to, val, start_ns, duration_ns, curve, active, seen }`，
  按 `(key, prop)` 寻址；`prop` 为 `ALPHA(0..255)`、`TX/TY(dp)`。
- 每帧根据 `now_ns - start_ns` 算进度并更新 `val`；结束后置 inactive，
  最后一个活动槽结束时停表。目标值未变时保留当前进度；目标改变时从
  `val` 改道，不跳变；`duration_ms <= 0` 或 `from == to` 直接落到终值。
- **动画只改绘制阶段**：`paint_node` 按节点 key 查 alpha/tx/ty，写入
  `g_aui_paint_alpha/dx/dy` 并沿子树继承，`cmd_add` 统一叠加到命令的
  颜色 alpha 与坐标上；不触发 build/layout，也不改变命中测试。
- 光栅端 alpha：`fill_run` 在 alpha=255 时走原来的整行写入快路径，
  否则逐像素 `blend_px`；字形与图片按命令颜色高字节缩放 alpha。
- `aui_anim_reset(key, prop)` 删除槽并回到默认值（alpha=255、tx/ty=0），
  以便重播；删除只置 PAINT，不做重建。

### 11.3 失效级别

| 调用 | 标志 | 下一帧做什么 |
|---|---|---|
| `aui_invalidate()` | BUILD | 运行 build 回调 → 协调 → 布局 → 生成命令 → 光栅 |
| `aui_invalidate_layout()` | LAYOUT | 不重建树，重新测量/排列 → 生成命令 → 光栅 |
| 输入按压态/滚动 | PAINT/LAYOUT | 只改节点属性 → 生成命令 → 光栅 |
| 动画帧 | PAINT | 更新动画值 → 重新生成命令 → 光栅（不重建、不重新布局） |

v1 的「PAINT」实际上仍然重新生成整棵树的命令（因为命令是每帧重建的），但跳过 build 回调。M3 可以缓存未变化子树的命令块。

### 11.4 帧预算

- 目标 60 Hz，16.6 ms/帧。
- 预算分配（1080×2400，简单界面）：build 0.5 ms、布局 0.5 ms、命令生成 0.5 ms、光栅 6–10 ms、系统合成余量 3 ms。
- 超过预算时：降低动画帧率、合并失效、减少全屏 alpha 混合；M3 再做 damage。
- 所有时间用 `CLOCK_MONOTONIC`（`clock_gettime(1)`）纳秒；v1.10 没有引入
  `AChoreographer`，因此不存在与 vsync 时基不一致的问题。测试用
  `aui_debug_set_time` 注入同一时基。

---

## 12. 生命周期与 Android 适配层

### 12.1 `ANativeActivityCallbacks` 偏移（AArch64，实测于示例）

| 偏移 | 回调 | AsterUI 用途 |
|---|---|---|
| 0 | onStart | 可选：恢复 |
| 8 | onResume | 可选：恢复渲染 |
| 16 | onSaveInstanceState | v1 不设置（签名/所有权不确定） |
| 24 | onPause | 停止帧回调 |
| 32 | onStop | 释放窗口引用 |
| 40 | onDestroy | `aui_shutdown` |
| 48 | onWindowFocusChanged | 焦点/软键盘 |
| 56 | onNativeWindowCreated | 保存 window、设置格式、首帧 |
| 64 | onNativeWindowResized | 重新布局 |
| 72 | onNativeWindowRedrawNeeded | 全量重绘 |
| 80 | onNativeWindowDestroyed | 清空 window、停止绘制 |
| 88 | onInputQueueCreated | attach looper |
| 96 | onInputQueueDestroyed | detach |
| 104 | onContentRectChanged | 更新内容区/安全区 |
| 112 | onConfigurationChanged | 密度/夜间模式/语言变化 |
| 120 | onLowMemory | 丢弃缓存（字体已常驻，主要是图片） |

写入方式（已验证）：

```aster
let cb: ptr = load_ptr(activity);      // ANativeActivity.callbacks @ 0
*(cb + 56) = on_native_window_created;
*(cb + 64) = on_native_window_resized;
...
```

注意：`ANativeActivity` 的 `assetManager` 在 AArch64 上位于偏移 64（`callbacks@0, vm@8, env@16, clazz@24, internalDataPath@32, externalDataPath@40, sdkVersion@48, instance@56, assetManager@64, obbPath@72`）。读取时用 `load_ptr(activity + 64)`，不要把它和 callbacks 混淆。

### 12.2 窗口生命周期

- `onNativeWindowCreated`：保存 `window`，`setBuffersGeometry(0,0,1)`，查询宽高，置 `window_ready=1`，post 首帧。
- `onNativeWindowResized`：重新查询宽高，置 LAYOUT 失效，post 帧。
- `onNativeWindowRedrawNeeded`：置 BUILD/PAINT 失效，全量重绘。
- `onNativeWindowDestroyed`：`window_ready=0`，清空指针；之后任何绘制都必须直接返回。
- `onPause`：停止 Choreographer 重投；`onResume` 恢复。
- `onDestroy`：释放会话；v1 不 free（静态池），只清状态。

### 12.3 配置变化

- manifest 的 `configChanges` 在 v1.9 由编译器补丁改为 `0x1F90`（orientation/screenLayout/uiMode/screenSize/smallestScreenSize/density/keyboard），这些变化都不重建 Activity，走 `onConfigurationChanged` + `onNativeWindowResized` + `onContentRectChanged`。
- `AConfiguration_fromAssetManager` + `AConfiguration_getDensity/getUiModeNight/getScreenWidthDp/getScreenHeightDp` 读取配置；用完 `AConfiguration_delete`。
- 夜间模式：`AConfiguration_getUiModeNight` 返回 `0 ANY / 1 NO / 2 YES`；等于 2 时换主题表并 `aui_invalidate()`。NDK **没有** `AConfiguration_getUiMode`。
- 语言：`AConfiguration_getLanguage(cfg, buf)` 写入两字母代码（缓冲区由调用方提供）；切换字符串表。
- 字体缩放：`AConfiguration_getFontScale` 返回 float，Aster 不能调用；v1 忽略系统字体缩放，只按 density 和固定档位。

### 12.4 状态保存

- `onSaveInstanceState` 的签名与内存所有权在无 Java 环境下不可靠（需要返回一个由系统接管的 buffer）；v1 **不实现**。
- 应用需要持久化时，自己用 `openat` 写到 `activity.internalDataPath` 下的文件；路径在 `ANativeActivity` 偏移 32。
- `aui_state_*` 提供遍历接口（M3）以便应用序列化；v1 由应用自己保存业务状态。

### 12.5 低内存

- `onLowMemory`：释放图片缓存（如果有）、清空命令池、保留字体与字符串；置 BUILD 失效。
- 节点池是静态的，不需要释放；避免在低内存回调里做复杂工作。

---

## 13. 主题、资源、本地化

- **主题表**：`u32[16]` 全局数组，角色索引常量：`SURFACE/ON_SURFACE/PRIMARY/ON_PRIMARY/OUTLINE/ERROR/...`。启动时由应用选择主题并填表；节点只存角色或直接颜色。
- **颜色**：统一 `0xAARRGGBB`；`aui_bg` 接收 `u32`。
- **图片**：`@embed` 的 RGBA8888 blob，头部 8 字节 `{w:u32, h:u32}`，随后 `w*h*4` 字节；`aui_image` 直接接收像素指针与宽高。
- **字符串**：`@embed` UTF-8 文本，按 id 偏移表访问；语言切换只换 blob 指针。
- **密度**：见 §7.2；所有 dp 值在构建时转 Q16.16 px。
- **深色模式**：主题表切换 + 重绘；节点树不需要重建（除非文本颜色是硬编码的）。
- **本地化**：v1 支持中/英两套字符串表；RTL 不做（需要镜像布局与文本重排）。

---

## 14. 语义与无障碍边界

- 每个可交互节点有 `role`、`label`、`enabled`、`bounds`，存放在节点的附加字段或并行数组中。
- 语义树用于：
  - headless 测试：按 role/label 查找节点、断言 bounds、模拟点击。
  - 调试：dump 当前界面结构。
- **没有 TalkBack**：注册无障碍服务需要 Java 壳；AsterUI 无法把语义树交给系统。这是无 Java 壳的硬边界。
- 未来如果允许一个极小的 Java 桥（仅 `AccessibilityNodeProvider`），可以在此语义树上做映射；但那已经违反当前硬约束，因此不作为路线图承诺。

---

## 15. 测试

### 15.1 headless 后端

`platform/headless` 提供与 Android 相同的接口：

- 目标：一块 `w*h*4` 的内存缓冲区（可用静态数组或 `mmap`）。
- 事件：脚本化的 `{type, x, y, key}` 序列，直接调用 `aui_input_*` 内部函数。
- 帧：`aui_frame(t)` 手动推进，时间戳由测试给定，保证确定性。

核心（tree/layout/paint/raster/input）不依赖 libandroid，因此 headless 测试可以先 `build-obj`、再 `link-obj` 成静态 ET_EXEC，在 AArch64 Linux 或 qemu-user 上运行。

### 15.2 测试类型

| 类型 | 做法 | 判定 |
|---|---|---|
| 布局 golden | dump 节点 `{id,kind,key,x,y,w,h}` 文本 | 与期望文本逐行比较 |
| 像素 golden | 渲染到内存缓冲，FNV-1a 哈希 | 哈希相等；失败时输出 PNG/PPM |
| 输入脚本 | 按下/移动/抬起序列 | 断言点击回调次数、滚动偏移 |
| 状态机 | 直接调用手势函数 | 断言状态迁移 |
| APK 门禁 | `unzip -l` + `verify-apk` | 无 `classes.dex`；签名 OK |
| 设备烟雾 | `adb install` + logcat | 启动、首帧、点击 |

### 15.3 确定性

- 不用系统时钟；所有时间来自测试传入的 `now_ns`。
- 不用随机数；动画曲线是纯函数。
- 字体、字符串、图片都是编译期嵌入，不受设备影响。
- 像素输出用小端 RGBA8888，测试机字节序固定 AArch64。

### 15.4 CI 边界

本沙箱可以编译 AArch64，但不能执行；运行时测试必须在 AArch64 机器或 qemu-user 上跑。CI 至少要包含：

```
aster build-obj tests/headless_test.ast -o build/headless_test.o
aster build-obj stdlib/asterui/aui_impl.ast -o build/aui_impl.o
aster link-obj build/headless_test.o build/aui_impl.o -o build/headless_test
qemu-aarch64 build/headless_test
```

（`link-obj` 产出静态 ET_EXEC，不依赖 libandroid；headless 实现只使用 `write`/内存操作。）

以及 APK 打包 + `verify-apk` + 无 dex 断言。

---

## 16. 构建与目录

### 16.1 建议目录

```
stdlib/asterui/
  aui.ast              公共头：extern fn / extern let / 回调类型 / 常量
  aui_impl.ast         v1 实现（单文件，按节组织；编译成一个 .o）
  auix_internal.ast    M4 拆分实现文件时的内部头（extern 声明）
  assets/font_latin.auf
  assets/strings_zh.txt
  assets/strings_en.txt
examples/ui_hello.ast
examples/ui_counter.ast
examples/ui_list.ast
tests/headless_test.ast
```

v1 把下列逻辑模块写在 `aui_impl.ast` 一个文件里（Aster 的 include 不编译函数体，拆文件需要为每个跨文件符号手写 `extern` 声明，v1 先避免这份样板）：

```
config / fix / pool / tree / layout / text / paint /
raster / input / focus / anim / semantics / theme /
android_attach / android_window / android_config /
headless_backend
```

M4 拆分时，每个模块一个 `.ast`，各自 `include "aui.ast"; include "auix_internal.ast";`，分别 `build-obj --pic`，再 `link-so`。跨模块只传 `i32` / 裸 `ptr` / 标量。

### 16.2 构建命令（实测，两个对象链接）

```bash
# 1) 编译库对象（实现文件作为顶层源文件，函数体在这里编译）
aster build-obj --pic stdlib/asterui/aui_impl.ast -o build/aui_impl.o

# 2) 编译应用对象（include 只带来声明；ANativeActivity_onCreate 在这里定义）
aster build-obj --pic examples/ui_hello.ast -o build/ui_hello.o

# 3) 链接成单个 .so；--needed 解决 AMotionEvent_/AKeyEvent_ 的库映射缺口
aster link-so build/ui_hello.o build/aui_impl.o \
  --soname libuihello.so \
  --needed libandroid.so --needed liblog.so --needed libm.so \
  --page-size 16384 \
  -o build/libuihello.so

# 4) 打包 NativeActivity APK（无 dex）
aster build-apk build/libuihello.so \
  -o build/uihello.apk \
  --package dev.aster.uihello \
  --label "UI Hello" \
  --libname uihello \
  --abi arm64-v8a \
  --min-sdk 24 \
  --target-sdk 35 \
  --page-size 16384

# 5) 门禁
aster verify-apk build/uihello.apk
unzip -l build/uihello.apk | grep -c classes.dex    # 必须为 0
```

注意：

- **不能**用 `build-so examples/ui_hello.ast` 一步完成，除非 `ui_hello.ast` 自己包含所有实现（它不会——include 只带声明）。必须先把库实现编成对象，再链接。
- `build-apk` 不接受 `--needed`；依赖必须在 `link-so` 阶段加。
- `--libname` 决定 manifest 的 `android.app.lib_name` 与 APK 内的文件名。
- `--page-size 16384` 用于 16 KB page 设备与 targetSdk 35；4 KB 设备可继续用默认 4096。
  **实测修正（v0.23.54）**：`link-so` 和 `build-apk` 都只解析、不传递 `--page-size`——生成的 .so 的 `p_align` 仍是 0x1000，APK 内 .so 也仍按 4096 对齐。需要两行补丁（`patches/aster-16k.patch`）或等上游修复；补丁后实测 `p_align = 0x4000`、APK 内 .so 偏移 16384。4 KB 设备不受影响。
- 发布签名用 `--sign-mode release --keystore ... --cert ...`；不要用 debug key 发布。

### 16.3 标准库接入

应用侧只需要：

```aster
include "asterui/aui.ast";
```

应用的构建脚本负责把 `aui_impl.o` 链进来：

```
aster build-obj --pic app/main.ast -o build/main.o
aster build-obj --pic stdlib/asterui/aui_impl.ast -o build/aui_impl.o
aster link-so build/main.o build/aui_impl.o --needed libandroid.so -o build/libapp.so
```

---

## 17. 性能与内存预算

### 17.1 时间

| 阶段 | 预算（1080×2400） | 说明 |
|---|---|---|
| build 回调 | 0.3–1 ms | 应用代码；节点数 < 1000 |
| 协调/剪枝 | < 0.5 ms | O(n)，无分配 |
| 测量/排列 | < 1 ms | 两遍迭代 |
| 命令生成 | < 0.5 ms | 每节点 1–3 条 |
| 光栅 | 5–10 ms | 全量；文字/圆角是热点 |
| 总计 | < 16.6 ms | 留 20% 余量 |

光栅优化优先级：

1. 实心矩形用 8 字节写、按行批处理。
2. 文本按字形批量 blit，避免每个像素一次函数调用。
3. 圆角用预计算 span 表。
4. alpha 混合只在必要区域做；不透明背景先填满。
5. M3：命令块缓存 + damage（需先解决缓冲区轮换正确性）。

### 17.2 内存

| 项 | 预算 |
|---|---|
| 代码 `.text` | < 300 KiB（含光栅/字体/输入） |
| 只读资源（字体/字符串/图片） | 0.2–2 MiB |
| `.bss` 池 | ≈ 700 KiB |
| 运行峰值 | < 8 MiB（不含应用数据） |
| APK（单 ABI） | < 5 MiB（资源为主） |

### 17.3 容量上限的行为

- 节点耗尽：丢弃新节点，保留已有树，记录错误；不崩溃。
- 命令耗尽：截断显示列表，记录错误；界面可能缺元素，但不越界。
- 文本 scratch 耗尽：截断文本，保证 NUL 结尾。
- 栈深度上限 128：超过时拒绝打开新容器，记录错误。

---

## 18. 编译器与平台缺口

### 18.1 i64 复合表达式移位 codegen bug（已复现）

```aster
fn f(a: i64, b: i64) -> i64 {
    let s: i64 = (a * b) >> 16;   // error: TypedIR MISMATCH kind=26 type=i32 exprType=i64
    return s;
}
```

- 触发条件：i64 的 `+`/`*` 等二元表达式直接接 `>>`（`let s: i64 = (a*b) >> 16;` 同样失败）；TypedIR 把移位结果错误地标成 `i32`（`kind=26 type=i32 exprType=i64`）。
- 绕法：先把乘积/和存入 i64 临时变量，再移位（`let p: i64 = a * b; return p >> 16;`），已验证通过。
- 建议上游修复；AsterUI 的 `auix_fx_mul` 已封装绕法，业务代码不受影响。

### 18.2 `AMotionEvent_*` / `AKeyEvent_*` 未映射

- `ndkLibraryFor` 没有这两个前缀，符号默认落到 `libc.so`。
- 绕法：`build-so --needed libandroid.so`；实测 `DT_NEEDED` 含 `libandroid.so`，运行时符号可解析。
- 建议上游补两行映射；在补之前，AsterUI 的构建脚本必须带 `--needed libandroid.so`。

### 18.3 `mmap` 失败不可判定

- 失败返回 `-errno` 编码在 `ptr`，Aster 不能转整数，无法检测。
- v1 核心不用 `mmap`；应用自行使用时需接受「失败即崩溃」。
- 建议上游加 `ptr_bits(p: ptr) -> u64` 或 `sys_is_err(p: ptr) -> bool`；有了它，AsterUI 才能安全地提供可选的 arena/大缓冲。

### 18.4 没有 float

- 影响：TTF 光栅化、`AConfiguration_getFontScale`、部分 NDK 接口（返回 float）不可直接调用。
- 绕法：Q16.16 + 位图字体 + `lrintf` 桥。
- 不建议为此加 f32：会牵动 ABI、寄存器分配和现有整数语义；位图字体已能满足 UI。

### 18.5 没有 `void`

- 所有函数必须返回值；回调统一 `-> i32`。这只是风格问题，不影响 ABI。

### 18.6 所有 `.so` 符号默认导出

- 没有 visibility 控制；内部函数也会出现在动态符号表。
- 纪律：公共 `aui_`，内部 `auix_`；应用代码避免使用这两个前缀。
- 将来若支持 `--visibility hidden`，可显著减小符号表。

### 18.7 APK 没有 assets

- `build-apk` 不打包 `assets/`；所有资源必须 `@embed` 进 `.so`。
- 优点：无运行时文件 IO、启动快；缺点：资源更新需重新发版。
- 对 UI 字体/字符串来说可接受。

### 18.8 其他边界

- 无 enum/const：常量是全局 `i32/u32`，应用可能误改；靠命名和文档约束。
- 无泛型/闭包：组件复用靠「顶层 build 函数 + user 指针」，不能写内联 DSL  lambda。
- struct ≤ 1024 B：节点保持 96 B；不要往节点里塞大数组。
- 8 KiB 帧：避免深递归；所有树遍历用显式数组。

---

## 19. 里程碑

### M0 核心骨架

- `fix.ast`、`pool.ast`、`tree.ast`、`headless` 后端。
- 构建器：root/column/row/pad/label/end；key 复用；剪枝。
- 固定 Q16.16 布局；单色矩形绘制。
- 产物：headless 渲染出一张带标题和按钮的静态图；布局 golden 通过。

**退出标准**：`build-obj` + `link-obj` 的 headless 测试在 qemu/AArch64 上通过；节点池不越界。

### M1 文本与真机

- `.auf` 解析、UTF-8、文本测量/换行、字形 blit。
- 按钮、圆角、图片、主题表。
- Android 适配：attach、窗口、全量重绘、Choreographer 首帧。
- 产物：`ui_counter.apk` 在真机启动并显示中文/英文文本。

**退出标准**：APK 无 dex；首帧 < 500 ms；点击计数正确；像素 golden 通过。

### M2 交互

- AInputQueue 接入、坐标桥、命中测试、点击/长按/滚动。
- 焦点、返回键、文本字段（ASCII）、自绘键盘。
- 压态/焦点态视觉。
- 产物：可滚动列表 + 可点击按钮 + 可输入文本框。

**退出标准**：事件脚本测试通过；滚动无越界；键盘输入正确。

### M3 系统集成

- 密度/夜间模式/语言切换；内容区/安全区。
- 动画槽、补间、失效级别。
- 导航栈/弹层（stack + 路由）。
- 语义树 + headless 查询。
- damage 评估（设备验证后启用）。

**退出标准**：旋转/深色模式切换正确；动画 60 fps；语义测试通过。

### M4 打磨与扩展

- `libasterui.so` 形态；命令块缓存；性能优化。
- CJK 字体子集工具；多语言资源。
- PNG 解码（可选）、更多组件（switch/slider/dialog）。
- GPU 后端接口（仅预留，不实现）。

---

## 20. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 无 Java 壳导致 IME 不完整 | 中文输入体验差 | 自绘键盘；产品层面接受 |
| 无 TalkBack | 无障碍不合规 | 明确不支持；语义树留给未来桥接 |
| 软件光栅性能不足 | 掉帧 | 全量重绘优化；M3 damage；降低动画频率 |
| BufferQueue 轮换导致 damage 残影 | 画面错误 | v1 全量重绘；damage 需逐设备验证 |
| 编译器 bug/限制 | 开发受阻 | 已定位两个；局部绕法；推动上游修复 |
| 节点/命令池耗尽 | 界面缺失 | 容量上限 + 错误标志；列表虚拟化 |
| 字体子集缺字 | 显示 `?` | 构建期扫描字符串码点，自动校验 |
| 设备密度差异 | 布局错位 | dp→Q16.16；整数取整；多设备 golden |
| 16 KB page 兼容 | 安装/启动失败 | `--page-size 16384`；`verify-apk` |
| `mmap` 失败不可检测 | 崩溃 | v1 不用 mmap；应用自担 |

---

## 21. 与 HuxerUI 的架构映射

| HuxerUI | AsterUI | 说明 |
|---|---|---|
| `RuntimeRoot` | `Aui` 会话（全局单例） | 单进程单 UI；无多窗口 |
| `View` / `ViewSpec` | 构建器调用序列 + `AuiNode` | 声明式描述，保留树承载状态 |
| `[[huxerui::composable]]` / `RecomposeScope` | `build(user)` + `aui_invalidate()` | 无编译器插件；整树重建 |
| `Environment` / `Theme` | `theme.ast` 角色表 | 颜色/间距/字体档位 |
| `MountedNode` | 节点池 `AuiNode` | 同时承载布局与绘制数据 |
| Constraints 布局 | Q16.16 两遍测量/排列 | 无 float；迭代遍历 |
| `RenderScene` / `PaintSequence` | 显示列表 `AuiCmd` | 每帧重建；固定池 |
| 增量渲染/damage | 失效级别 + 全量重绘 | v1 保守；M3 评估 damage |
| `PointerInteraction` | 指针会话 + 命中测试 | 单指针；显式状态机 |
| 手势识别/仲裁 | 点击/长按/滚动状态机 | 嵌套滚动 M3 |
| `TextInteraction` / IME | key 事件 + 自绘键盘 | 无完整 InputConnection |
| `SemanticTree` | 语义记录数组 | 测试用；无系统桥 |
| `MotionController` / `Transition` | 定点补间槽 | 无弹簧；固定曲线 |
| layers / popups / navigation | stack + 导航栈 | 简化版 |
| 平台适配层（Android Java Canvas） | android/headless 后端 | 自绘，无 Canvas |
| CMake / modules / SDK | `build-obj` + `link-so` + `build-apk` | 标准库目录 |
| 无窗口 UI 测试 | headless 后端 + golden | 确定性 |

**刻意不照搬**：

- Java Canvas / `android.graphics`：违反无 Java 壳。
- float 约束系统：Aster 没有 float。
- 编译器插件/代码生成：Aster 没有宏/注解处理。
- JVM 反射/资源系统：Aster 是 AOT 原生。
- 复杂动画/共享元素：v1 不需要。

---

## 附录 A：验证记录（Aster v0.23.54-dev）

### A.1 编译与链接

| 验证 | 命令 | 结果 |
|---|---|---|
| 定点乘法（临时变量绕法） | `aster build-elf fx.ast` | 通过 |
| i64 复合移位直接写法 | `let s: i64 = (a*b) >> 16;` | 失败：`TypedIR MISMATCH kind=26 type=i32 exprType=i64` |
| 函数指针作参数/全局 | `set_cb(target)` | 通过 |
| 全局 i64 池转结构体指针 | `let g_nodes: ptr<N> = pool;` | 通过（含 ptr/fn 字段读写） |
| 含 ptr 字段的全局结构体数组字面量初始化 | `let g: N[16] = N{0,0};` | 失败：`global struct field 'N.p' cannot be initialized by a constant` |
| 纯 i32 结构体数组初始化 | `let g: C[8] = C{0,...};` | 通过 |
| 非 ASCII 字符串字面量 | `"你好"` | 通过（7 字节 rodata） |
| 裸函数调用语句 | `f(3);` | 通过 |
| `include` 传递 struct | 包含方使用 `ptr<N>` | 通过；重复定义报错 |
| `extern fn` 公共头 + 两个对象 | `build-obj --pic` + `link-so` | 通过（含 fn 类型参数） |
| `extern let` 声明 | `extern let g_total: i32;` | 通过 |
| 库对象（含 BSS 池）+ 应用对象 | `link-so app.o impl.o` | 通过，`.bss` 正常合并 |

### A.2 APK 管线

```
# 完整管线：应用 + 库两个对象 -> 一个 .so -> APK
build-obj --pic impl.ast      -> impl.o   (4 functions, 2 globals)
build-obj --pic app.ast       -> app.o    (4 functions, 1 global)
link-so app.o impl.o --soname libfull.so --needed libandroid.so -> libfull.so (8 exports)
build-apk libfull.so --package dev.aster.full --libname full --abi arm64-v8a \
  --min-sdk 24 --target-sdk 35 --page-size 16384
  → APK 内容：AndroidManifest.xml / resources.arsc / res/drawable-nodpi/ic_launcher.png /
              lib/arm64-v8a/libfull.so / META-INF/*（无 classes.dex）
  → verify-apk: v1 + v2 签名 OK
  → manifest 字符串：hasCode / android.app.NativeActivity / android.app.lib_name

# 单独验证触摸符号的 DT_NEEDED
build-so touchchk.ast --needed libandroid.so -> touchchk.so
  → DT_NEEDED: libandroid.so / libc.so / libm.so
```

### A.3 未验证项（必须在真机/CI 补）

- 真机启动、首帧、输入回调时序。
- `AChoreographer` 回调频率与 `onNativeWindowRedrawNeeded` 的交互。
- 不同厂商的 BufferQueue 行为（damage 是否安全）。
- `AConfiguration_fromAssetManager` 在 API 24 的可用性（不可用则回退 160 dpi）。
- 软键盘 `showSoftInput` 的实际字符事件形态（尤其中文输入法）。
- 16 KB page 真机安装（模拟器/设备）。

---

## 附录 B：API 速查

| 函数 | 用途 |
|---|---|
| `aui_android_attach` | 绑定 Activity，安装回调，启动首帧 |
| `aui_frame` | 手动泵一帧（headless） |
| `aui_invalidate` | 重建+布局+重绘 |
| `aui_invalidate_layout` | 只布局+重绘 |
| `aui_root` | 开始构建 |
| `aui_column/row/stack/scroll` | 容器 |
| `aui_pad/gap/weight/align/bg/radius` | 修饰当前节点 |
| `aui_label/label_n/text_i32` | 文本 |
| `aui_button` | 按钮 + 回调 |
| `aui_spacer` | 固定间距 |
| `aui_image` | RGBA 图片 |
| `aui_end` | 关闭容器 |
| `aui_state_get/set` | 256 个 i32 状态槽 |
| `aui_focus` / `aui_focus_get` | 聚焦/查询焦点（0 = 无） |
| `aui_text_field/keyboard/key` | 文本字段与自绘键盘 |
| `aui_text_value/len/append/backspace/clear/set` | 文本读取与编辑 |
| `aui_route/nav_push/nav_pop/nav_reset/nav_depth` | 页面栈（固定 8 层，route 为 i32） |
| `aui_finish` | 结束 Activity（根页 BACK 的内部路径） |
| `aui_shutdown` | 释放会话 |

---

## 附录 C：术语

- **Q16.16**：i32 定点数，低 16 位是小数，高 16 位是整数；1.0 = 65536。
- **dp**：密度无关像素；160 dpi 下 1 dp = 1 px。
- **NativeActivity**：Android 框架提供的无 Java 子类 Activity，加载 `lib*.so` 并调用 `ANativeActivity_onCreate`。
- **hasCode=false**：manifest 声明应用无 dex 代码；系统不会要求 `classes.dex`。
- **显示列表**：把树拍平成的绘制命令数组。
- **软件光栅**：CPU 直接写像素缓冲区，不用 GPU。
- **headless 后端**：把绘制目标换成内存缓冲、事件换成脚本的测试后端。
- **`@embed`**：Aster 编译期把文件字节放进 `.rodata`，返回 `ptr`；`@embed_len` 返回长度。
- **`.auf`**：AsterUI 位图字体格式（本设计定义）。

---

## 附录 D：v1 实现记录

本设计已经落成一份可编译、可链接、可打包的 v1 实现（`asterui/` 目录，随本文档交付）。以下是实现阶段对设计的校准，**以本节为准**。

### D.1 代码与产物

```
asterui/
  stdlib/asterui/aui.ast          公共头（extern）
  stdlib/asterui/aui_impl.ast     v1 单体实现（1468 行 → 114 个函数、49 个全局）
  stdlib/asterui/assets/font_latin.auf
  tools/gen_auf.py                字体图集生成器
  examples/ui_hello.ast           计数器示例
  tests/headless_test.ast         离屏渲染自检
  tests/android_stubs.ast         离屏测试用的 NDK 空实现
  build.sh                        编译 → 链接 → 打包 → 验证
  patches/aster-16k.patch         16 KB 页对齐的两行编译器修复
```

实测：实现对象 7,721 条指令 / 114 个函数 / 49 个全局；示例对象 375 条指令；链接后
122 个导出、20 个 PLT 函数导入、22 个 GOT 数据导入、DT_NEEDED = libandroid.so + liblog.so
（v1.1 起补 libm.so，见 D.5）；APK 7 个条目、无 `classes.dex`、v1+v2 签名校验通过。

### D.2 与设计的三处偏差

1. **字体改为运行时注入**：设计里库自带 `@embed`；实测 `@embed` 生成 `__aster_embed_N`
   全局符号，两个目标文件各嵌入一个文件就链接失败。因此库不嵌入任何文件，公开
   `aui_set_font(font, scale)`，由应用 `@embed` 字体后注入。同理库内不保留字符串字面量
   （`__aster_string_N` 在非 PIC 链接时也会重名）。
2. **v1 每帧重建节点树**：设计 §6 的 key 协调尚未实现；状态、焦点、按压都按 key 存
   独立表，所以重建不影响行为，但节点 id 不跨帧稳定。节点池仍是固定 4096。
3. **首版同步呈现**：没有接 AChoreographer；输入/窗口回调在主线程同步完成
   重建→布局→绘制→`ANativeWindow_lock/unlockAndPost`。`aui_frame(now_ns)` 保留给
   动画宿主手动泵帧。全量重绘，damage 区域留到 M2。

另：v1 没有实现滚动偏移、IME 文本编辑、语义树；`aui_scroll` 目前等同 column。

### D.3 实现阶段新增的编译器限制（全部实测）

| 现象 | 报错 / 结果 | 规避 |
|---|---|---|
| `@embed` 符号跨对象重名 | `duplicate global symbol '__aster_embed_0'` | 只让一个对象嵌入文件；库改为注入字体 |
| 非 PIC 下字符串符号重名 | `duplicate global symbol '__aster_string_0'` | PIC 链接（`link-so`）会本地化；或让库无字符串 |
| 所有全局/函数默认导出 | 应用与库同名的 `g_font` 直接冲突 | 库内统一 `g_aui_` 前缀、常量 `AUI_` 前缀 |
| `len` 是内建名 | `expected '(' after len` | 参数改名 `tlen` |
| 调用结果不能直接当赋值目标 | `node_at(i).field = v` 拒绝 | 先存 `ptr` 临时变量 |
| 全局数组长度不接受表达式 | `u8[960 * 640 * 4]` → `expected ']'` | 写字面量 `u8[307200]`，且 ≤ 1,048,576 |
| `switch` 的 `case` 不能带 `{}` | `expected let, assignment, ...` | `case 1: return x;` |
| `link-so` / `build-apk` 丢弃 `--page-size` | .so `p_align=0x1000`、zip 内 .so 偏移 12288 | `patches/aster-16k.patch`（两处传参 + 一处用 pageSize 对齐）；补丁后实测 0x4000 / 16384 |

### D.4 已验证 / 未验证

已验证（本沙箱，x86_64 主机）：编译、`link-so`、`build-apk`、`verify-apk`、无 dex、
`link-obj` 离屏可执行文件链接（含 NDK 桩）、16 KB 对齐补丁前后对比。

首轮真机安装反馈「打开即闪退」后，补到 qemu-user 环境，把整条 Android 路径在
AArch64 上跑通：`tests/android_harness.ast` + `tests/fake_ndk.ast` 模拟
`onCreate → onStart → onResume → onNativeWindowCreated → onRedrawNeeded →
onPause/onStop/onDestroy`，窗口用真实内存缓冲，断言回调表、画面非空、进程存活。
该 harness 直接复现了首帧死循环；修复后返回 0，并把 720×1280 的帧缓冲导出成 PNG
做了目视确认（图标、卡片、标题、按钮、数字都正确）。

仍未验证：真机 Android 动态加载器（`dlopen`/符号解析）、真实 BufferQueue、
真实触摸坐标、16 KB 设备安装。这些只能靠真机日志确认。

### D.5 真机闪退定位与修复（v1.1）

反馈「装好打开闪退、无法 adb」后，用静态检查 + qemu harness 找到三处 v1 缺陷：

| # | 缺陷 | 后果 | 修复 |
|---|---|---|---|
| 1 | 库引用 `lrintf`，但 `link-so` 的 DT_NEEDED 只有 libandroid/liblog；`.so` 带 `BIND_NOW`，加载时全部符号必须解析，`lrintf` 找不到 → 整个 `.so` 加载失败 | 进程在 `ANativeActivity_onCreate` 之前就被杀，表现为秒退 | `build.sh` 增加 `--needed libm.so`（实测 DT_NEEDED 3 条） |
| 2 | 绘制命令里坐标是 Q16.16，`fill_rect`/`draw_image`/`draw_text_run` 却按像素直接用；`draw_image` 拿 `48<<16` 做循环上界 | 首帧在 `onNativeWindowCreated` 里约 10^13 次迭代，主线程卡死 → ANR → 系统杀进程，看起来也是闪退 | 光栅入口统一 `fx_px()` 换算；`draw_image` 按可见区裁剪 |
| 3 | `tools/gen_auf.py` 用 `<IBBBbbBBIH` 打包，实际 17 B/项；解析器按 16 B 步进、bitmap_off 读 @12 | 除第一个字形外全部查不到，文字整片缺失（图标/色块正常） | 改为 16 B 布局（`<IBBBbbBBBI`，pad 在 @11，bitmap_off @12），重新生成字体 |

同时加了两件诊断设施（不依赖 adb）：

- **启动轨迹**：`aui_android_attach` 打开
  `/sdcard/Android/data/<pkg>/files/trace.txt`（`externalDataPath`，偏移 40），
  每个里程碑写一行：`S` attach、`d`+density、`I` init、`K` 回调表、`W` 窗口、
  `N`+节点数、`L` 布局、`P`+命令数、`F` 呈现、`R` 重绘、`X` 销毁。
  闪退后最后一行即崩溃阶段。实现只用 `openat/write` 原始系统调用，无 Java、无 JNI。
- **诊断 APK**：`probe1-red.apk`（裸 NativeActivity 纯红屏，验证打包/加载/窗口）、
  `probe2-text.apk`（AsterUI 最小两行文字，验证库核心），与主包不同包名可共存。


### D.6 第二次真机反馈：三个包全闪退且没有 trace（根因在 `link-so`）

D.5 的三处修复完成后，反馈变成「probe1 / probe2 / uihello 全部闪退，
外部数据目录里连 trace.txt 都没有」。trace 文件由 `aui_android_attach`
第一行创建，**文件不存在说明 `ANativeActivity_onCreate` 一次都没执行**，
所以问题不在布局、光栅、字体或 ANR，而在 `.so` 被 `dlopen` 的阶段。

用 `readelf --dyn-syms` / `readelf -r` 审计三个 `.so`，发现同一形状的致命
重定位：每个「把函数地址存进回调表/按钮表」的引用，都对应一条
`R_AARCH64_GLOB_DAT`，符号名与同一 `.so` 里已定义的函数重名，但该符号表项
是 `UND OBJECT`（`st_shndx = 0`）。数量：`libuihello.so` 22 条、
`libprobe1.so` 4 条、`libprobe2.so` 19 条。`.so` 带 `BIND_NOW`，Android 链接器
必须在 `dlopen` 时解析全部 GLOB_DAT；它按名字查到的却是未定义项（或只查
依赖库），于是报 `cannot locate symbol ...` 并中止加载。进程在入口之前就死，
自然没有 trace。

qemu harness 没发现，是因为它用 `link-obj` 把 `.o` 静态链接成可执行文件，
函数地址在链接期就解析成常量，根本不经过 `.so` 的 GOT/GLOB_DAT——这是
v1 测试链路的一个盲区。

根因在 Aster 编译器的 `link-so` 多对象分支：GAT 引用分类只查了
`defObjs`，漏了 `defFuncs`，于是把「已定义函数的地址」当成「外部数据导入」，
生成了 UND GLOB_DAT。`build-so` 单对象分支本来就有这个检查，会把它归入
`funcAddrRefs` 并生成 `R_AARCH64_RELATIVE`；两条路径行为不一致。

修复：在 `link-so` 分支补上 `defFuncs` 检查（`patches/aster-link-so-funcaddr.patch`），
重链后三个 `.so` 的 GLOB_DAT 数量均为 0，函数地址槽全部是
`R_AARCH64_RELATIVE`（加载器写入 `base + st_value`）。新增
`tools/check_so.py` 作为构建门禁：只要还存在「指向自身 UND 符号的重定位」
就拒绝产出。对已经生成的坏 `.so`，`tools/fix_selfreloc.py` 可原地把这些
GLOB_DAT 改成 RELATIVE 作为应急。

同时给 `probe1` 加了独立于 AsterUI 的 `p1.txt` 轨迹（`A` onCreate、
`K` 回调表、`W` 窗口、`F` 首帧、`R` 重绘）：没有 `A` 就说明加载器还没把
控制权交给库，与 UI 代码无关。这比 `trace.txt` 更早一环。

仍未验证：真机 `dlopen` 行为本身（静态审计只能证明重定位形状合法，
不能替代真机）。若换新包后仍无 `A`/`S`，下一步只能取系统 logcat 或
bug report 里的 `cannot locate symbol` / `signal 11` 行。

### D.7 第三次真机反馈：GLOB_DAT 修完仍闪退（悬空 `DT_VERNEED`）

D.6 的 GLOB_DAT 修复交付后，反馈仍是「还是闪退」。此时三个 `.so` 的重定位
已经全部合法（GLOB_DAT 0 条），说明还有第二个**加载期**致命条件。继续逐项
核对 `readelf -dW` 的动态标签，发现每个 `.so` 都有：

```
0x6ffffffe (VERNEED)     0x10090
0x6fffffff (VERNEEDNUM)  1
```

指向 `.gnu.version_r`，内容为 `vn_file = "libc.so.6"`、`vna_name = "GLIBC_2.17"`，
而三个 `.so` 的 DT_NEEDED 只有 `libandroid.so` / `liblog.so` / `libm.so`
（probe1 只有 libandroid.so）。这是 Aster 从桌面 ELF 习惯照搬的“声明 libc
基线”，**但 Android 的 libc 是隐式依赖，soname 从来不叫 `libc.so.6`**。

对照 AOSP bionic `linker/linker_soinfo.cpp` / `linker.cpp`
（`VersionTracker::init_verneed`，本机核对的是 aosp-mirror/platform_bionic
master）：

```cpp
uintptr_t verneed_ptr = si_from->get_verneed_ptr();
if (verneed_ptr == 0) return true;             // 没有 DT_VERNEED 就跳过
...
soinfo* target_si = si_from->get_children().find_if(
    [&](const soinfo* si) { return strcmp(si->get_soname(), target_soname) == 0; });
if (target_si == nullptr) {
  DL_ERR("cannot find \"%s\" from verneed[%zd] in DT_NEEDED list for \"%s\"", ...);
  return false;
}
...
bool VersionTracker::init(const soinfo* si_from) {
  ...
  return init_verneed(si_from) && init_verdef(si_from);
}
```

即：只要存在 `DT_VERNEED`，其中每个 `vn_file` 都必须是本库 DT_NEEDED
子节点之一的 **soname**；`libc.so.6` 不在其中，`dlopen` 直接返回失败。
这个检查与符号是否真的使用该版本无关——`init_verneed` 在加载时就无条件
执行。三个 `.so` 的导入符号 versym 原本就是 1（无版本），没有任何符号
引用 index 3，所以这段 verneed 纯属有害的死数据。

修复：`link-so` 的 `writeSharedObjectDyn`（以及静态 `writeSharedObject`）
不再输出 `DT_VERNEED` / `DT_VERNEEDNUM`（`patches/aster-no-verneed.patch`）。
保留 `DT_VERDEF` / `DT_VERSYM`：定义侧版本（BASE + `aster`）是合法的，
bionic 的 `init_verdef` 能正常解析，dlsym 对非 hidden 的默认版本也能找到
符号（`check_symbol_version` 在 `verneed == kVersymNotNeeded` 时只检查
hidden 位）。`.gnu.version_r` 的字节和 section header 仍在文件里，但不再
有动态标签指向，加载器完全忽略。

门禁同步扩展：`tools/check_so.py` 现在解析 `.dynamic` 与 `.gnu.version_r`，
按 bionic 的同一规则检查每个 `vn_file` 是否在 DT_NEEDED 中；旧 `.so` 会
直接报 `verneed[0] requires "libc.so.6", not in DT_NEEDED [...]`。

诊断再加一层：`probe1` 的 `__aster_init`（INIT_ARRAY，dlopen 成功后、
`ANativeActivity_onCreate` 之前运行）会写
`/storage/emulated/0/Android/data/dev.aster.probe1/files/p1boot.txt`，内容
`B`。框架在调用 `LoadNativeCode` 之前已经用 `getExternalFilesDir(null)`
创建了该目录。于是三段可区分：

- 连 `p1boot.txt` 都没有 → 仍然卡在 `dlopen`；
- 有 `B` 没有 `p1.txt` 的 `A` → `.so` 已加载、init 已跑，崩溃在 init 与
  onCreate 之间；
- 有 `A K W F` → 加载/回调/窗口/首帧全部通过。

仍未验证：真机 `dlopen`。两次修复（GLOB_DAT、悬空 VERNEED）都是 bionic
源码里明确的硬失败条件，静态形状已与 bionic 要求一致，但只有真机能最终
确认。

---

### D.8 第四次真机反馈：`+` / `-` 不改变数字（输入事件类型常量写错）

v1.3 的轨迹已经跑完整条生命周期（`S → I → K → W → N → L → P → F → R →
F → X`），三张截图也证明窗口、布局、字体、圆角、按钮都正常；但点按
`+` / `-`，计数不变。这不是绘制问题，而是触摸事件在进入命中测试之前就
被整批丢弃了。

根因只有一行：

```aster
let typ: i32 = AInputEvent_getType(ev);
if (typ == 1) {                 // BUG
    let r0: i32 = handle_motion(ev);
}
```

Android 的 `AINPUT_EVENT_TYPE_KEY = 1`，`AINPUT_EVENT_TYPE_MOTION = 2`
（`android/input.h`）。触摸是 `MOTION`，所以 `typ == 1` 对所有触点都为假，
`handle_motion` 一次都没执行；`finishEvent(..., 1)` 还会把这些事件标成
「已处理」，系统侧看起来一切正常。v1.4 改为 `typ == 2`，并加了常量注释。

为什么之前的 qemu 测试没抓到：`tests/fake_ndk.ast` 里
`AInputQueue_getEvent` 永远返回 `-1`、`AInputEvent_getType` 永远返回 `0`，
输入路径在测试里根本没有事件流过。v1.4 把假 NDK 改成可脚本化：

- `fake_post_motion(action, x, y)` 压入一个 MOTION 事件；
- `AInputEvent_getType` 返回 2，`AMotionEvent_getAction` 返回预设动作；
- `AMotionEvent_getX/Y` 记下「当前取的是 X 还是 Y」，`lrintf()` 据此返回
  预设坐标——真机上这一步是 s0 里的 float，测试里用轴标记模拟同一条时序。

`tests/headless_test.ast` 现在会在离屏渲染后用 `aui_debug_rect(6, ...)`
查出 `+1` 按钮的像素矩形，模拟 DOWN/UP，断言计数从 0 变 1；再验证
「点按钮外不触发」「按钮上按下、别处抬起不触发」。用旧的 `typ == 1`
编译同一份测试，进程返回 5（回调没触发），证明这个测试确实能拦住回归。

两个顺带的加固：

1. **looper 兜底**。`aui_cb_iq_created` 原来直接
   `ALooper_forThread()` 后 attach。AOSP 的 `ALooper_forThread()` 就是
   `Looper::getForThread()`；NativeActivity 的 Java MessageQueue 构造时
   已经 `Looper::setForThread`，正常情况下非空。但为防某些定制 ROM/线程
   模型差异，v1.4 在返回 0 时调用
   `ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS)`，仍为 0 则放弃
   attach，不再解引用空指针。
2. **坐标桥门禁**。`AMotionEvent_getX/Y` 返回 C `float`（AArch64 的 `s0`），
   Aster 没有 float 类型，库里的做法是先按 i32 接收（拿到无用的 `x0`），
   紧接着调用无参 `lrintf()` 读 `s0`。这个技巧只在两条调用之间没有任何
   指令写 `s0/d0/q0/v0`、也没有别的调用时成立。反汇编确认 v1.4 的
   `event_x` 是：

   ```
   bl AMotionEvent_getX
   str w0, [sp, #8]      ; 不影响 s0
   bl lrintf
   ```

   `tools/check_input_bridge.py` 对 `aui_impl.o` 做结构检查，出现第三条
   调用或任何写 `s0` 的指令就拒绝构建。

诊断轨迹也扩了。v1.4 的 `trace.txt` 在触摸时会追加：

```
A00000001     A + 1 = 进入 onInputQueueCreated 时线程已有 NDK looper（0 = 没有）
B00000001     B = forThread 为空、已调用 ALooper_prepare
Q00000000     Q + attachLooper 返回值（0 = 成功）
T00000000     T + action（0 = DOWN，1 = UP）
x0000014A     x + 触摸像素 x
y00000320     y + 触摸像素 y
```

这样如果真机上仍不响应，可以直接区分：没有 `A/Q` = 输入队列回调没来；
有 `A/Q` 没有 `T` = 事件没到 looper 或类型仍不对；有 `T/x/y` 但数字不动 =
命中测试/坐标问题，`x/y` 的数值会直接暴露桥是否失效。

真机确认（v1.4，用户提供的 `trace.txt`）：`A00000001`（UI 线程已有
NDK looper）、`Q00000000`（attach 成功），随后每次触点都有
`T/x/y`，坐标与按钮位置一致（`+` 约 x=1038/y=487，`-` 约 x=161/y=545，
Reset 约 x=667/y=691）。更关键的是重建次数的签名：

- `ACTION_DOWN` 命中按钮 → 只有一次 `N L P F`（按压态重绘）；
- `ACTION_UP` 命中同一按钮 → **两次** `N L P F`：第一次来自
  `on_add/on_dec/on_reset` 里的 `aui_invalidate()`，第二次来自
  `handle_motion` 末尾的 `aui_invalidate()`；
- 有一次触点在 x=1075（1080 宽屏的最右缘）落在按钮外：DOWN 没有
  `N`，UP 只有一次 `N`，正好符合“未命中就不触发回调”。

因此 v1.4 的触摸派发、命中测试、回调执行都已由真机确认；`+` / `-` /
Reset 的数字会按预期变化。坐标桥（`s0` → `lrintf`）在真机上也给出了
合理像素值，不再只是静态推断。

---

### D.9 第五次迭代（v1.5）：滚动容器

v1.4 解决了「点得动」。v1.5 要解决「内容装不下时怎么办」：一个可拖拽的
`aui_scroll` 容器，加上一个 24 行（12 行 + 按钮 + 12 行）的列表演示
`examples/ui_list.ast`。

这个功能在 AsterUI 里比在常规 UI 框架里难，原因是**树每帧重建**：布局阶段
生成新节点、绘制后销毁，滚动偏移如果只存在节点字段里，下一帧就归零。因此
偏移必须放在树外。v1.5 的做法是一张按 `key` 索引的小表：

```aster
let AUI_SCROLL_CAP: i32 = 64;
let g_aui_scroll_key: i32[64];   // 节点 key
let g_aui_scroll_val: i32[64];   // 当前偏移 Q16.16，>= 0
let g_aui_scroll_max: i32[64];   // 最大偏移 = 内容高 - 视口高
```

`scroll_get/set` 只接受非负值，`set` 以 `max` 夹紧；`arrange_scroll` 每帧
调用 `scroll_store_max(key, n.aux - n.h)`，窗口旋转或内容变化后旧偏移会
自动收进新范围。key 为 0（没有显式 key 的节点）不参与滚动，避免所有匿名
节点共享一个偏移。

**布局。** `measure_scroll` 用可用高度约束子节点宽度，但按内容累加高度
（`pad*2 + Σ子高 + gap*(n-1)`），把内容高存进 `aux`，返回内容高而不是
视口高；`arrange_scroll` 把子节点排在 `n.y + pad - offset`，子节点拿到的
仍是**绝对坐标**。这点很关键：命中测试一直走绝对坐标，所以滚动后按钮
不需要额外的坐标换算，`hit_test` 与 v1.4 完全一样。`arrange()` 在
`k==9` 时直接走 `arrange_scroll`，不再把 scroll 当普通 column 处理。

**裁剪。** 显示列表的命令结构从 56 B 扩到 64 B，尾部加了
`cx/cy/cw/ch`（Q16.16 绝对坐标）四个字段。绘制每个节点前，`paint_node`
把当前裁剪矩形与 scroll 视口求交、压栈、画完恢复；`cmd_add` 把当时的
裁剪矩形写进命令。光栅器对矩形、文字、字形、图片四条路径都做裁剪，且
圆角矩形**先算四角再裁剪**——反过来会把圆角切出直边。这里没有实现通用
的裁剪栈，只维护「当前矩形 + 一层保存」，因为 v1.5 的语义只需要父子
scroll 嵌套。

**拖拽。** DOWN 时沿父链找最近的 `k==9` 节点（`find_scroll`），记下
`drag_key`、按下 y、当时偏移；MOVE 超过 8 dp 的 slop 才进入拖拽，并把
`aui_pressing` 清零，避免滚动结束时误触按钮；进入拖拽后偏移 =
`起始偏移 - dy`，经 `scroll_set` 夹紧。偏移真的变化时打一条
`v + 新偏移` 轨迹并 `aui_invalidate_layout()`。UP 时只有在「按下与抬起
是同一 key、且没发生过拖拽」才派发 `on_tap`；CANCEL 清掉按压与拖拽。

**顺带修的两处。** 按钮文字原来固定画在 `n.y + pad`，按钮被拉伸后文字
贴顶；`emit_text_lines` 增加 `ytop` 参数，按钮用
`n.y + (n.h - text_line_h())/2` 居中。另一个是布局陷阱：column 里带
weight 的子节点会先把 column 自身量成内容高，如果直接把 `aui_scroll`
放进 column 而不给它 `weight(1)` 或固定高度，滚动视口会被压成 0。
README 已写明这条约束，scroll 内部暂不支持 weight 子节点。

**测试。** 两层：

1. `tests/scroll_test.ast`（200×200 离屏）：内容 494、视口 180、最大偏移
   314。断言初始偏移 0；向上拖 40 px 后偏移 40、色块 y 从 50 变 10；
   滚出视口后按钮点击不触发；期间检查 (5,5) 不是红色、(5,25) 是红色，
   验证裁剪；再拖到上限 314 并拖回 0。返回码 0..12 对应各断言。
2. `tests/list_harness.ast`：在 720×1280 的假窗口里驱动真实的
   `ui_list` 应用，从列表中心向上拖 300 px，断言偏移 300、按钮 y 坐标
   随内容上移 300、随后点击按钮使计数变 1。

构建门禁（`build.sh` 九步）新增 `check_so`/`check_input_bridge` 对
`libuilist.so` 的检查，并生成 `uilist.apk`（包名 `dev.aster.uilist`，
versionName 1.5）。四个 .so 的静态门禁仍然全部通过：命令扩到 64 B 后
RELATIVE 重定位 100/96 与 RELACOUNT 前缀一致、GLOB_DAT 为 0、无
DT_VERNEED、p_align 0x4000、APK 内 .so 数据偏移 16384。

真机确认（v1.5，用户提供的滚动 `trace.txt`）：density 为 3.25
（`d00034000`），单帧 81 节点 / 80 命令；拖动时 `v` 从 0 连续增大到
`0x2738000`（627.5 px，等于内容高减视口高）后钳住，回拖回到 0 且不出现
负值；滚动后点列表按钮仍产生两次 `N L P F`，全程无崩溃。即偏移表、
夹紧、裁剪重建和滚动后命中的真机行为符合设计。

当时尚未验证：惯性（fling）、scroll 内 weight 子节点、同一 key 的嵌套
scroll。惯性在 v1.6 实现。

---

### D.10 第六次迭代（v1.6）：fling 惯性 + 滚动条

v1.5 让列表能拖，但松手就停。v1.6 补上惯性滑动和可见滚动条，仍然只用
Aster 能表达的东西：没有 float、没有线程、没有 `std::chrono`。

**为什么用 timerfd + ALooper。** Aster 没有线程 API，也不能在 UI 线程之外
碰节点池。Android 上最自然的方式是让同一个 looper 定时回调：创建
`timerfd`（`CLOCK_MONOTONIC`、`TFD_NONBLOCK`），用 `timerfd_settime`
设 16 ms 周期，再 `ALooper_addFd(looper, fd, ident, ALOOPER_EVENT_INPUT,
cb, data)`。回调在 UI 线程执行，可以直接调 `aui_frame(now_ns)`，不需要
任何锁。looper 就是 `onInputQueueCreated` 里拿到的那个（v1.4 已缓存
`g_aui_looper`）；没有 looper 或 `timerfd_create` 失败时 `fling_start`
直接放弃，滚动本身不受影响。

**速度。** 每个 MOVE 用 `clock_gettime(CLOCK_MONOTONIC)` 求 `dt`，
`dy/dt` 得瞬时速度（Q16.16 px/s），再与已有速度做 3:1 低通
（`(v*3 + inst)/4`），避免最后一帧抖动主导。`dt` 上限 100 ms，速度上限
12000 px/s。UP 时只有「确实拖动过、UP 距最后一次 MOVE < 80 ms、
|v| > 200000（约 3 px/s）」才启动 fling，否则视为普通点击/微动。

**衰减。** 每 16 ms：`dv = v * dt / 1e9`，偏移按 `dv` 增加；随后
`v -= v/16`。`dt` 取真实间隔但上限 32 ms，所以掉帧不会跳变。速度绝对值
低于 200000 或偏移被 `scroll_max` 钳住时立即停止；按下（DOWN）也立即
停止并清 `g_aui_fling_active`。轨迹里 `g + 初速度` 表示开始，`h + 0`
表示结束，`v` 仍记录每次偏移变化。

**滚动条。** 只画不交互：内容高 `aux` > 视口高 `h` 时，在节点右缘内
3 dp 处画 3 dp 宽、不透明灰 `0xFFAEB8CC` 的圆角条；高度 =
`h*h/aux`，最小 24 dp；位置在 4 dp 内缩的轨道上按 `off/max` 线性移动。
颜色刻意不用半透明：v1.5 的矩形填充直接写 RGBA，不做 alpha 混合，
半透明会被当成实色。`paint_node` 在画完子树、恢复裁剪之前调用
`paint_scrollbar`，所以条本身也被视口裁剪。

**生命周期。** `onPause` / `onStop` / `onWindowDestroyed` / `onInputQueueDestroyed`
/ `aui_shutdown` 都会 `fling_stop`；输入队列销毁或 shutdown 还会
`ALooper_removeFd` + `close` 计时器 fd。`aui_frame(now_ns)` 的第一行是
`fling_step(now_ns)`，因此宿主即使自己驱动帧循环也能得到同样的衰减；
`now_ns <= 0` 时跳过（给旧调用方留的兼容路径）。

**测试。** `tests/fling_test.ast`（200×200、可滚 700 px）不依赖真实时间，
直接调 `aui_debug_fling_start(key, velocity, now)` 和
`aui_debug_fling(now)`：

- 1200 px/s 在 250..340 px 内停住，且第二次 tick 返回已停止；
- 5000 px/s 撞到底部 700 后钳住并停止；
- 已在 700 时向外（正值）启动被拒绝（返回 0）；
- 从 700 以 -1000 px/s 反向，最终落在 300..550；
- 2 px/s 被拒绝；
- 滚动条像素 (195,10) 的亮度低于 220（灰条存在）。

qemu 的假 NDK 把 `clock_gettime` 写成 0、`timerfd_create` 返回 -1，
所以 headless 路径实际走的是「计时器不可用 → 放弃 fling」的降级分支；
纯衰减逻辑由上面的注入时间戳覆盖。另有临时渲染 harness（不入库）用假宿主
渲染 `ui_list` 拖动前后两帧，目视确认灰条位于圆角列表右缘内、拖动 300 px
后随偏移下移。

**边界。** 这一版没有过冲/回弹、没有按速度比例加速的「甩动曲线」、
滚动条不可拖动；fling 的 `timerfd` 回调节奏只在真机上才能最终确认。
`build.sh` 里三个可执行包显式 `--needed libc.so`，四个 `.so` 现有
4 条 DT_NEEDED，静态门禁（GLOB_DAT 0、RELACOUNT 前缀匹配、无 VERNEED、
16 KB 对齐）全部保持通过。

### D.11 第七次迭代（v1.7）：文本字段 + 自绘 ASCII 键盘

M2 里的「文本字段（ASCII）、自绘键盘」在 v1 只留下了 `aui_focus` /
`aui_text_value` 两个空声明。v1.7 把它们补成可用组件，仍然不引入 Java、
JNI、系统 IME 或任何输入法服务：键盘就是 AsterUI 自己画的普通节点，触摸
由现有的 `AInputQueue` 路径派发。

**为什么不接系统 IME。** 接 IME 需要 `InputConnection`、`Editable`、Java
对象和 `JNIEnv`，这直接违反「无 dex/Java/Kotlin」的硬约束；`ANativeActivity`
的软键盘 API 也需要 Java 侧 `Window`。因此 v1.7 选择「字段 + 自绘 QWERTY」，
应用自己决定何时显示键盘（通常是 `if (aui_focus_get() != 0) aui_keyboard(key)`）。
代价是没有拼音/候选词/手势输入，只有 ASCII 可见字符；这对调试面板、配置页、
搜索框足够，对中文输入不够，这是明确的边界而不是遗漏。

**文本存储。** 节点每帧重建，文本不能挂在节点上。库内用固定池：
`AUI_TEXT_CAP = 32` 个槽，每槽 63 字节 + NUL，`g_aui_text_pool[2048]`，
`g_aui_text_key[32]` / `g_aui_text_len[32]` 记录归属与长度。按 key 线性查找，
不存在时取空槽；槽满后新 key 复用第 0 槽（文档写明上限）。API 为
`aui_text_append/backspace/clear/set/len/value`，`value` 返回池内指针，
无内容时返回 `g_aui_empty`（1 字节 0），调用方不必判空。纯 ASCII，
`append` 只接受 32..126。

**节点类型。** 字段是 kind 10：`aui_text_field(key, hint)` 记录 text 指针、
长度（`aux`）、hint（`user`），最小高度 48 dp + 12 dp 内边距，圆角 8 dp；
绘制时先画 surface/pressed 背景，聚焦时底部画 2 dp 主色线，文本为空画
hint（`0xFF8A8A93`），非空画 `text_fit_start` 的尾部（超长时保证光标可见），
再画 2 dp 光标。键盘键是 kind 11：`aui_key(key, code)` 把 ASCII/动作码放
`aux`，最小 42 dp 高、宽度 0，由 `weight` 分配；绘制时按 `code` 选
DEL/DONE/SHIFT/123/ABC/SPACE 或单字符标签。

**逐键标签。** 最初所有键共用 `g_aui_kb_ch` 一个 2 字节缓冲，绘制阶段
只看到最后一次写入的字符，真机/离屏都会出现「所有键同一个字母」。改为
`g_aui_kb_glyphs[128]`，每键槽号 = `key - 9000`，`paint_key` 在生成命令时
把自己的字符写进自己的槽；命令里的指针因此互不覆盖。SHIFT 打开时字母
槽写大写，关闭写小写；`123`/`ABC` 切换的是整个键盘布局（`g_aui_kb_mode`）。

**布局与 key。** `aui_keyboard(target)` 先铺一个 column（7000），再铺四行
（7001–7004）：Q 行 9000–9009、A 行 9020–9028 + DEL 9029、Z 行 9040–9049
（含 `,` `.`）、底行 123/ABC 9060 + SPACE 9061 + DONE 9062。`kb_key_w`
无论权重是否为 1 都调用 `aui_weight(wgt)`——这是第二个实测 bug：权重 1 的
键宽度保持 0，整行塌成一条线。行高 42 dp、行距 6 dp、键距 4 dp，容器
12 dp 内边距、圆角 8 dp、浅灰背景。

**焦点与命中。** `g_aui_focus_key` 是唯一焦点；`aui_focus(k)` 写焦点并
置 `g_aui_need_build/layout/paint`（必须重建，否则键盘不会出现/消失），
`aui_focus(0)` 收起。DOWN 时先找 kind 10/11 节点：字段设置按下态并清
drag，键设置按下 key；UP 时字段只做聚焦/保持，键则调 `kb_activate(code)`：
DEL 退格、DONE `aui_focus(0)`、SHIFT 切换、MODE 切换、SPACE 与可打印
字符追加（字母按 shift 映射大写）。按键处理后直接返回，不再落进按钮
的 `user` 回调逻辑；焦点变化或文本变化都会触发一次 `N L P F`。

**API 与版本。** 公共头新增 `aui_text_field`、`aui_keyboard`、`aui_key`、
`aui_focus_get`、`aui_text_len/append/backspace/clear/set`；`aui_version()`
返回 `10700`，APK versionCode 7 / versionName 1.7。`examples/ui_form.ast`
是完整示例：标题、字段、实时回显卡片、Clear/Focus 两个按钮，焦点非空时
才铺键盘。

**测试。** `tests/text_test.ast`（560×420，离屏）断言：字段初始无焦点；
点字段后 `aui_focus_get()==10` 且底部出现主色线；点 `q` 后文本为 `q`；
SHIFT 后点 `q` 得 `qQ`；DEL 退格；切 `123` 后点 `1` 得 `qQ1`；DONE 后
焦点与键盘消失；`aui_text_set/clear` 正常。`tests/form_harness.ast` 跑
真实 `ui_form` 的完整假宿主路径：初始无键盘、点字段出现、输入、
DONE 收起、Focus 重新唤起、Clear 清空。临时渲染 harness（不入库）导出
720×1280 帧，目视确认 `Hello`、光标、实时回显和四行键盘的逐键字母。
`build.sh` 新增 `libuiform.so` 与 `uiform.apk`，五个 `.so` 的静态门禁
（GLOB_DAT 0、RELACOUNT 前缀匹配、无 VERNEED、16 KB 对齐、无 dex）保持通过。

**边界。** 只支持 ASCII、单行、无选区/长按/光标闪烁/复制粘贴；字段本身
不滚动，超过 63 字节拒绝追加；不接硬件键盘与系统 IME；键盘不随窗口
resize 重排（按容器宽度均分），不支持自定义布局/语言。文本池 32 个 key，
键盘 key 段 9000–9062 由库保留。真机上的按键手感与 density 取整仍需确认，
字符串标签全部用数值 ASCII 写入 `.bss`，避免库内字符串字面量与应用的
`__aster_string_0` 符号冲突。

### D.12 第八次迭代（v1.8）：页面栈 + 系统 BACK

M3 的「页面导航 / 返回键」在 v1.7 之前完全空白：库只处理触摸，`AInputEvent`
的类型 1（KEY）被当作未知事件。v1.8 补上一个最小但完整的导航层，仍然
不引入 Java、Fragment、路由表或字符串分配。

**为什么路由是 i32。** Aster 没有堆分配，字符串比较与切片也没有运行时
辅助；把路由做成 `ptr` 字符串会迫使每个页面自己保存生命周期和比较逻辑。
v1.8 直接把 route 定义成 i32，栈是固定数组 `g_aui_nav_stack[8]`，
应用在 build 里用 `if (route == 2)` 分支。初始 route = 1、depth = 1，
`nav_ready()` 在第一次访问时写栈底，避免依赖全局初始化顺序。
`aui_nav_push` 在 depth 已达 8 时返回 -1；`aui_nav_pop` 在根返回 -1；
`aui_nav_reset(route)` 把栈截回一层并替换栈底。push/pop/reset 成功后
都把 `g_aui_route_key` 更新为新 route、清空 `g_aui_focus_key`，并调用
`aui_invalidate()` **同步**重建——应用在按钮回调里直接 `return
aui_nav_push(2)` 即可，不需要自己再请求重绘，也不会出现「先显示旧页
再闪一下」的两帧。

**BACK 的派发语义。** `aui_on_input` 先看 `AInputEvent_getType`：2 走
触摸，1 走 `handle_key`。`handle_key` 读 `AKeyEvent_getKeyCode` 与
`AKeyEvent_getAction`，只处理 `KEYCODE_BACK (4)`：DOWN 只写轨迹 `k`，
真正的决策放在 UP。原因是长按 BACK 会重复发 DOWN，若在 DOWN 里 pop
就会一次连跳多页；UP 只在松手时来一次。无论 DOWN/UP 都返回 1 表示
「本库消费了这个事件」，避免系统把同一次按键当成未处理再走一遍默认
返回。其他 keycode 返回 0，`AInputQueue_finishEvent` 的 handled 传 0，
交还给系统/应用。这点与触摸不同：触摸始终 handled = 1，因为 AsterUI
是整棵 UI 的唯一消费者。

决策顺序是 **焦点 → 栈 → 结束**：焦点非空时 BACK 只调 `aui_focus(0)`
收起键盘，文本保留、页面不动；否则 depth > 1 时 pop 一级；否则调
`aui_finish()`。`aui_finish` 用 `g_aui_finished` 做幂等保护，写轨迹
`b` 后调 `ANativeActivity_finish(activity)`；没有 activity（离屏测试）
时返回 -1。库不提供「拦截根页 BACK」的钩子：需要「再按一次退出」的
应用应自己放一个退出按钮，或在 build 里根据状态提示，而不是和系统
返回键抢语义。

**轨迹。** v1.8 新增三个字母：`k` + keycode（收到按键 DOWN，目前只会
出现 4；UP 不重复写）、`n` + route（导航变化后的新 route）、`b`（根页
BACK 即将结束 Activity）。配合 `N/L/P/F` 可以判断 BACK 是收了键盘
（节点数下降、文本仍在）、pop（route 变小、节点数变化）还是 finish
（`b` 之后进程退出）。长按会看到多行 `k00000004`，但只出现一次 pop。

**API 与版本。** 公共头新增 `aui_route`、`aui_nav_depth`、`aui_nav_push`、
`aui_nav_pop`、`aui_nav_reset`、`aui_finish`；`aui_version()` 返回
`10800`，六个 APK 的 versionCode 统一为 8 / versionName 1.8。
`examples/ui_nav.ast` 是三页示例：第 1 页可 push 2 或直接 push 3，
第 2/3 页可 pop 或 reset，页脚实时显示 Route 与 Depth。

**测试。** `tests/nav_test.ast`（离屏 320×480）断言：初始 1/1；push
2/3/4 后 route 与 depth 正确；push 会清掉已设置的焦点；连续 push 到
8 层后第 9 次返回 -1；pop 逐级回退；reset(5) 后 depth 回 1；根页
pop 返回 -1。`tests/nav_harness.ast` 跑真实 `ui_nav`：点按钮 push 到
2、再 push 到 3、用「DOWN, DOWN, UP」模拟长按 BACK，断言只 pop 一次、
再正常按 BACK 逐级 pop、直接 push、reset 回根，最后在根页按 BACK 断言
假 NDK 的 `ANativeActivity_finish` 被调用一次。`tests/form_harness.ast` 追加：键盘打开时按 BACK，断言
焦点与键盘消失、`aui_text_len` 仍为 2、页面没有 finish。三者在 qemu
上全部退出 0；`build.sh` 六个 `.so` 的 GLOB_DAT 0 / RELACOUNT 前缀
匹配 / 无 VERNEED / 16 KB 对齐 / 无 dex 门禁不变。

**一个必须记住的测试陷阱。** `nav_test` 最初在 `node_alloc` 处段错误：
Aster 只有在主链接对象包含全局初始化器（例如 `@embed`）时才生成并
调用 `__aster_init`。没有它，`g_aui_nodes` 这类指针全局保持 0，第一次
建树就写空指针。`nav_test` 因此也嵌入了字体文件并在 main 里
`aui_set_font`——即使导航测试完全不画字。所有新测试都应保留一个
`@embed` 初始化器。

**边界。** 栈固定 8 层，route 只能是 i32；没有转场动画、深链、参数
传递、导航状态保存/恢复、预测性返回手势、多栈或嵌套导航；Activity
被系统回收重建后 route 回到 1（库不写 saved state）；BACK 以外的
按键完全不处理；根页 BACK 直接结束 Activity，应用无法拦截。真机上
还需确认不同 ROM 的 BACK action 序列与手势导航行为。

### D.13 第九次迭代（v1.9）：内容区 / 安全区 / 旋转 / 深色主题

v1.8 之前，AsterUI 默认「窗口即画布」：根节点从 (0,0) 铺满
`ANativeWindow`，density 只在 attach 时读一次，颜色全部写死成浅色。
这在状态栏不透明、竖屏、浅色系统的 ROM 上能用，但一到边到边显示、
旋转、分屏或夜间模式就不对。v1.9 把系统状态收进库内，仍然不引入
Java/JNI/WindowInsets。

**内容区与安全区。** NativeActivity 的 `onContentRectChanged`（回调表
偏移 104）给出窗口坐标系里的内容矩形。库把它保存为原生像素
`g_aui_ct_l/t/r/b`，并设 `g_aui_ct_valid`；布局 `pump_ui` 把四边钳到
窗口内，换算成 Q16.16 内缩 `g_aui_inset_*`，再用
`root = (sl, st, sw-sl-sr, sh-st-sb)` 调 `measure/arrange`。如果矩形
退化（宽或高 <= 0），回退到整窗，避免横竖屏切换瞬间把根节点排成 0。
绘制时，只有存在内缩才在 `paint_node` 之前追加一条 `(0,0,sw,sh)` 的
全屏 `theme_bg` 命令，把状态栏/导航栏/刘海条带填上；正常全屏时根节点
自己的 kind 1 底色已经覆盖整屏，不重复。命中测试从根节点开始，根节点
只覆盖内容区，所以点在条带里不会命中任何控件——不需要额外的裁剪或
坐标偏移。`onWindowCreated` 与 `onWindowResized` 都先清
`g_aui_ct_valid`，等系统重新发内容区；resize 走**整树重建**而不是只
布局，因为应用可能在 build 里按宽高分支。`aui_debug_set_content` 是
给离屏测试的模拟入口。

**density 与 night。** `config_refresh()` 用
`AConfiguration_new → AConfiguration_fromAssetManager → getDensity /
getUiModeNight → delete` 读取当前配置。density 换成 Q16.16 的
`dpi*65536/160`，所有 dp 尺寸随之缩放；night 枚举存进
`g_aui_night`（0=ANY，1=NO，2=YES），等于 2 即
`ACONFIGURATION_UI_MODE_NIGHT_YES`，置 `g_aui_dark=1`。attach 时在
`init` 之前调用一次（保证应用 build 第一帧就是正确密度/主题），
`onConfigurationChanged`（偏移 112）再调用并整树重建；`onResume` 也会
重读一次（系统深浅色可能在后台变化，某些 ROM 不补发配置回调），只有
density/night/dark 实际变化时才重建。这里有一个
真机陷阱：NDK 的 `AConfiguration_fromAssetManager` 返回 **void**，
最初按 i32 声明并检查 `== 0`，在 qemu 假实现里碰巧成立，但真机上
x0 的残留值不保证为 0，会让整段配置读取被跳过。v1.9 改为调用后
直接读字段，不检查返回值。另一个更严重的陷阱见 D.14：NDK 只有
`getUiModeNight`，没有 `getUiMode`。

**主题角色。** 颜色不再散落在组件里，而是集中到 `theme_color(role)`：
浅色 bg `FFF6F6F8`、surface `FFFFFFFF`、primary `FF3A6DF0`、
primary_dark `FF2B55C8`、text `FF1A1A1E`、on_primary `FFFFFFFF`、
hint `FF8A8A93`、pressed `FFE8EEFF`、tint `FFEDF1FA`、scrollbar
`FFAEB8CC`、keyboard_bg `FFE9E9EE`；深色对应 `FF121216` /
`FF1E1E24` / `FF6E96FF` / `FF4F79E8` / `FFEFEFF4` / `FF0B1020` /
`FF9A9AA6` / `FF2A3550` / `FF232A3D` / `FF5A5A68` / `FF17171C`。
按钮、按钮按压、文本、提示、滚动条、键盘背景全部改为取角色；
`aui_theme_color(role)` 是应用可用的公共入口。`aui_set_dark(1)`
只改库内调色板并同步重建（写轨迹 `m`），不改系统设置；下一次
`onConfigurationChanged` 会按系统 night 枚举覆盖。公共角色 0..10 定义在
`aui_impl.ast`，头文件里用 `extern let`——否则 `ui_system.o` 与
`system_harness.o` 都 include 头文件时会出现重复的 `AUI_COLOR_*` 全局。
（Aster 支持 `extern let` 与直接调用返回 void 的声明，两者都在
v0.23.54-dev 上实测通过。）

**安全区 API。** `aui_safe_left/top/right/bottom` 返回 dp，内部是
`px_to_dp(fx_px(inset))`，即先四舍五入到像素、再做整数除法向下取整；
没有内容区或内容区等于整窗时全为 0。单位与布局 API 一致，应用不需要
自己乘 density。示例 `ui_system.ast` 用它显示 `L/T/R/B`，并在深色卡片
里给出 `Toggle dark` 按钮，方便在没有系统深色设置的情况下验证调色板。

**示例与测试。** `tests/system_test.ast`（离屏 720×1280）用
`aui_debug_set_density(420)` 把密度设为 2.625，先断言整窗根节点与
浅色角像素；再 `aui_debug_set_content(24,72,696,1208)`，断言根节点
`(24,72,672,1136)`、label 偏移到 `(50,98)`、安全区 dp 为
`9/27/9/27`、命令数恰好 +1（全屏底色）、安全区内按钮仍能点中；
然后 `aui_set_dark(1)` 断言深色角像素、`AUI_COLOR_SURFACE` 与
`KEYBOARD_BG`，最后恢复全屏/浅色并断言命令数回到初始值。
`tests/system_harness.ast` 跑真实 `ui_system`：720×1280 → 1280×720
触发 `onNativeWindowResized`（偏移 64）；内容区回调后根节点
`(40,60,1200,600)`、label `(103,123)`、安全区 `15/22/15/22`；
再把假配置改成 density 160 + night `2`（NIGHT_YES），触发偏移 112，断言
dark=1、label `(64,84)`、primary `FF6E96FF`、角像素深色；最后点
`Toggle dark` 回到浅色。`tests/fake_ndk.ast` 因此增加了可变的
`g_fake_win_w/h/density/night`，`ANativeWindow_getWidth/Height` 与
`lock` 都跟随窗口尺寸，`AConfiguration` 返回假配置。两个测试在
qemu 上退出 0，完整 12 项套件全部通过；导出 720×1280 的浅色（带
状态栏/导航栏内缩）与深色帧目视确认卡片、按钮、安全区数值与背景
条带。

**测试陷阱。** 离屏默认 density 是 1.0（`65536`），不是 420；直接按
2.625 写期望值会得到错误的像素坐标。v1.9 增加
`aui_debug_set_density(dpi)`，测试必须先设密度。另一个坑是字体
`@embed`：如果 app 与被链接的 harness 各自 embed 一次，Aster 会给
两个对象生成同名 `__aster_embed_0`，链接期报 duplicate global。
`system_harness` 因此不再 embed，直接复用 `ui_system.o` 的全局初始化器，
同时保留 `g_anchor` 以确认 `__aster_init` 真的运行了。

**Manifest 的 configChanges。** Aster 的 `build-apk` 原先写死
`android:configChanges="0x490"`（keyboard|orientation|screenSize）。
这组标志下旋转不会重建 Activity，但系统深浅色（uiMode）和 density
变化仍会重建——重建后 attach 会重新读配置、页面也能恢复，但
`onConfigurationChanged` 永远不会被调用，v1.9 的配置路径在真机上
等于没测到。v1.9 给编译器加第四个补丁
（`patches/aster-configchanges.patch`），把值改成 `0x1F90`：
keyboard|orientation|screenLayout|uiMode|screenSize|smallestScreenSize|
density。这样旋转走 `onNativeWindowResized`，深浅色/density 走
`onConfigurationChanged`，Activity 不重建，页面栈、文本池、滚动偏移
和焦点都原地保留。补丁只改 APK 生成器的 manifest 常量，不改变任何
Java/Kotlin/dex 结构。

**API 与版本。** 公共头新增 `AUI_COLOR_*`（extern let）、
`aui_theme_color`、`aui_dark`、`aui_set_dark`、`aui_safe_left/top/right/
bottom`，以及测试用的 `aui_debug_set_content`、`aui_debug_set_density`；
v1.9.1 的 `aui_version()` 返回 `10901`，七个 APK 的 versionCode 统一为
10 / versionName 1.9.1。新增 `libuisystem.so` / `uisystem.apk`
（`dev.aster.uisystem`，标签 `UI System`）。七个 `.so` 的静态门禁
（GLOB_DAT 0、RELACOUNT 前缀匹配、无 VERNEED、16 KB 对齐、无 dex、
无已知不存在的 NDK 符号）保持不变；其中六个带 AsterUI 的库仍是 4 条
DT_NEEDED，probe1 只有 libandroid。

**边界。** 内容区完全依赖 ROM 是否/何时调用 `onContentRectChanged`，
库不做 WindowInsets 查询（那需要 JNI）；状态栏图标明暗无法控制（除非
ROM 按 uiMode 自动切换）；没有字体缩放（`AConfiguration_getFontScale`
返回 float，Aster 无 float）、语言/布局方向切换、每控件自定义配色、
内容区过渡动画。`aui_set_dark` 是库内覆盖，不是系统设置写入。
v1.8 真机 trace 已确认按钮导航（route 依次 2/3 切换、节点数 14、
命令数 15/16），但该 trace 没有 `k/b`，系统 BACK 仍只有 qemu 证据；
v1.9 的内容区/深色/旋转全部为 qemu + 离屏验证。

### D.14 v1.9.0 启动崩溃：不存在的 `AConfiguration_getUiMode`

v1.9.0 的 `uisystem`（以及所有链入 `aui_impl.o` 的 APK）在真机
`dlopen` 阶段就失败，`ANativeActivity_onCreate` 一次都没执行，因此
连 trace 文件都不会创建。根因是 `config_refresh()` 调用了
`AConfiguration_getUiMode`——这个符号在公开 NDK/libandroid 中**不存在**。
NDK 的配置 API 只有 `AConfiguration_getUiModeNight`（返回
`ACONFIGURATION_UI_MODE_NIGHT_ANY/NO/YES` = 0/1/2）和
`AConfiguration_getUiModeType`，没有把整个 uiMode 打包返回的函数。
v1.9.0 还按 Java `Configuration.UI_MODE_NIGHT_MASK` 的语义写了
`uiMode & 0x30 == 0x20`，这同样不适用于 NDK 枚举。

为什么 qemu 没抓到：`tests/fake_ndk.ast` 和 `tests/android_stubs.ast`
按同一个错误假设**发明**了这个假函数，测试因此全部通过；静态门禁只检查
重定位、VERNEED、对齐，没有对照真实平台的导出表。真实 `.so` 的
`.dynsym` 里留下 `UND AConfiguration_getUiMode`，bionic 在加载时
报 `cannot locate symbol "AConfiguration_getUiMode"`，先于任何应用代码。

v1.9.1 的修复：

- `extern fn AConfiguration_getUiModeNight(cfg) -> i32`，直接把返回值
  存进 `g_aui_night`；只有等于 `2` 才置 `g_aui_dark=1`。
- 两个测试替身同步改名，`system_harness` 的假夜间配置从 `0x21` 改为
  `2`（`g_fake_night`），否则会测到一个现实中不可能出现的值。
- `tools/check_so.py` 增加 `BAD_UNDEF` 黑名单，构建时直接拒绝
  `AConfiguration_getUiMode` 这类“看起来合理但平台不导出”的导入；
  这比只依赖 qemu 更接近真机加载器的行为。
- 版本升到 versionCode 10 / versionName 1.9.1，`aui_version()` 返回
  `10901`；七个 APK 全部重打包，安装时覆盖旧版即可。

结论：Aster 侧没有语言问题，问题在**把平台 API 当成推测接口**。
凡是 `extern fn`，名字与返回值必须以 NDK 头文件/参考页为准，测试替身
不能反向定义不存在的东西。

### D.15 第十次迭代（v1.10）：动画槽 / 绘制阶段变换

HuxerUI 的路线图里「Interaction and animation」是 M3 的第一项，AsterUI
按 §11.2 先做最小但完整的动画系统：**64 个固定槽、alpha + tx/ty、三种
缓动、与 fling 共用的 16 ms 帧**。

实现要点：

- 槽按 `(key, prop)` 寻址，`prop` 为 `ALPHA(1)/TX(2)/TY(3)`；`ALPHA` 是
  0..255，`TX/TY` 是 dp。树每帧重建也不会丢槽。
- `anim_begin` 目标未变时保留进度（build 每帧重复调用不会重置）；
  目标变化时从当前 `val` 改道。`duration_ms <= 0` 或 `from == to`
  直接落终值，不占帧。
- `anim_step(now)` 逐槽按 `elapsed/duration` 算 Q16.16 进度并缓动；
  只在值变化时置 PAINT。最后一个活动槽结束时 `frame_timer_disarm()`。
- 动画**只影响绘制**：`paint_node` 在进入节点时读该 key 的 alpha/tx/ty，
  乘进 `g_aui_paint_alpha`、加进 `g_aui_paint_dx/dy`，子树继承；
  `cmd_add` 把颜色 alpha 与 Q16.16 坐标统一叠加。build/layout/命中
  测试完全看不到动画值。
- 滚动视口的裁剪矩形在进入 scroll 节点时也按当前绘制位移换算，因此
  被动画移动的滚动容器仍能正确裁剪；子节点自己的 tx/ty 不会带走视口。
- 光栅端：`fill_run` 在 alpha=255 时保持原来的整行写入，半透明时逐像素
  `blend_px`；`draw_glyph` 用命令颜色高字节作为文字 alpha；`draw_image`
  增加命令 alpha 参数并与像素 alpha 相乘。
- 生命周期：`onPause/onStop` 停表（槽保留），`onResume` /
  `onInputQueueCreated` 重新同步；`aui_shutdown` 清空所有槽与绘制状态。
  `aui_anim_reset` 只置 PAINT，不触发 build。
- 调试：`aui_debug_set_time(t)` 切到注入时基，配合 `aui_frame(t)` 可逐帧
  断言；`anim_test` 用它在 qemu 上验证 0 → 128 → 255 的 alpha、
  30 → 15 → 0 dp 的 TX、半透明像素的精确混合、动画期间 build 次数不变、
  64 槽上限和第 65 个被拒绝；`anim_harness` 跑真实 `ui_anim` 的
  onCreate → 首帧 → 中点 → 结束 → Replay → pause/resume/destroy。

Aster 编译器的一个坑：Sema 把整数算术（`Add/Mul/...`）标成 i32，而
Codegen 按操作数宽度提升到 i64；这个差异在 `>>` 节点上会触发
`TypedIR MISMATCH`（`type=i32 exprType=i64`）。因此 i64 右移必须作用在
i64 **变量**上，不能直接写 `(a + b) >> 16`：

```aster
let q: i64 = p + 32768;      // 先落到 i64 变量
return i32(q >> 16);         // Shr 的左操作数是 Var(i64)，两遍一致
```

边界：v1.10 没有颜色/尺寸动画、没有弹簧、没有共享元素转场、没有
damage 区域；动画帧仍是全量重绘。`AChoreographer` 对齐 vsync 留到后续。
版本升到 versionCode 11 / versionName 1.10.0，`aui_version()` 返回
`11000`；新增 `uianim.apk`，测试从 12 项增加到 14 项。

---

### D.16 第十一次迭代（v1.11）：页面转场（命令快照）

HuxerUI 的 `docs/design/animation.md` 把导航/场景转场列为 transition 的
第一类。AsterUI 的节点树每帧重建，保留旧树不现实；整屏像素快照又要
720×1280×4 ≈ 3.5 MB。这里选择**复制上一帧的扁平命令列表**：128 KB 的
2048 条命令池 + 48 KB 文本池，零堆分配，深拷贝量只与命令数有关。

实现要点：

- `page_capture` 把 `g_aui_cmds` 逐条复制到 `g_aui_page_pool`（每条 64 B，
  含裁剪矩形）；文字命令（op=2）把 UTF-8 字节复制进 `g_aui_page_text`，
  因为下一次 build 会覆盖节点文本池；图片命令保持指针（应用持有的 RGBA
  在转场期间不变）。超过 2048 条命令或 48 KB 文本时放弃转场（直切）。
- `page_begin(dir, ms)` 在 `nav_changed` 里、`aui_invalidate` 之前调用：
  push 传 `dir=1`、pop 传 `-1`、reset 传 `0`；同时清掉进行中的按压/拖动，
  避免转场结束后残留按压态。
- `draw_frame`：无转场时等价于原来的 `draw_cmds`。有转场时先铺一条不透明
  主题底色（两层都半透明时不至于透出上一帧形成拖影），再画旧页快照
  （alpha `255-255e`、dx `-20dp·e`）与新页当前列表（alpha `255e`、
  dx `20dp·(1-e)`）；pop 反向，reset 两层都不位移。
- 进度 `e` 用 `AUI_EASE_OUT`；`page_step(now)` 到时清标志、置 PAINT，
  三个子系统（fling / 动画 / 转场）都空闲才 `frame_timer_disarm`。
  `aui_frame_tick`、`anim_step`、`fling_stop`、`frame_timer_sync` 的停表
  条件都补了 `g_aui_page_on == 0`。
- 输入：`handle_motion` 与 `handle_key` 最前面检查 `g_aui_page_on`，
  转场期间点击不派发、BACK 被吞（返回 1，避免 DOWN/UP 连跳两页）。
  转场不阻塞 build/layout，导航语义（route/depth）立即生效。
- API：`aui_nav_transition(ms)`（0..1000，默认 0 关闭）、`aui_nav_busy()`。
  默认关闭保证 v1.10 应用行为不变；`ui_nav` 在 `app_init` 里开启 240 ms。
- 测试：`nav_transition_test` 用红/绿/蓝整屏页面与一段旧文字，验证起点
  旧页不透明、中点左/右缘与中心的混合方向、终点落到新页、旧页文字在
  文本池被覆盖后仍正确（x≥30 有墨迹）、pop 反向、reset 只淡入、
  关闭后立即直切、2100 条命令时退化为直切。`nav_transition_harness`
  用注入时钟跑真实 `ui_nav`，验证转场中的点击/BACK 被吞与 240 ms 自动结束。
  `nav_test`/`nav_harness` 默认关闭路径不受影响（harness 显式关掉演示转场）。

边界：转场期间新页面不接收输入（短转场可接受；需要交互的页面应把
`aui_nav_transition(0)` 或缩短时长）；没有共享元素、没有手势驱动的
交互式返回、没有按页面区分的转场方向；快照只保存绘制结果，不保存
滚动偏移等状态（回退页面由应用自己的 key 状态决定）。版本升到
versionCode 12 / versionName 1.11.0，`aui_version()` 返回 `11100`，
qemu 测试从 14 项增加到 16 项。

### D.16.1 v1.11.1：真机“切换后卡死”的修复

真机 trace 里 `n2` / `n3` 之后只剩 `T/x/y`，没有任何 `N/L/P/F`：转场把
输入挡住了，但 16 ms 帧回调一次都没来，`page_on` 永远不归零。v1.11.0 的
漏洞是 `page_begin()` 忽略了 `frame_timer_arm()` 的返回值——只要
`ALooper_addFd` / `timerfd_create` / `timerfd_settime` 任何一个失败
（或回调所在的 Java looper 在这台 ROM 上不派发新增 fd），就会停在
半透明中间帧且永久吞输入。

修复分三层，原则是**转场的正确性不能依赖帧源一定工作**：

- `frame_timer_arm()` 现在按阶段返回 `-1` 无 looper、`-2` `timerfd_create`
  失败、`-3` `ALooper_addFd` 失败、`-4` `timerfd_settime` 失败。
  `page_begin()` 拿到负数（且不是假时钟测试模式）就**不进入转场**，
  直接按直切把新页画出来。
- `page_refresh()` 加在 `handle_motion` / `handle_key` / `aui_nav_busy` /
  `onResume`：转场中先按单调时钟推进；只要已到时长，立刻 `page_finish`
  并重画最终页面，然后**照常处理这一次事件**（点击不会被丢）。
  这样即使定时器彻底不回调，最多吞掉 240 ms 内的触摸，之后自动恢复。
- 降级：看门狗收尾时如果“转场开始后 `g_aui_timer_ticks` 一帧都没涨”
  且已超过时长 250 ms，判定该设备帧源不可用，置 `g_aui_timer_dead`，
  此后所有导航直接切页，不再尝试动画。
- `draw_frame` 发现已到点时也走 `page_finish`（原因 3）；`onPause` /
  `onResume` 取消半截转场，避免后台回来后停在中间帧。
- 轨迹新增两个标记：`a`（0 已启动，1..4 定时器失败阶段，5 快照超限，
  6 已降级）、`e`（1 定时器帧，2 输入看门狗，3 绘制路径，4 取消）。
  `nav_watchdog_test` 在“全程不调用 `aui_frame`”的假宿主里验证 busy 到点
  归零、点击/BACK 不丢，以及超过判定窗口后永久直切。

版本升到 versionCode 13 / versionName 1.11.1，`aui_version()` 返回
`11101`，qemu 测试 17 项。

### D.16.2 v1.11.2：trace 自证版本 + 第一次导航也不赌帧源

v1.11.1 的包里 `page_begin()` 每次都会写 `a`，结束时写 `e`。真机复测发回
的 trace 里这两个字母一个都没有，说明手机上跑的仍是 v1.11.0 的旧包——这
一类“到底测的是哪一版”的沟通成本必须消掉，同时把“第一次导航”也兜住：

- `trace_init()` 在 `S` 之后立刻写 `V` + 版本号（`V00002B5E`）。以后
  任何一条 trace 的第二行就能确认库版本，不再依赖安装提示或设置页。
- 帧源自检：`frame_timer_probe()` 在输入队列挂上 looper（`Q` 成功）和
  `onResume` 后各点一次 16 ms 定时器，只要有一次回调，
  `g_aui_timer_ticks` 就从 0 变 1，证明这台设备的 ALooper + timerfd
  真的能驱动帧。
- `page_begin()` 在非假时钟模式下若发现 `g_aui_timer_ticks == 0`，直接
  直切（`a7`），并顺手再点一次自检；下次导航只要自检成功就恢复转场。
  这样帧源不工作的设备**第一下切换就不会停在旧页**，不需要“再点一下
  才动”，视觉上也不再像卡死。
- 自检的回调即使落在空闲时刻也只做 `read` + 停表，不绘制、不改变布局，
  所以启动时不会多出一帧。
- 版本升到 versionCode 14 / versionName 1.11.2，`aui_version()` 返回
  `11102`，qemu 17 项保持全过。

### D.16.3 v1.11.3：帧源自检必须排除“被输入/重绘顺手唤醒”

v1.11.2 的真机 trace（第二行 `V00002B5E`）显示第一次导航仍然 `a0`：
自检只要求“进程内至少有一帧定时器回调”，而启动阶段窗口创建、首帧绘制
本来就会把 looper 叫醒，timerfd 过期后被顺手读到，于是被误判为“帧源
可用”。随后转场开始，空闲时定时器并不能唤醒 looper，屏幕停在旧页，
直到下一次触摸才由看门狗收尾（`e2`），并且这次触摸被派发到新页面的
树（用户看到的是旧页，于是像“点一下跳了两级”）。之后 `g_aui_timer_dead`
生效，所有导航 `a6` 直切，不再卡死但第一下仍然停顿。

修正后的判据（`aui_frame_tick` + `frame_timer_probe`）：

- 自检在首帧重绘回调结束后武装一次 16 ms 定时器；
- 连续两帧回调之间必须**没有输入事件**（`g_aui_input_seq` 不变），也
  **没有别的呈现**（`g_aui_paint_seq` 不变）。任一变化就把计数清零；
- 只有满足条件的第二帧才置 `g_aui_timer_ok = 1`，从此允许转场；
- 未通过自检时 `page_begin()` 直接直切（`a7`），并重新武装自检。

这样“启动时被顺手读到一帧”不再算证明；帧源真的能唤醒空闲 looper 的
设备仍然在首帧后约 32 ms 内通过自检，第一次点击就有动画；不能唤醒的
设备从第一次导航起就是直切，视觉上立即换页。版本升到 versionCode 15 /
versionName 1.11.3，`aui_version()` 返回 `11103`，qemu 17 项保持全过。

### D.17 第十二次迭代（v1.12.0）：自唤醒帧泵

D.16.3 已经把 timerfd 方案推到极限：v1.11.3 的真机 trace
（`V00002B5F`，30 次导航全部 `a7`、零 `e`、零 `a0`）证明自检判定是
准确的，也即**这台设备上 timerfd 永远不会在空闲时唤醒 UI 线程
looper**。两次独立 trace、反汇编核对（timerfd 创建/注册/settime、
`itimerspec` 偏移、fd 注册参数全部正确）之后可以确认这不是库的 bug，
而是该 ROM 的调度行为。继续在 looper 上做自检没有意义，帧源必须换。

**设计**：一个专用的 native 渲染线程（帧泵），完全绕开 UI 线程 looper。

- 启动时 `pipe2(O_NONBLOCK | O_CLOEXEC)` 建一对唤醒管道，帧泵线程对
  读端 `poll(fd, POLLIN, timeout)`。有事件就 drain（最多 16 次
  `read`）；没有事件时靠超时出帧：活跃（fling/动画/转场）或脏
  （need_build/layout/paint）时 16 ms，完全空闲时 250 ms 只做一次
  状态检查，不绘制。
- 每帧调用现有的 `aui_frame(clock_ns())`，由帧泵线程自己完成
  `ANativeWindow_lock` / 绘制 / `unlockAndPost`。所有绘制、输入派发、
  窗口与输入队列生命周期回调都用一把 `pthread_mutex_t`
  （`g_aui_lock`，bionic 40 字节，零初始化的 `i64[8]`）串行化；
  `win_destroyed` 与 `aui_shutdown` 必须先解锁再 `pthread_join`
  停线程，避免自锁。
- UI 线程侧任何“需要帧”的地方（`aui_invalidate`、输入、导航、
  `frame_timer_arm`）只做 `pump_wake()`：向管道写 1 字节，帧泵立刻
  醒。管道写失败或已关闭也不影响节拍——poll 的 16 ms 超时本身就
  保证连续出帧。
- 失败路径：`pipe2` 失败（trace `J1`）或 `pthread_create` 失败
  （`J2`）时置 `g_aui_pump_fail`，此后所有导航 `a7` 直切，与
  v1.11.3 行为一致；成功时 `J0`。

**首帧门**：帧泵只在“活跃或脏”时绘制，所以启动后可能一帧都不画。
`frame_pump_ensure()` 成功后会置 `need_paint = 1` 并 `pump_wake()`，
保证首帧在几毫秒内落地；`page_begin()` 仍保留 `g_aui_pump_frames < 1`
时直切（`a7`）并再次唤醒的门，因此即使首帧意外迟到，第一次点击也
不会停在旧页。转场结束时 trace `Z` + 本次转场实际渲染帧数，用来判断
动画是真的在跑（约 15 帧 @240 ms）还是只出了一两帧。

**观测**：v1.12.0 的 `V00002BC0`、`J0`、导航时 `a0`（进入转场）、
`e0` 与 `Z0000000E` 左右（15 帧）是预期形态；若 `J1/J2` 则说明
线程或管道都没起来，若 `a7` 一直出现则说明首帧门没过。qemu 测试是
单线程假宿主（`pthread_create` 桩返回 -1、假时钟），所以帧泵路径
在这里总是走直切分支，真线程路径由真机 trace 验证。

版本升到 versionCode 16 / versionName 1.12.0，`aui_version()` 返回
`11200`，qemu 17 项保持全过。

### D.17.1 v1.12.1：“帧”必须以 present 成功为准

D.17 的帧计数有一个漏洞：`pump_frame_once()` 无条件把每次
`aui_frame()` 计为一帧，而 `present_now()` 的返回值没有向上传（它只在
窗口锁失败时返回 -1）。如果泵线程拿不到窗口锁（Surface 正在重建、
BufferQueue 异常等），会出现两种坏结果：

- `g_aui_pump_frames` 已经 ≥ 1，`page_begin()` 的首帧门被绕过，转场
  照常进入，但屏幕上没有任何新帧，仍会停在旧页直到 240 ms 到点或输入
  看门狗收尾；
- `g_aui_timer_ticks` 照常增长，`page_note_stall()` 永远判定“帧源正常”，
  永久降级机制失效。

修正：在调用 `aui_frame()` 前后比较 `g_aui_paint_seq`（`present_now()`
成功路径才自增）。只有序列变化的帧才计入 `g_aui_pump_frames` 与
`g_aui_timer_ticks`；没变化的帧不计帧，置 `need_paint` 让下一拍重试。
连续 120 帧（约 2 s）都失败则置 `g_aui_pump_fail`，此后导航一律直切，
同时停止空转。trace 新增：

- `Y1`：首次 present 失败（正常运行不应出现）；
- `Y2`：连续失败达到上限，判定帧泵不可用。

版本升到 versionCode 17 / versionName 1.12.1，`aui_version()` 返回
`11201`（`V00002BC1`），qemu 17 项保持全过。

### D.17.2 v1.12.2：首帧必须无条件出一次

v1.12.1 的真机 trace（`V00002BC1`）给出了决定性证据：`J0`（线程创建
成功）、30 次导航全部 `a7`、0 次 `a0`、0 次 `e`、0 次 `Z`，而且**没有
一次 `Y`**。没有 `Y` 说明泵线程从未尝试 present，而不是 present 失败。

原因在首帧门与“按需绘制”的相互作用：

1. `win_created` 里 `frame_pump_ensure()` 先置 `need_paint = 1` 并唤醒；
2. 同一把锁内紧接着 `aui_invalidate()` 在 UI 线程同步建树、布局、绘制，
   把 `need_build/layout/paint` 全部清 0；
3. 泵线程拿到锁时，既没有动效（active = 0）也没有脏帧（dirty = 0），
   于是直接 `pump_need = 0` 返回，一帧都不画；
4. `g_aui_pump_frames` 永远是 0，`page_begin()` 的首帧门永远返回
   `a7`，转场永远不启动——自洽地卡死在这个循环里。

修正：`pump_frame_once()` 在 `g_aui_pump_frames < 1` 时**无条件**走一次
`aui_frame()`（命令列表已经由 UI 线程准备好，present 一次是安全的），
成功 present 后写 `Y0`，帧数变为 1；此后才恢复 active/dirty 判断。
每次 `frame_pump_ensure()` 新建泵都把帧数与失败计数清零，所以旋转/窗口
重建后同样会先出一次 `Y0`。

版本升到 versionCode 18 / versionName 1.12.2，`aui_version()` 返回
`11202`（`V00002BC2`），qemu 17 项保持全过。

### D.17.3 v1.12.3：转场帧从 100 ms 级降到整页帧级

v1.12.2 的真机 trace（`V00002BC2`）显示泵已经就绪（`J0`）、首帧已经
present（`Y0`），每次导航都进入转场（`a0`），但转场结束全是 `e2 Z1`
（个别 `e1 Z1`、一次 `e3 Z1`）：240 ms 里只出 1~2 帧，动画等于没有。

离线基准（720×1280、假宿主、qemu-user）把原因量化了：
**转场帧 210 ms/帧，普通整页帧只有 13.5 ms/帧**。旧转场路径每帧做三次
全屏逐像素混合：

1. 主题底色全屏填充；
2. 旧页命令列表（含它自己的满屏底色）按 `a_old` 混合；
3. 新页命令列表（含满屏底色）按 `a_new` 混合。

每次混合在 `blend_px` 里是每像素两次乘法 + 三次 `/255`，屏幕越大越亏；
1216×2688 上单帧就是 100 ms 量级，`e3`（绘制路径发现已超时）正是某一帧
自己就跨过了整个 240 ms 的证据。同时输入线程在分发导航事件时持锁同步
`present`，又白画 1~2 帧、和泵抢同一把锁。

两条修复：

**（1）合成快路径。** 转场两页的命令列表开头都是“同色、不透明、无圆角、
满屏”的底色（`aui_root` 页面在无安全区时就是根节点自己，有安全区时
`pump_ui` 还会先补一条满屏底色）。这种情况下两层底色可以先解析地压成
一个颜色：

```
base = C_new(a_new) over [ C_old(a_old) over theme ]
```

整屏只做一次**不透明填充**（`fill_rect` 的 alpha=255 直写路径），然后
旧内容按 `a_old × (255-a_new)/255` 绘制（它位于新底色之下，必须再衰减
一次），新内容按 `a_new` 绘制。页面开头不是单色满屏底时 `fs_bg_run`
返回 0，自动回退旧的三层路径，正确性不受影响。位移最多 20dp，边缘
几十像素的缝用合成色补上，两页底色相同时与旧效果逐字节一致。

**（2）转场期间 UI 线程不再同步绘制。** `aui_invalidate` /
`aui_invalidate_layout` 在“转场中 + 帧泵健康”时只置脏并 `pump_wake()`，
绘制和 present 全部交给泵线程；泵不可用（`pump_fail`）或非转场时保持
原来的同步路径。

基准结果：转场帧 210 ms → 47 ms（-77%），普通整页帧不变（13.5 ms）；
离屏渲染的 start/end 帧与 1.12.2 逐字节一致，中间帧仅混色舍入差
（最大 11/255，0.14% 像素超过 8）。

诊断增强：转场期间泵线程每帧写 `q` + 本帧耗时（毫秒），`present_now`
写 `w` + 窗口锁等待（毫秒）。下一份 trace 里 `q` 应接近普通帧耗时、
`Z` 应从 1~2 升到 10 以上；若 `w` 很大则说明瓶颈在缓冲/合成器而不是绘制。

版本升到 versionCode 19 / versionName 1.12.3，`aui_version()` 返回
`11203`（`V00002BC3`），qemu 17 项保持全过。

---

### D.18 第十三次迭代（v1.13.0）：原生 PNG 解码

v1.13 之前 `aui_image` 只收裸 RGBA，演示图标 48×48 就要在 `.so` 里放
9 KB 的 `icon48.bin`；HuxerUI 的运行时本来就有资源解码这一层。本轮把
README 里挂了很久的「PNG 解码」补上，且继续守「全部原生」：不使用
zlib / libpng / stb_image，inflate 与行解码都写在 Aster 里。

#### D.18.1 范围与取舍

支持：

- 8 位、非隔行；
- 颜色类型 0（灰度）、2（真彩）、3（调色板）、4（灰度 + alpha）、
  6（RGBA）；
- `PLTE`（≤ 256 色）与 `tRNS`（灰度 2 B、真彩 6 B、调色板 ≤ 256 B）；
- 行过滤器 0..4（None / Sub / Up / Average / Paeth）；
- zlib 流里的 stored、fixed-Huffman、dynamic-Huffman 三种 deflate 块；
- IDAT 拆成最多 32 段（跨段读位流）。

不支持的都在解析阶段直接返回 `-2`，不做「尽力猜」：16 位深度、隔行、
未知关键块。`iCCP/gAMA/sRGB` 这类辅助块被跳过（不影响像素），也不做
色彩管理。CRC 不校验（随包资源可信），但每个块长度、调色板索引、距离
与行宽都做边界检查，坏数据返回 `-4`，不会越界读。

#### D.18.2 结构：三段流水线

1. **`png_parse`**：只读文件头与块目录，记录 IHDR 参数、PLTE/tRNS 在
   文件内的偏移、每个 IDAT 的 `(offset, length)`；不复制压缩数据。
2. **`png_inflate`**：校验 zlib 头（CM=8、CINFO≤7、FCHECK%31==0，
   FDICT 拒绝），按块循环。stored 块手动对齐后逐字节取；fixed/dynamic
   共用 puff 式的 `counts + symbols` 规范 Huffman 表（MSB-first 逐位
   累积码字），三个表槽分别是字面量/长度、距离、码长码。
3. **逐行流水**：`png_emit` 每解出一个字节，同时写进 32 KB 回溯环和
   当前行；行满后 `png_unfilter` 原地还原（Paeth 用 i32 中间量，避免
   8 位溢出）、`png_expand_row` 按色型与 `tRNS` 展开成 RGBA 写进目标
   缓冲、`png_row_done` 把当前行拷到 `prev` 供下一行使用。

这样峰值内存与图片高度无关，只有「环 + 当前行 + 上一行」三块固定缓冲，
不需要整幅压缩/解压镜像，也不需要为每张图 malloc。

#### D.18.3 内存上限

| 项 | 容量 | 说明 |
|---|---|---|
| 回溯环 `g_png_ring` | 32 KiB | deflate 最大距离 |
| 当前行 `g_png_row` | 32 KiB | `AUI_PNG_ROW_MAX` |
| 上一行 `g_png_prev` | 32 KiB | Up/Average/Paeth |
| Huffman 表 | ~5 KB | `lens[352]` + `cnt[48]` + `sym[960]` |
| 解码池 `g_png_pool` | 1 MiB | `aui_png_decode_pool` 的 bump 分配 |

行宽上限 32768 B 对应 RGBA 8192 px（调色板/灰度更宽），池上限对应
512×512 RGBA。Aster 的全局数组上限恰好是 1,048,576 个元素，池不能再大；
需要更大的图时用 `aui_png_decode` 自带缓冲。`png_tables_init` 只初始化
长度/距离基表，Huffman 表每个 deflate 块重建，避免跨图残留。

#### D.18.4 期间发现的距离附加位表错误

第一次跑 `png_test` 时 `rgb_filters.png` 返回 `-4`，位置在第一次长度-
距离匹配之后（调试输出显示「距离 6145 超出已输出字节」）。位流本身没有
错位：用 Python 写了一个逐位参考解码器，输出的符号序列与位偏移和 Aster
实现完全一致。差异落在距离基础表上——初始实现把距离附加位写成

```
g_png_dext[i] = i / 2;          // 错
```

但 RFC 1951 3.2.5 规定距离码 0..3 没有附加位，之后每两个码多一位：

```
g_png_dext[i] = 0;
if (i >= 4) { g_png_dext[i] = i / 2 - 1; }
```

错误的表让参考解码器与实现从同一个码读出不同的 distance，接着读错
附加位、后续符号全乱。修正后 `png_test` 一次通过。这个 bug 也说明
「先做位级参考实现、再对拍」比在实现里加日志更省时间：参考实现能
明确区分「位流错位」和「查表错」两类问题。

#### D.18.5 测试

`tools/gen_png_fixtures.py` 是确定性生成器（固定数据、固定 zlib 级别），
产出 12 个 PNG 与 1 个非 PNG。生成后还会读回 IDAT 的第一个 deflate
字节，断言 BTYPE 分别是 0/1/2，防止「以为覆盖了三种块，其实全是
dynamic」。`tests/png_test.ast` 覆盖：

- RGBA 4×3：逐像素核对 `r/g/b/a` 公式，dims 正确；cap=47 返回 `-3`
  且 dims 清 0。
- 真彩 9×5：五种过滤器各一行（BTYPE=fixed），验证 Sub/Up/Average/Paeth。
- 灰度 + tRNS 6×4：透明样本 alpha=0，其余 alpha=255。
- 调色板 + tRNS 6×4：索引取色、每索引 alpha。
- 一条 PNG 拆成 3 个 IDAT（第一段只有 1 字节）：跨段位流。
- 64×48 RGBA（dynamic Huffman）、3×2（fixed）、4×3（stored）。
- `examples/assets/icon48.png` 解码结果与 `icon48.bin` 逐字节相同，
  证明演示图标换 PNG 后视觉不变。
- 拒绝路径：16 位 `-2`、隔行 `-2`、2048×2048 超行缓冲 `-3`、截断
  `-4`、非 PNG `-1`、过滤器 9 `-4`。
- 池：复位后首次分配地址稳定、第二次解码地址不同、复位后可复用；
  2048×2048 放不进 1 MiB 池，返回 0。

`ui_hello` 改为 `app_init` 里 `aui_png_decode_pool` 解
`assets/icon48.png`，失败回退到原来的裸 RGBA，因此旧资源仍是兜底。
`png_test` 加入 `run_qemu.sh` 与 `build.sh`，qemu 18 项全过。

版本升到 versionCode 20 / versionName 1.13.0，`aui_version()` 返回
`11300`（`V00002C24`）。

---

### D.19 第十四次迭代（v1.14.0）：Android 15 edge-to-edge 安全区

v1.13.0 的真机 trace 和截图给出一对新事实：

```
i0 j0 o1216 p2688      ← 内容区等于整窗（1216×2688）
V00002C24
```

截图里标题和图标直接压在状态栏下面。v1.9 的布局逻辑本身没错：它把根节点
排进 `onContentRectChanged` 给出的矩形；错在这个矩形在 Android 15 上已经
不再扣系统栏。

#### D.19.1 根因：API 35 强制 edge-to-edge，而 NDK 没有 WindowInsets

targetSdk 35 的应用在 Android 15 上被系统强制 edge-to-edge：窗口铺满屏幕，
`onContentRectChanged` 给的就是整窗；状态栏/导航栏变成透明浮层，应用自己
负责避让。标准做法是 `WindowInsetsController` / `View.setOnApplyWindowInsetsListener`，
但这两者都在 Java/Kotlin 框架层。NDK 这边：

- 没有 `AWindowInsets` 或 `ANativeWindow_getInsets` 之类的 API；
- `AConfiguration` 只有 density/uiMode/screenSize 等，没有系统栏尺寸；
- `ANativeWindow_getWidth/Height` 与内容区回调都只给整窗；
- `native_app_glue` 也不解决这个问题（它同样拿整窗）。

项目硬约束是不使用 dex / Java / Kotlin，JNI 调 `WindowInsets` 也被排除。
因此只能做**保守估算 + 应用覆盖**，而不是假装能精确查询。

#### D.19.2 方案：24 dp 估算、应用下限、显式铺满

`calc_insets()` 的优先级（每项取较大者，最终夹在窗口内）：

1. **系统内容区**：`onContentRectChanged` 给出非整窗矩形时，直接用
   `left/top/right/bottom` 换算 Q16.16 内缩。v1.9 的行为完全保留。
2. **API 35 估算**：`sdkVersion >= 35`、内容区等于整窗、且
   `g_aui_e2e == 0` 时，上下各留 24 dp。24 dp 是 Material 对状态栏/
   手势条的常见高度，也是 Android 各版本 `status_bar_height` 的常见值；
   横屏、刘海、三键导航会偏，但至少不再把标题画进状态栏。
3. **应用下限**：`aui_set_insets(l,t,r,b)` 指定四边最小 dp，与上面两项
   取较大者。用于刘海/挖孔/三键导航或 ROM 差异；应用不需要知道系统栏
   真实高度，只需给出自己内容不能进入的区域。
4. **显式铺满**：`aui_edge_to_edge(1)` 把估算关掉（`g_aui_e2e = 1`），
   内容回到整窗；应用仍可用 `aui_set_insets` 自己留边。`(0)` 恢复估算。

内缩之和超过窗口宽/高时整体归零，避免内容区变成负数（例如极端分屏 +
应用给了过大的下限）。

计算时机有两处：`pump_ui` 在 build 前算一次（应用在 build 里调用
`aui_safe_*` 拿到的是本帧值，而不是上一帧），布局前再算一次（内容区/
窗口尺寸可能在 build 期间变化）。结果缓存在 `g_aui_inset_*`，绘制与
命中仍沿用 v1.9 的「先铺全屏底色，再画内容区」路径，因此系统栏区域
保持主题底色，不会露出上一帧。

#### D.19.3 观测：`O` 与 `E`

- attach 读取 `ANativeActivity.sdkVersion`（偏移 48，i32）并写
  `O` + 低 16 位。真机 Android 15 应看到 `O00000023`（35）。
- 估算状态变化时写一条 `E` + 打包值：高 16 位 = 上内缩像素，低 16 位 =
  下内缩像素。例如 density 3.25 时 24 dp = 78 px，得到
  `E004E004E`；`E00000000` 表示估算关闭（API < 35、显式铺满或内容区
  不是整窗）。

这两个标记让「包对不对」「估算有没有生效」「实际留了多少像素」在
没有 adb 的情况下也能从 `trace.txt` 判断。

#### D.19.4 测试

`system_test` 在原有内容区/深色用例后追加：

- 模拟 `sdk=35` + 整窗（720×1280、density 420，24 dp = 63 px）：
  `aui_safe_top/bottom = 24`，根节点 `(0,63,720,1154)`，多出的一条
  全屏底色命令仍在，节点数与命令数按预期 +1。
- `aui_edge_to_edge(1)`：内缩归零，根节点回到 `(0,0,720,1280)`。
- `aui_set_insets(0,40,0,0)`：`safe_top=40`、`safe_bottom=0`，根节点
  `(0,105,720,1175)`（上 40 dp = 105 px，下 0）。
- `aui_edge_to_edge(0)`：恢复估算后取较大值，`safe_top=40`、
  `safe_bottom=24`，根节点 `(0,105,720,1112)`。
- `aui_set_insets(0,0,0,0)`：回到 24/24 与 `(0,63,720,1154)`。

离屏渲染 `hello_render` 也注入 `sdk=35` + 整窗，重新导出 720×1280 帧：
标题与图标整体下移 48 px（density 2），底部留出 48 px，目视确认不再
压住状态栏。`ui_hello` / `ui_nav` 的版本文案同步改为 v1.14。

#### D.19.5 边界

24 dp 只是经验值，不能替代真正的 WindowInsets。以下情况需要应用用
`aui_set_insets` 补偿：刘海/挖孔屏（尤其横屏）、三键导航（导航栏通常
48 dp）、平板/折叠屏分屏、某些 ROM 的加高状态栏。库不做「读系统属性/
解析 framework-res」这类脆弱的 hack：它们同样拿不到每窗口的 insets，
还会引入 ROM 兼容问题。真正的精确方案需要 JNI 或 `AWindowInsets` 的
NDK 暴露，在本项目约束下不可用。

版本升到 versionCode 21 / versionName 1.14.0，`aui_version()` 返回
`11400`（`V00002C88`），qemu 18 项全过。

## D.20 v1.15.0：系统栏条带

#### D.20.1 问题：浅色图标压在浅色背景上

v1.14 的真机 trace（`V00002C88`、`O00000024`、`E004E004E`）证明 24 dp
估算生效：内容整体避开了状态栏。但截图暴露出下一层问题——系统栏的
时间、电量、导航条图标是**浅色**（白色），而应用的默认背景是
`0xFFF6F6F8`，两者对比度极低，状态栏信息几乎不可读。

图标的明暗由系统按 `windowLightStatusBar` / `windowLightNavigationBar`
这两个 **主题属性**决定。本项目的 APK 由 `build-apk` 生成最小
`resources.arsc`，没有主题 XML，改不了这两个属性；NDK 也没有对应的
运行时接口，JNI 又被硬约束排除。也就是说：**在不用 Java 的前提下，
库无法把图标改成深色**。

#### D.20.2 方案：深色条带垫在浅色图标下面

既然改不了前景，就改背景。v1.15 在有安全区时按以下顺序绘制：

1. **全屏系统栏色**：先铺一条覆盖整窗的 `AUI_COLOR_SYSTEM_BAR`
   （浅色主题 `0xFF1B1B1F`，深色主题 `0xFF050507`）。这条命令盖住
   v1.14 的全屏底色，作用相同（防止露出上一帧），同时给系统栏图标
   提供深色衬底。
2. **内容区主题底色**：再在内容矩形内铺 `AUI_COLOR_BG`。浅色主题下
   就是原来的 `0xFFF6F6F8`，应用的自绘区域观感不变。
3. 根节点照常在内容区里绘制。

于是状态栏区域是深色 + 浅色图标，内容区仍是原来的浅色主题；导航栏
同理。整条路径只多出一条矩形命令（有内容区时共 +2，原有全屏底色
命令被条带替代），不参与布局和命中，`i j o p` 与节点数都不变。

#### D.20.3 API

- 新主题角色 `AUI_COLOR_SYSTEM_BAR`（11）：浅色 `0xFF1B1B1F`，
  深色 `0xFF050507`。公共角色从 11 个（0..10）扩到 12 个（0..11）。
- `aui_set_system_bar(color: u32) -> i32`：覆盖条带色，`0` 表示跟随
  主题角色（默认）。传 `aui_theme_color(AUI_COLOR_BG)` 可让条带与
  内容同色，等于**关掉条带**，回到 v1.14 的观感——适合系统栏图标本来
  就是深色的 ROM 或深色背景的应用。
- `aui_system_bar_color() -> u32`：返回当前生效色，便于应用在自绘的
  自定义标题栏里与条带对齐。

覆盖值只在 `sdkVersion >= 35` 且存在安全区时参与绘制；API < 35 或
`aui_edge_to_edge(1)` 时整窗仍只铺主题底色，与 v1.14 完全一致。

#### D.20.4 测试

`system_test` 追加：

- 深色主题下 `AUI_COLOR_SYSTEM_BAR = 0xFF050507`。
- `sdk=35` + 整窗 + density 420：命令数从 `n0` 变为 `n0 + 2`；像素
  `(0,0)` 与 `(719,0)` 为 `1B 1B 1F`，内容区首行 `(360,63)` 为
  `F6 F6 F8`——条带与内容分界正确。
- 覆盖 API：`aui_set_system_bar(0xFF3A6DF0)` 后 `(0,0)` 变为
  `3A 6D F0`；传 `0` 后恢复 `1B 1B 1F`；`aui_system_bar_color()`
  与绘制结果一致。
- 三种内缩来源（估算、应用下限、两者取较大）都断言命令数为 `n0 + 2`。

离屏 `hello_render` 注入 `sdk=35` + 整窗重新导出 720×1280：顶部
0–62 px、底部 1217–1279 px 为 `#1B1B1F`，内容底色从 y=63 开始，
目视确认浅色图标落在深色上。

#### D.20.5 边界

条带只解决「图标与背景」的对比度，**不控制图标本身的明暗**：ROM 若
强制深色图标，深色条带反而会降低对比度，此时应用应调用
`aui_set_system_bar(aui_theme_color(AUI_COLOR_BG))` 关掉条带。条带
高度完全跟随安全区估算（见 D.19.5），刘海/挖孔/三键导航下的外观仍
需要应用用 `aui_set_insets` 修正。真正按系统栏明暗自动取反需要读取
主题属性，仍要 JNI，超出本项目约束。

版本升到 versionCode 22 / versionName 1.15.0，`aui_version()` 返回
`11500`（`V00002CEC`），qemu 18 项全过。

## D.21 v1.16.0：CJK 回退字体

#### D.21.1 问题：库里只有 8x8 拉丁字形

v1.15 的界面全是英文：不是不想写中文，而是 `font_latin.auf` 只有
ASCII 32..126 的 8x8 字形。`utf8_next` 已经能解 1–4 字节，但缺字时
`glyph_advance` 只按 8 px 留空、`draw_text_run` 直接跳过，所以中文
标签会变成一串等宽空白。

设计 §8.5 已经预留了「16x16 1bpp 子集」方案：中文常用 3500 字约
112 KiB，运行时不解析 TTF。v1.16 把它做出来，但没有改拉丁字体——
8x8 拉丁在 density 2 下放大 2 倍正好 16 px，换成 16x16 会牵动所有
已有布局和测试；更小的改动是**保留主字体，增加回退字体**。

#### D.21.2 字体格式与生成

AUF1 头 32 字节：magic、version、flags、glyph_count、pixel_size、
line_height、baseline、table_off、bitmap_off、bitmap_size。字形记录
仍是 16 字节：codepoint(i32)、advance、w、h、xoff、yoff、flags、
reserved、bitmap_off。v1.16 首次使用 `w/h > 8` 的字形：

- 1–8 px 宽：每行 1 字节，MSB 是左起第一像素；
- 9–16 px 宽：每行 2 字节，小端 16 位读出，bit15 是左起第一像素。

`tools/gen_cjk_auf.py` 用 Pillow 从 Noto Sans CJK SC（TTC face 2）
按 16 px 渲染，阈值 100 二值化，居中到 16×16 cell。字符集是 GB2312
一级 + 二级共 6763 个汉字，加 CJK 标点 U+3000–303F、全角
U+FF01–FF5E、常用符号，去重后 6931 个字形；每个字形 32 字节，
连同 16 字节表项共 325 KB。生成结果直接进仓库，构建期不需要 Pillow
或字体文件；许可证是 OFL，随包放 `font_cjk.LICENSE.txt`。

#### D.21.3 运行时：两套字体、两套缩放

新增全局 `g_aui_font2` / `g_aui_text_scale2` 和 API
`aui_set_fallback_font(font, scale)`（`font=0` 关闭）。查询顺序：

1. 在 `g_aui_font` 里二分查找码点；命中就用主字体的 scale。
2. 否则在 `g_aui_font2` 里查；命中就用回退字体的 scale。
3. 都没有：按 `8 × 主 scale` 留空，和 v1.15 的行为一致。

`glyph_advance`、`text_measure` 都走这个顺序，所以宽度与换行正确；
`draw_text_run` 逐码点选择字体，`draw_glyph` 改为接收字体指针、字形
偏移和缩放，按 `w` 算每行字节数。行高
`text_line_h = max(主 line_h×scale, 回退 line_h×scale2)`，字形高度
`text_glyph_h` 同理：拉丁 8x8×2 = 20 px 行高，CJK 16x16×1 = 18 px，
最终 20 px，汉字在 20 px 行里垂直居中，不会把行撑高。

选择「各自缩放」而不是统一缩放，是因为两套字体的设计尺寸不同：
density 2 下 8x8 拉丁要放大 2 倍才和 16x16 汉字同高；如果统一用
scale=1，拉丁只有 8 px，中文 16 px，视觉上完全失衡。API 让应用显式
给出两个 scale，文档推荐 2/1。

#### D.21.4 UTF-8 编辑

`aui_text_append(key, ch)` 原先只写 `ch & 255`，对中文会把码点截断。
v1.16 改为按码点写 1–4 字节 UTF-8，并在写入前检查 63 字节上限；
`aui_text_backspace` 从尾部跳过 `10xxxxxx` 续字节，删掉整个码点。
`text_fit_start`（字段内容超宽时丢掉左侧）也改为按完整码点前进，
避免从汉字中间截断后画出 U+FFFD。

系统 IME 仍未接：键盘还是库内 ASCII QWERTY，中文目前用于标签、按钮
和 `aui_text_set/append` 的程序内写入。要做拼音/候选词需要
`AInputConnection` 或 JNI，超出本项目约束。

#### D.21.5 测试与边界

`cjk_test`（离屏 720×1280）注入拉丁 + CJK 两套字体：

- `中文` 宽 32 px、`A中` 宽 32 px、`中文界面` 宽 64 px、行高 20 px；
- 汉字区域墨迹数 ≥ 30；关闭回退后宽度不变、墨迹为 0；
- `U+4E2D U+6587` 追加后长度 6，字节为 `E4 B8 AD E6 96 87`；
  两次退格回到 0；
- 恢复回退后再次出墨。

`ui_hello` 的副标题改为 `v1.16 中文界面`、计数标题 `计数`、重置按钮
`重置`，真机截图可以直接看混排效果。

边界：只覆盖 GB2312，生僻字/繁体/emoji 显示空白；16x16 1bpp 在
density 3.25 的屏幕上是否清晰要以真机为准；325 KB 字体常驻
`.rodata`，APK 从 272 KB 涨到约 616 KB；没有复杂文本整形、字距调整、
粗体/斜体，也没有系统字体回退。

版本升到 versionCode 23 / versionName 1.16.0，`aui_version()` 返回
`11600`（`V00002D50`），qemu 19 项全过。

---

## D.22 v1.17.0：开关与进度条

设计 §5 的 M4 清单里，switch / slider / dialog 一直标着“以后”。v1.17
先做最常用的两个只读/简单交互控件：开关与进度条。两者都用现有节点池、
布局和光栅器，没有引入新绘制原语——圆角矩形就是命令类型 1 加 radius。

#### D.22.1 节点与 API

新增节点类型 12（switch）和 13（progress），都是叶子：

```aster
extern fn aui_switch(key: i32, on: i32, cb: fn(ptr) -> i32, user: ptr) -> i32;
extern fn aui_progress(key: i32, value: i32) -> i32;   // 千分比 0..1000
```

状态归属是这一版最重要的取舍：**库不保存开关状态和进度值**。`on` 与
`value` 每帧由应用在 build 里传入，存在节点的 `aux` 字段（switch 0/1，
progress 0..1000，构造时夹紧）。这样应用可以直接把业务字段映射进来，
不需要像文本字段那样再维护一份库内状态；点开关只调用 `cb(user)`，应用
翻转自己的字段后 `aui_invalidate()` 即可。代价是开关不能在按下瞬间自己
变灰/变色——按下态仍由库的 `g_aui_pressing` / `g_aui_press_key` 提供，
但最终开/关值要等下一次 build。

#### D.22.2 布局与绘制

- switch：`measure_switch` 固定 44×24 dp（`n.w/n.h`），不参与 weight。
  绘制两条圆角矩形：轨道铺满 44×24、半径 12 dp；滑块直径
  `h - 2×3dp = 18 dp`，半径 9 dp，关时靠左、开时靠右，内缩 3 dp。
  轨道色：开 `AUI_COLOR_PRIMARY`，关 `AUI_COLOR_SCROLLBAR`；按下时开
  用 `PRIMARY_DARK`、关用 `HINT`；滑块统一 `AUI_COLOR_SURFACE`。
- progress：`measure_progress` 高度固定 8 dp，宽度取父容器给的
  `avail`（column 里就是内容宽，row 里应给 `weight(1)`），没有 avail
  时退回 200 dp。绘制轨道（`SCROLLBAR`，半径 4 dp）+ 已完成段
  （`PRIMARY`，同半径）。`value=0` 只画轨道。

圆角半径直接传 `n.h/2`，光栅器的圆角矩形本来就是按像素扫描的，
所以胶囊和进度条不需要新的 SDF/路径。

#### D.22.3 一个必须记下来的溢出

第一版填充宽度写成 `fw = n.w * v / 1000`。`n.w` 是 Q16.16：288 px
是 `288 << 16 = 18,874,368`，乘以 500 已经 9.4e9，超出 i32；实际得到
的是负数/截断值，65% 的进度条只画了 12 px。`controls_test` 首先在
“左侧应为 PRIMARY”的像素断言上失败，随后用临时 `aui_debug_cmd_info`
打印命令表确认填充宽度确实是 12。修复是先把两个操作数转成 `i64`：

```aster
let fw: i32 = i32((i64(n.w) * i64(v)) / 1000);
```

非零值再夹到 `[n.h, n.w]`：至少保留一个圆角直径，避免 1% 时看起来像
空条；最大值不超过轨道宽。这个坑对后续 slider 同样成立——凡是
Q16.16 长度乘大于 1 的系数，都要用 64 位中间量。

#### D.22.4 命中与测试

switch 走普通 `hit_test`，整个 44×24 区域可点，抬起时调 `cb(user)`；
progress 不接收点击。`controls_test`（离屏 320×240，density 1）断言：

- 树 6 节点 / 6 命令：switch 开 + 关各 2 条，progress 2 条；
- switch 矩形 44×24；开轨道 `0xFF3A6DF0`、滑块 `0xFFFFFFFF`；
- 点 switch 中心回调一次、应用状态翻转，点旁边 label 不触发；
- 关轨道 `0xFFAEB8CC`；
- progress 矩形 288×8；value=500 时左半 `PRIMARY`、右半 `SCROLLBAR`；
- value=2000 夹到 1000（最右像素也是 PRIMARY），value=-50 夹到 0
  （整条都是轨道色）。

`ui_hello` 追加一张设置卡片：`提醒` 行（label + 状态文字 + switch）和
`进度` 行（label + `65%` + progress 650）。设备上的期望轨迹是
`N00000018`（24 节点）/ `P00000018`（24 命令）；qemu 假宿主没有安全区，
少了系统栏条带与内容区底色两条命令，所以 `android_harness` 里是
`P00000016`。数字不同不是 bug，看 `E` 是否存在即可区分。

版本升到 versionCode 24 / versionName 1.17.0，`aui_version()` 返回
`11700`（`V00002DB4`），qemu 20 项全过。

---

## D.23 v1.18.0：24px 比例字体与按词换行

### D.23.1 出发点：真机字体偏小

v1.17 真机截图确认开关/进度条后，用户直接反馈“字体感觉有点小，看着不太
舒服”。旧方案是 8×8 位图拉丁字体放大 2 倍（16 px）加 16×16 汉字，在
density 3.25 下只有约 5 dp，远小于系统正文 16 sp。单纯把 8×8 放大到
4 倍会得到 32 px，但笔画只有 1 像素粗、字形发虚，而且所有字符仍然等宽，
所以这一版改为**更大的源字体 + 比例步进**：

- `font_latin24.auf`：从 Noto Sans CJK 的拉丁部分逐字渲染 24 px，记录
  真实 `advance` 与 `xoff/yoff`，95 个 ASCII 字形，4.4 KB；按 2 倍绘制
  => 48 px，density 3.25 下约 15 dp，接近系统正文。
- `font_cjk24.auf`：24×24 1bpp 图集，6932 个字形，610 KB；同样按 2 倍
  绘制 => 48 px。行高 30 逻辑 px（生成器默认 6 px 额外行距），×2 后
  60 px，正文不再挤在一起。
- 旧 `font_latin.auf` / `font_cjk.auf` 原样保留，`cjk_test` 等回归测试
  继续校验旧路径，也保证第三方示例不因升级而消失。

### D.23.2 AUF 位图行：17–24 px 需要 3 字节

AUF 的字形行按 `bit_width = 8 × ceil(size / 8)` 存小端位串：

| 像素高 | 每行字节 | 读取方式 |
| --- | --- | --- |
| 1–8 | 1 | `load_u8` |
| 9–16 | 2 | `load_u16` |
| 17–24 | 3 | `load_u16` + 最高字节 `<< 16` |

`draw_glyph` 原来只处理 1/2 字节，24px 汉字只会画出左侧 16 px。
（v1.19 起改为按 `ceil(w/8)` 逐字节读取，见 D.24.2。）
`font24_test` 用单个“中”字专门验证：字形左半（x..x+24）和右半
（x+24..x+48）都必须有墨迹，否则返回 7。

### D.23.3 一个定位偏移 bug

字形记录是 16 字节：

```
codepoint i32 | advance u8 | w u8 | h u8 | xoff i8 | yoff i8 | flags u8 | ... | bitmap_off i32
偏移             +4           +5     +6     +7         +8         +9
```

第一版 `draw_glyph` 把 xoff/yoff 读成 `+8/+9`，恰好是 yoff 和 flags；
比例字体每个字母的 xoff 被丢弃、yoff 被当成 xoff，预览里出现
“A ?te?UI”这种整体错位。改为 `+7/+8` 并做 i8 符号扩展后，字形位置
完全正确。等宽 8×8 字体 xoff/yoff 恒为 0，所以这个 bug 在 v1.17 之前
从未暴露——**只有引入比例字体才会踩到**。

### D.23.4 按词换行：测量与绘制必须共用一份结果

24px 下长标签更早触顶，原来的逐字符换行会把 “the stack” 切成
“t / he stack”，按钮文字“Open page 3 directly”甚至被截断。改为：

- `layout_text(s, tlen, maxw)` 一次算出所有行的 `(start, len, width)`，
  缓存在 `g_aui_line_start/len/w`（上限 64 行），同时设置
  `g_aui_mlines` / `g_aui_mwidth`；
- 折行优先落在最近的空格，空格本身不进入行尾；只有单词本身宽过整行
  时才退化为按字符切；
- `text_measure()` 直接返回 `layout_text()` 的宽度，`emit_text_lines()`
  直接复用同一份行缓存。这一点是硬约束：如果测量和绘制各自换行，
  节点宽度会按 A 算、实际按 B 画，长文本必然溢出或提前截断。

单行文本、显式 `\n`、纯 CJK（无空格）走的是和以前相同的断点，
所以 `cjk_test` / `text_test` 的宽度断言不变。

### D.23.5 ui_form：滚动区把键盘留在屏幕内

字体变大后，`ui_form` 整页 + 键盘在 720×1280 上超出屏幕，DONE 键中心
落在 y=1287。布局改为：

```
column(1, weight=1, pad=24, gap=12)
  scroll(11, weight=1, gap=12)
    label / label / text_field / "Live value" / surface-row
  row(7)                       <- Clear / Focus 固定在滚动区外
  if focused: keyboard(10)
```

这里有两个必须同时满足的条件：

1. 顶层列必须 `weight(1)`。根节点的 arrange 只按子节点测量高度分配，
   顶层列若没有 weight，测量结果只有内边距（因为唯一的在流子节点是
   weight 的滚动区），滚动视口高度会是 0，`hit_test` 在列边界就被
   挡掉，点字段没有任何反应（`form_harness` 返回 22）。
2. Clear/Focus 必须放在滚动区外。键盘弹出后滚动视口变小，按钮留在
   滚动内容里会落到视口下方，`tap_key` 的命中测试失败（返回 28）。

### D.23.6 测试与版本

- `font24_test`（离屏 720×1280）：A 宽 20..40、行高 60；“中文”96；
  `A中` = A + 48（比例步进 + 一个 48 px 汉字）；“中文界面”192；
  汉字墨迹与 3 字节行右半墨迹。返回码 0..8。
- `list_harness` 不再写死“拖 300 px”，改为按 scroll 与按钮的实际矩形
  计算拖动距离（24px 字体让列表高了约一倍），再点按钮。
- `ui_form` 的布局变化由原有 `form_harness` 全流程覆盖（点字段 →
  键盘 → 输入 → BACK → Done → Focus → Clear）。
- qemu 21 项全过。

版本升到 versionCode 25 / versionName 1.18.0，`aui_version()` 返回
`11800`（`V00002E18`）。`ui_hello` 仍是 24 节点 / 24 命令；设备上
`N00000018` / `P00000018` 的期望不变。

### D.23.7 键盘特殊键：文字放不下就画图标

48 px 字体下，`paint_key` 里的文字标签宽度是：SHIFT 130 px、DEL 88 px、
DONE 132 px、SPACE 146 px。720×1280 的假宿主 density 是 2.625
（274 dp 宽），键盘一行 10 键时每键约 60 px，`DEL` 压到左边的 `l` 上，
`SHIFT` 也几乎顶满两格宽的键；设备 1080 宽 / density 3.25 时每键
93.7 px，`DEL` 左右各只剩约 3 px。把标签缩到 1 倍（24 px）能放下，
但在设备上只有 7.4 dp，太碎。

最后只替换 SHIFT / DEL 两个“不像词、更像符号”的键：

- 图标尺寸取 `键高 / 3`，随 density 与键高走；`paint_kb_tri` 生成
  上箭头（逐行收窄的实心三角 + 竖柄），`paint_kb_del` 生成退格五边形
  （左侧尖角 + 右侧矩形），中间的 `×` 用按键底色画，按下时底色换成
  主色，`×` 自动跟随；shift 打开时箭头用 `PRIMARY` 提示大写。
- 两个 helper 都按整数像素循环，最后用 `fx()` 转回 Q16.16 命令；
  每帧多约 60 条填充命令，键盘其余键仍是普通文字。
- 底部的 `123` / `ABC` / `SPACE` / `DONE` 保持 48 px：按键本身有
  weight 2/4/2，设备上最窄的 DONE 也有 256 px，不会溢出。

验证：720×1280 / density 2.625 与 1080×970 / density 3.25 两档离屏
渲染下，SHIFT 箭头约 25×32 px、DEL 约 48×32 px（设备档 36×45 /
67×45），四行键宽一致、无重叠；21 项 qemu 测试（含 text_test 点
SHIFT / DEL / DONE）全过。

**截图通道顺序。** 交付用的 PNG 一直由原始帧缓冲转换。缓冲是 RGBA：
`nav_transition_test` 的 `is_rgb` 直接断言字节 0/1/2 = R/G/B。旧转换
脚本却按 BGRA 读，导致所有交付截图里主色 `0xFF3A6DF0` 显示成橙色
`0xFFF06D3A`，图标 `0xFF283593` 显示成棕红。v1.18 的截图改用
`Image.frombytes("RGBA")` 直接转换，颜色与设备一致；库和 APK 无需改动。

边界：开关没有动画（滑块瞬移）、没有禁用态；进度条只有确定态，没有
indeterminate 转圈；不支持垂直方向、分段进度或自定义粗细；slider、
单选/复选框、对话框仍未实现。

---

## D.24 v1.19.0：原生 48px 图集与逐字节行读取

### D.24.1 发虚的根因是 2 倍放大，不是字号

v1.18 把 24px 1bpp 图集按 2 倍画成 48 px。位图放大是复制像素：
每个笔画台阶、每个拐角都是 2×2 的方块，CJK 的细横（1 px）放大后
变成 2 px，遇到非整数对齐还会断成虚线，所以用户看到“字大了，但发虚”。
提高对比度或换颜色都不能解决，必须让字形在源尺寸就有 48 px 的细节。

方案比较：

| 方案 | 细节 | 体积 | 取舍 |
|---|---|---|---|
| 24px × 2（v1.18） | 2 px 台阶 | 610 KB CJK | 已证明发虚 |
| 32px × 1.5 | 1–2 px 混合台阶 | ~1.0 MB | 缩放仍有非整数台阶 |
| 48px × 1（v1.19） | 1 px 台阶 | 2.0 MB CJK | 体积换清晰度 |

选 48px × 1：字形高度仍是 48 px，行高 60，布局与 v1.18 基本一致；
只是把“放大”从运行时移到生成时。两套图集：`font_latin48.auf`
（95 字形，11,342 字节，baseline 46）与 `font_cjk48.auf`
（6932 字形，48×48 全格，2,107,360 字节，baseline 47）。uihello.apk
因此从 895,646 增大到 2,386,590 字节；其余示例只带拉丁 48px，体积
基本不变。

### D.24.2 行读取：48 px 一行 6 字节，超过 i32 移位

AUF 的一行是 `ceil(w/8)` 字节的小端整数，最左像素在最高位。旧实现
把整行装进 i32 再移位，最多只能处理 3 字节（24 px）；48px 汉字一行
6 字节，`W` 一行 5 字节，必须换写法。`draw_glyph` 现在逐字节装载：
每个字节覆盖 8 个像素，字节下标是 `rb-1-(xx>>3)`（小端行字的最左
像素在行尾字节），一行 6 次装载。1 倍绘制时内层缩放循环退化为单次
赋值，额外开销可以忽略。

第一版逐字节实现按大端索引（`rowp + (xx>>3)`）取字节，结果所有
文字被读成竖直条带——每个像素行取到的是别的列。`font48_test` 为此
加了三条与字节序强相关的断言：

- “L” 左侧 10 px 必须有竖笔墨迹；
- “L” 右上角 12×24 区域必须没有墨迹（字节序反了竖笔会跑到右边）；
- “W” 最右 12 px 必须有墨迹（5 字节行没读全时右端是空白）。

### D.24.3 基线对齐

24px 时代拉丁 baseline 19、汉字 23，按 2 倍后汉字墨迹比拉丁低 6 px；
v1.18 的截图上“v1.18 中文界面”里汉字的底边明显低于数字。48px 图集
的基线由生成器参数决定：`gen_latin_auf.py` 新增可选的 baseline 参数，
latin48 用 46（cell 60 内 `|` 不溢出），cjk48 是 47，混排落差约 1 px。
再加大会让 `|`（54 px 高）超出单元格，所以取 46 是 1bpp 全格字体下
的折中。

### D.24.4 验证

- `font48_test`：A 宽 29、行高 60、“中文”96、“A中”77、“中文界面”192；
  “中”右半有墨；L/W 字节序断言。返回码 0..11。
- qemu 22 项全部 exit=0（font24_test 继续覆盖 24px × 2 与 3 字节行）。
- 离屏对比：同一 ui_hello 界面分别用 24×2 与 48×1 渲染，720×1280
  density 2.625 与 1080×970 density 3.25 两档；48×1 的笔画台阶为
  1 px，“AsterUI / v1.19 中文界面 / 计数 / 重置 / 65%”边缘明显更实，
  汉字细横不再断线。布局位置与 v1.18 一致，行高多 8 px 由卡片间距
  吸收。
- 截图仍按 RGBA 通道导出（见 D.23.7 的通道顺序说明）。

边界：1bpp 没有灰度抗锯齿，斜线和圆弧仍是硬台阶，只是台阶从 2 px
降到 1 px；更高的清晰度需要灰度图集（体积 ×8）或运行时抗锯齿，留作
后续选项。CJK 图集仍只覆盖 GB2312。

---

## D.25 v1.20.0：复选 / 单选 / 滑块

### D.25.1 对照 HuxerUI 的 toggle.cpp / slider.cpp

HuxerUI 的 `toggle.cpp` 把 checkbox 与 radio 放在一起：同一套 20 dp
盒子、同一套状态层，区别只在“方框 + 对勾”还是“圆环 + 圆点”；
`slider.cpp` 是 32 dp 高的水平条，4 dp 轨道、9 dp 内缩、16 dp 拇指
（按下 18 dp），拖动中被完全接管。AsterUI 照这个拆分实现三个节点
类型 14 / 15 / 16，而不是像开关那样一个函数两种形态——因为复选框
带标签、需要参与行高，滑块需要手势，三者的测量、绘制、命中差异
都比“开关的开与关”大。

状态模型沿用 v1.17 的开关：库不存应用状态，构造时传入当前值，
回调里由应用翻转并 `aui_invalidate()`。差别是多了一个 `aux2`：

```
aux   ：复选框/单选钮 = 标签长度（-1 = NUL 结尾）；滑块 = 初值（千分比）
aux2  ：复选框/单选钮 = 0/1 勾选态；滑块 = 吸附步长（千分比，>= 1）
```

`AuiNode` 仍是 96 B：v1.19 的 17 个 i32 后面本来就有 4 B 对齐填充，
`aux2` 正好占用它，结构体尺寸与 `node_at(i)` 的步长不变（头注释已
改成 18 个 i32 + 3 个 8 字节字段）。快照与拷贝全部走 `node_at()`，
没有裸偏移需要跟着改。

### D.25.2 测量：纵向铺满、横向保持固有宽度

复选框的固有宽度是 `pad*2 + 20dp + 8dp + 文字宽`，行高是
`max(20dp, 文字行高) + pad*2`。但如果只有固有宽度，20 dp 的方框在
手机上是极难点的目标，所以加了一条按父容器区分的规则：

- 父节点是 root / column / scroll（kind 1 / 2 / 9）→ 宽度铺满
  `avail`，整行可点；
- 父节点是 row / stack → 保持固有宽度，不把同一行的其他控件挤走。

这条规则写在 `measure_check` 里，依据是 `n.parent` 的 kind；它和
`weight` 无关，所以列里的复选框不需要 `weight(1)` 也会铺满。文字
只排一行（`text_measure(..., 0)`），超出裁剪——复选框标签不做多行，
和 HuxerUI 一致。

滑块相反：高度固定 32 dp，宽度要么铺满（列/根/滚动），要么在 row
里按 `weight` 分，独立放置时给 160 dp 默认值——和 HuxerUI 的默认
轨长一致。轨道绘制时两端各内缩 9 dp（拇指半径 8 + 1 px 余量），
节点比轨道宽 18 dp，保证拖到端点时拇指完整落在节点内；若节点宽度
小于 24 dp，内缩退化为 0，避免负宽度。

### D.25.3 描边：光栅器没有 stroke，用“外圈 + 内缩底色”拼

显示列表只有三种命令（圆角矩形填充、文字、图片），没有描边、没有
擦除、也没有“只画环”的原语。复选框的 2 dp 边框和单选钮的圆环是
这样画的：

1. 外圈用边框色画一个整块圆角矩形/圆；
2. 再用“内部露出色”画一个内缩 2 dp、圆角小 1 dp 的图形盖住中间；
3. 单选钮再叠一个 10 dp 的圆点。

“内部露出色”不能写死成白色或页面底色：复选框经常放在卡片上，
卡片有自己的 `bg`。于是绘制阶段加了一个上下文变量
`g_aui_paint_bg`：`paint_node` 进入节点时，若节点有非零 `bg` 就更新
它，根节点用 `theme_bg()`；子树绘制完再恢复。复选框/单选钮的内层
直接用这个值。这样同一个控件在页面、卡片、深色主题下都正确，且不
需要给节点增加“父背景色”字段。

对勾是三条线段，用 `paint_line` 画：Bresenham 逐点 stamp 一个
`t×t` 的小矩形（t = 盒子边长/8，最小 2 px），线段坐标从盒子尺寸
百分比推出（23%,54%）→（43%,74%）→（79%,31%）。不用 line 命令是
因为显示列表里没有；stamp 的矩形数上限 512 步，盒子最大 20 dp，
实际 30 步以内。

### D.25.4 滑块：手势接管与吸附

滑块的 DOWN / MOVE / UP 全部在 `handle_motion` 顶部拦下，不进入
通用的 press/drag 路径：

- DOWN：`slider_begin()` 记录节点 key、值、步长、轨道矩形、回调与
  user，把 `press_key` / `drag_key` 清零（否则外层 scroll 会跟着
  滚），然后立刻按触点取值并回调一次；
- MOVE：`slider_apply()` 按 `(x - track_x) * 1000 / track_w` 求千分比，
  值变化才回调 + invalidate；
- UP：再 apply 一次后 `slider_end()`；CANCEL 只 end。

值用 i64 乘再除，避免 1000 倍溢出（轨道宽度 1000 px 时 i32 就到头）。
吸附 `slider_snap()`：`v<=0 → 0`、`v>=1000 → 1000`，否则
`((v + step/2) / step) * step` 再夹紧。先判端点保证 `step=700` 这类
步长下用户仍能拖到 0 和 1000，而不是被吸附到 700/1400 后卡住。

拖动中的实时值放在 `g_aui_slider_val`，`aui_slider_value(key)` 先看
手势 key 是否匹配，否则扫描节点树回读 `n.aux`；找不到返回 -1。
这样应用在回调里只写一行 `a.bright = aui_slider_value(50)`，不必
自己从坐标换算。

### D.25.5 一个被字体假设绊倒的测试

`select_test` 第一版按“24px 字体、density 160”推算复选框行高为
26 px（20 dp 盒子与 24px 行高取大，再加 padding），实际是 20 px。
原因是 `font_latin.auf` 不是 24px 图集——它是旧的 8px/行高 10 图集，
按 2 倍绘制后行高 20 px，正好等于盒子高度。断言因此全部错位。
教训和 v1.19 一样：**测试里每一条与文字尺寸有关的常量都要以图集
头为准**，不能凭“文件名像 24”推断。修正后测试用 20 px 行距重排
Y 坐标（复选框 16、单选 44/64、滑块 100/140），并顺带覆盖了
“行高小于盒子时盒子垂直居中”的分支。

第二个失败更隐蔽：滑块点按断言用了 x=10，而节点从 x=16 开始
（column 的 16 dp padding），触摸落在节点外，回调根本没触发，
返回码 36 表示“读数没变”。把触点改到 x=20（节点内、轨道起点
25 的左侧）后，`slider_apply` 的负数钳制分支被正确覆盖，得到 0。
这类“测试自己点空了”的失败在离屏测试里没有视觉提示，只能靠
返回码定位，所以 `select_test` 的 45 个返回码按“先几何、再像素、
再交互”的顺序分段，便于二分。

### D.25.6 示例、测试与版本

- `examples/ui_settings.ast`：滚动页 + 两张设置卡（两个复选框、
  两个单选项、两个滑块）、亮度/音量实时数值、Reset；单选项切换
  `aui_set_dark`，一张截图里能同时看到浅色和深色两套调色板下的
  控件。包名 `dev.aster.uisettings`，是第 9 个 APK。
- `select_test`：45 个返回码。几何（复选框/单选钮 20 px 高、滑块
  32 px、轨道 y）、像素（勾选填充 `PRIMARY`、对勾白、未选边框
  `HINT`、内部底色、圆环/圆点、轨道左右段颜色）、交互（整行点按、
  标签点按、单选互斥、滑块点按 25% → 200、拖动 500 → 800、
  `step=0` 的两个端点）。
- 版本：`aui_version()` 12000（0x2EE0），versionCode 27。V 行
  修正为 `V00002EE0`——v1.19 的源码里 trace_hex 的字面量还停在
  11800（0x2E18），与 `aui_version()` 11900 不一致；v1.19 文档里
  写的 `V00002E7C` 是按 11900 推的，包上并未出现过。这次一并修掉，
  checks 里同时反汇编 `aui_version` 与 trace 字面量核对。

### D.25.7 边界

- 复选框/单选钮标签单行，超宽裁剪；没有多行、没有左侧图标。
- 单选钮的互斥完全由应用负责（同组只传一个 1），库不做分组键；
  这样同一棵树里可以并存多组，也不会引入库内状态。
- 滑块只有水平方向，没有刻度标签、没有双端范围、没有键盘/无障碍
  调节；吸附只在千分比空间进行，千分比精度 0.1%。
- 深色下的状态层是 `PRESSED`（深色主题里是暗蓝），没有 ripple 动画；
  按下反馈是静态的，和开关一致。

---

## D.26 v1.21.0：分段控件

### D.26.1 对照 HuxerUI 的 segmented_button.cpp

HuxerUI 的分段控件是「容器 + 等宽子段」：`SegmentedButtonStyle` 的默认值
是 `SURFACE` 底、选中段 `PRIMARY`、`TEXT` / `ON_PRIMARY` 两种标签色、
1 dp `HINT` 边框、内边距 14×7、最小段宽 48、最小高 32、圆角 8。
`measure` 取最高子段，`layout` 把内容宽度均分给各段，最后一段吃掉
除不尽的余数。AsterUI 照这个结构实现：kind 17 是容器，kind 18 是段，
段是普通叶子，容器负责等分与边框。

### D.26.2 测量与排列

- `aui_segmented(key, selected, cb, user)`：容器，`aux` 存选中下标，
  `bg` 固定 `SURFACE`，`radius` 8 dp；回调放在容器上，段在创建时复制。
- `aui_segment(key, text)`：叶子，`aux = -1`（标签长度由 `str_len` 算），
  `aux2` 先清 0，arrange 时写入自己的下标。
- `measure_segment`：宽 `文字宽 + 28dp`（至少 48 dp），高
  `文字行高 + 14dp`（至少 32 dp）。
- `measure_segmented`：先测所有子段，容器高 = 最高段；父节点是
  column / scroll 时宽度铺满 `avail`，否则保持 `Σ段宽`（所以能放在
  row 里和标签并排）。
- `arrange_segmented`：`cw = iw / cnt`（Q16.16 直接除），最后一段
  `w = cx + iw - x` 吃掉余数；每个子段 `aux2 = idx`。因为布局本身是
  Q16.16，172 px 分三段时每段是 57.33 px，绘制右边缘正好落在容器
  内沿；`aui_debug_rect` 只取整数部分，测试里读到的是 57/57/57。

### D.26.3 绘制：两层边框 + 一层胶囊

光栅器仍然没有 stroke，所以边框还是「外圈 + 内缩底色」：容器先画
`HINT` 圆角矩形，再在 `+1dp` 处画 `SURFACE` 圆角矩形（半径减 1 dp）。
每个段自己画胶囊：四周内缩 2 dp、圆角 6 dp；选中 `PRIMARY`（按下
`PRIMARY_DARK`），未选但按下 `PRESSED`。标签单行居中：选中用
`ON_PRIMARY`，其余用 `TEXT`。胶囊完全在段矩形内，不会盖住容器的
1 dp 边框；在 420 dpi（2.625×）下内缩量是 5 px，深色卡片上能看到
胶囊与边框之间留了一圈卡片色。

### D.26.4 输入与下标回读

段复制了容器的 `cb` / `user`，所以 `find_clickable` 直接命中段，
走与按钮相同的按压/抬起路径。UP 时若没有拖动，先判断节点 kind 是否
18：把父容器 key 与 `aux2` 写进 `g_aui_seg_key` / `g_aui_seg_val`，
再调用回调。应用在回调里用 `aui_segmented_value(容器key)` 读到的就是
本次点中的下标；非刚点击时该函数回读容器节点的 `aux`（应用传入的
选中值），找不到容器返回 -1。点已选中的段同样会回调一次（HuxerUI
的按钮语义），应用按需要忽略重复值即可。

### D.26.5 一个漏掉的 aui_end 与 761 px 的卡片

真机截图之前先做了离屏帧，结果 Climate 卡片的底部把 Reset 按钮和
两行说明都包了进去，分段控件的底边被滚动视口裁掉。用带调试计数的
`measure_column` 打出来：卡片高度 761 px，子节点是
`[61, 62, 67, 50, 51, 52, 53]`——Reset 和说明确实挂在卡片下面。
原因是 `aui_segmented(...) -> aui_segment(...)` 之后只写了一个
`aui_end()`：第一个关掉分段容器，卡片保持打开，后面所有节点继续
往里塞。卡片正常高度应为 `16*2 + 60 + 4 + 60 + 4 + 96 = 321 px`。
补上 `aui_end()` 后胶囊四边内缩都是 5 px，Reset 回到卡片下方。

这类 bug 用像素看只觉得「控件被裁了」，用 `aui_debug_rect` 把所有
key 的矩形打出来、再看父子链就一眼定位；`segmented_test` 里也加了
行内固有宽度与卡片外节点的断言，防止再次把兄弟节点吞进容器。

### D.26.6 测试与版本

- `segmented_test`：52 个返回码，离屏 320×240、density 160。覆盖
  容器/三段矩形（96×32 等分）、1 dp 边框与 2 dp 胶囊内缩的像素
  （y+0 边框、y+1 内衬、y+2 胶囊上边、y+29 胶囊下边、y+30 内衬）、选中主色、
  未选 `SURFACE`、选中白字/未选深字、点 High 回调与
  `aui_segmented_value(3)==2`、点 Low 回 0、再点已选中段仍回调、
  只按下时的 `PRESSED` 胶囊、点容器外不回调；row 内两段保持 96 px
  固有宽度、A/B 独立选择；第三行三分段 172 px 验证 Q16.16 等分。
  其中「选中段中心像素」最初取段中心，结果正落在字形上（白色），
  改为取胶囊左侧空白处；这是像素断言常见的坑。
- `ui_settings` 增加 Climate 卡：Height / 数值 / 单位一行，下面
  cm / in 分段；切换单位时数值 175 ↔ 69 同帧重建。
- 版本：`aui_version()` 12100（0x2F44），versionCode 28，trace 第二行
  `V00002F44`；qemu 24 项全过。

### D.26.7 边界

- 段宽严格等分，不支持按内容自适应（HuxerUI 同样均分）；段数很多时
  每段可点区域会小于 48 dp 的视觉下限，需要应用自己控制数量。
- 标签单行无图标；没有多选、没有滑动手势切换，也没有分段间的
  动画过渡。
- 容器背景固定 `SURFACE`，没有逐控件配色；按下态是静态的，没有
  ripple。
- 段的命中矩形就是布局矩形，容器没有内边距时整个控件都可点；
  在 row 里使用时宽度由文字决定，不会自动拉伸。

---

## D.27 v1.22.0：标签页

### D.27.1 对照 HuxerUI 的 tabs.cpp 与 TabsStyle

HuxerUI 的 Tabs 由 `TabsLayoutPolicy` 与 `TabsStyle` 组成。默认样式：
背景透明、无分隔线；普通标签用 `on_surface`、选中标签用 `primary`；
指示条 `primary`、高度 2 dp、圆角 1 dp、`TabIndicatorSizing::Item`
（宽度等于当前页宽）；`item_padding = 12×8 dp`；`minimum_item_width`
48 dp、`minimum_height` 36 dp、`expand_items = false`；默认没有 ripple
（`indication = nullopt`）。AsterUI 用两个新节点类型复刻：19 = 容器，
20 = 页；容器 `aux` 存当前页下标，页 `aux2` 由 arrange 写入页下标，
这样指示条绘制与 UP 回读都只依赖页自身。

### D.27.2 测量与排列：页宽由文字决定

HuxerUI 在未开启 `expand_items` 时按每页的固有宽度排列，容器本身
则 `ConstrainWidth(max(natural, min))`。AsterUI 的 measure_tab：

```
w = text_measure(text) + 24dp，且不小于 48dp
h = max(text_line_h + 16dp, 36dp)
```

于是页宽包含左右各 12 dp 的 `item_padding`，标签在 `paint_tab` 里
从 `n.x + 12dp` 起画单行。measure_tabs 对每个子节点调 measure，容器
高度取最高一页，宽度在父容器是 root/column/scroll 时铺满 `avail`，
否则（row/stack）取 `Σ页宽`。arrange_tabs 不摊剩余宽度：从
`n.x + pad` 起依次排开，同时写 `cn.aux2 = idx`；超出容器的页由绘制
阶段的 clip 裁掉，与滚动容器的视口裁剪共用一个矩形。

一个容易忽略的点：48px 比例字体下页宽很大。`ui_tabs` 的三页
Feed/Stats/More 在 2.625× 下合计 527 px，而内容区去掉 24 dp 内边距后
只有 546 px——只差 19 px。页宽是文字决定的，换更长的标题就会横向
溢出并被裁剪，这是 `expand_items=false` 的必然结果，应用需要自己
控制页数与标题长度（HuxerUI 同样如此）。

### D.27.3 绘制：底部指示条与文字颜色

`paint_tabs` 先画可选的自定义背景（`aui_bg` 设了才画），再在
`y + h - 2dp` 处画一条高 2 dp、圆角 1 dp 的 `PRIMARY` 矩形，宽度取
`aux2 == aux` 的那一页；找不到匹配页（下标越界）就不画。
`paint_tab` 只负责文字：选中页 `PRIMARY`、其余 `TEXT`，单行、
左内边距 12 dp、垂直居中。指示条在子节点之前 emit，文字随后画在
它上方，天然不会互相覆盖。

和滚动容器一样，kind 19 在 `paint_node` 里把裁剪矩形收窄到自身
矩形（再与父裁剪求交），子树所有命令都带这个 clip；退出时恢复。
这样即使页总宽超出容器，右边被裁掉的页也不会画出容器外。注释里
写明了「指示条只在当前页下方」，所以测试用 y+34（36 dp 高、2 dp
条）和 y+35 两行像素断言，而未选页下方必须没有 `PRIMARY`。

### D.27.4 输入：空白区域不回调

页构造时从容器复制 `cb` / `user`（与 segment 相同），所以点页走通用
clickable 路径。UP 时若命中的节点 kind 为 20，先写
`g_aui_tab_key = 容器 key`、`g_aui_tab_val = 页 aux2`，再调回调；
`aui_tabs_value(容器key)` 先看这对全局，否则回读容器节点的 `aux`，
找不到返回 -1。点已选中页同样回调（与 HuxerUI 按钮语义一致）。

与分段控件不同的是，页之间会有空白：容器在 column 里铺满整行，
三页只占左边一段，右侧剩下的是「容器本身」的命中。`find_clickable`
会一路向上找到容器的 `cb`，如果不处理，点空白也会回调并让应用
拿到「未变化的当前页」。v1.22 在点击派发处加了一条：`kind == 19`
的节点不调用回调。这样空白区域静默，页的点击不受影响。

### D.27.5 换行标签在 column 里的宽度陷阱

做 `ui_tabs` 的 Stats 页时出现了文字互相压盖：`measure_text` 用
可用宽度 462 px 算出标签占两行（120 px 高），arrange_column 却按
`cn.w`（最长一行的固有宽度，约 430 px）摆放，`emit_text_lines` 又按
`n.w - pad*2` 重新断行，得到三行 180 px，于是后面的兄弟节点压到了
第三行上。根因是**测量宽度与绘制宽度不一致**，不是换行算法本身。

修法是给需要换行的标签补 `aui_align(3)`：column 的 arrange 看到
align 3 时把子节点宽度改成整列内宽，绘制断行宽度就与测量时完全一致。
`ui_tabs` 里所有段落型标签（Feed 的两行说明、Stats 的说明与覆盖率、
More 的说明）都加了 align 3，截图中的重叠消失。这个约束值得写进
使用说明：**在 column 里放会长到换行的标签，必须 `aui_align(3)`**，
否则测量与绘制会按两个不同宽度断行。

### D.27.6 测试与版本

- `tabs_test`：47 个返回码，离屏 320×240、density 160。覆盖容器/
  三页矩形（48/48/72，不是均分）、选中页主色文字、未选页 `TEXT`、
  选中页无 `TEXT` 字形、指示条上下两行主色（y+34 / y+35）、未选页与
  第三页底部无主色；点 Longer 回调一次且 `aui_tabs_value(3)==2`，
  重绘后指示条与文字颜色一起移动；点 A 回到 0；再点已选中页仍回调、
  下标不变；点第三页右侧容器空白不回调；row 内两页保持 96 px 固有
  宽度、三页行 48+72+48=168 px、行内选择独立；未知 key 返回 -1。
- `ui_tabs` 示例（第 10 个 APK）：Feed 页有刷新按钮与计数，Stats 页
  有属性行与 70% 进度条，More 页有复选与深色开关；Reset 回到默认。
  720×1280@420dpi 下浅色 Feed/Stats/More 与深色 More/Feed 五帧已
  目视确认，页签、指示条、卡片与深色调色板都正确。
- 版本：`aui_version()` 12200（0x2FA8），versionCode 29，trace 第二行
  `V00002FA8`；qemu 25 项全过（新增 tabs 一项）。

### D.27.7 边界

- 只有文字页签，没有图标、徽标、可关闭页签与滑动切换；页内容由应用
  按当前下标自行渲染，库不保存页面。
- 指示条没有 HuxerUI 的 160 ms 位移动画，切换是瞬时的；也没有
  `TabIndicatorSizing::Content`（只实现了默认的 Item）。
- 页总宽超过容器时右侧被裁剪，不提供横向滚动或省略号；页数很多时
  需要应用自己缩短标题或减少页数。
- 容器背景只有 `aui_bg` 一种；没有分隔线（默认透明且高度 0，与
  HuxerUI 一致），也没有按下态（HuxerUI 默认 `indication = nullopt`）。
- 页的命中矩形就是布局矩形；空白区域被明确排除在回调之外。

---

## 结语

AsterUI 的可行性不依赖「Aster 变成 C++」：它依赖的是 Aster 已经具备的 `ptr`/`struct`/函数指针/固定数组/`@embed`/NativeActivity 打包能力，加上三个工程决定——**自绘、定点、位图字体**。HuxerUI 提供了经过验证的架构骨架（保留树、key 协调、约束布局、显示列表、手势仲裁、语义树、平台适配、无窗口测试），AsterUI 把其中依赖 Java/float 的部分替换成 Aster 原生实现，同时明确写下做不到的边界（TTF 整形、完整 IME、TalkBack）。

v1 的目标不是「和 Android UI 一样强」，而是**在没有任何 Java/Kotlin/dex 的前提下，做出一个正确、可测试、可维护、足够用的原生 UI 标准库**。

---

## D.28 v1.23.0：形状抗锯齿

### D.28.1 为什么先做形状、不做文字

用户反馈 48px 字体“发虚”之后，v1.19 用原生 48px 1bpp 图集把笔画台阶
降到了 1 物理像素；如果这时把文字改成灰度抗锯齿，CJK48 图集要从 2.0 MB
（1bpp）涨到约 8 MB（4bpp），而且 48px 灰度字形在 density 3.25 下会重新
显得发虚。真机上目前最扎眼的锯齿来自几何边缘：卡片/按钮的大圆角、开关
胶囊、单选圆环、复选方框和 2 dp 指示条。因此 v1.23 只处理形状。

### D.28.2 覆盖率模型：圆角带逐行求交

AsterUI 的圆角以前用整数 `inset = r - floor(sqrt(r²-dy²))` 逐行内缩，
边界落在整数像素上，曲率大的地方就是台阶。v1.23 把圆角带的每一行改成：

```
dy16 = row*16 + 8 - cy*16                 // 像素中心到圆心，1/16 px
s    = isqrt(r16*r16 - dy16*dy16)         // 圆在该行的半宽
xb16 = (x0+r)*16 - s;  xr16 = (x1-r)*16 + s
pl = xb16/16;  pr = xr16/16
核心区间 [pl+1, pr) 整行写入；pl、pr 两个边界像素按覆盖率混合
cov = clamp(128 + (r16 - d16)*16, 0, 255)
```

`d16` 是该像素中心到对应圆心的距离（同样是 1/16 px）。系数 16 的含义是
每往里 1/16 px 覆盖率加 16/255，于是在边界两侧各 0.5 px 内从 0 过渡到
255，正好一个像素宽。为什么用 1/16：距离平方和放进 i32 后，半径可以到
约 1000 px 才溢出；1/16 px 的量化对 8 位覆盖率足够细。

左右两个边界必须用各自的圆心：左边是 `x0+r`，右边是 `x1-r`。第一版
两处都用了左圆心，右侧圆角的覆盖率恒为 0，右半边的弧完全没有过渡，
`shape_aa_test` 的已选复选框角（返回码 25）就是被这个错误卡住的。

直边中点不受影响：矩形 x0/x1 是整数像素，非圆角带的行仍走整行
`fill_run`；半径 0 的底色填充保持原来的快路径（转场合成也依赖
`is_bg_fill` 的 radius==0 判断）。裁剪方面，x0/x1 先夹到帧缓冲与裁剪
矩形，pl/pr 再夹一次；水平方向被裁得比圆角还窄时（pr <= pl）退化为
整行填充，避免出现空心行。

### D.28.3 透明度与 1~2 dp 描边

边界像素走 `fill_px_cov`：先把颜色自身的 alpha 乘以覆盖率，再调
`blend_px`。按压态、动画 alpha 这类半透明填充因此不会出现“覆盖率混合
一次 + alpha 混合一次”的双重混合，边缘也不会发黑。

光栅器没有 stroke 原语，分段外框（1 dp）、复选边框（2 dp）、单选圆环
都是「外圈圆角矩形/圆 + 内缩的底色圆角矩形/圆」。两层各自在曲边做覆盖
率过渡，合成后细环的内外边缘都是平滑的；直边部分两端都是整数像素，
仍是精确的前景色/底色，不会出现整圈发灰。也就是说，这一版不需要为
描边单独加“覆盖率列”。

### D.28.4 开销

每个圆角行一次 `isqrt` 求边界，左右边界像素各一次 `isqrt` 求覆盖率；
圆角带最多 2r 行，常见半径 4~12 px 时一个形状只有几十次平方根。中心
区域仍是整行写入，整屏开销与 v1.22 同量级。没有逐像素求距离，也没有
超采样。

### D.28.5 测试：shape_aa_test

离屏 320×240、density 160，column 里依次放：

- 进度条（288×8，轨道胶囊半径 4，只有轨道色）；
- 开关（44×24，轨道胶囊半径 12 + 18 px 拇指圆半径 9）；
- 未选复选框（20×20，半径 4，2 px `HINT` 描边 + 背景色内芯）；
- 已选复选框（20×20，半径 4，`PRIMARY` 填充）；
- 标签页（一页 48×36，底部 2 px 指示条半径 1）。

断言 32 条：圆角区域存在“既不是前景也不是底色”的中间色像素（进度条
≥6、拇指圆 ≥6、描边 ≥4、已选块 ≥3、指示条两端各 1）；圆角外的角像素
仍是精确底色；直边中点与内部仍是精确前景色；指示条内部（y+0/y+1）
仍是纯 `PRIMARY`、右端外一像素仍是底色。半径 4 的方块一圈只有 3 个
过渡像素（64/192 等），所以已选块的阈值是 3 而不是 4——这是覆盖率
量化的正常结果，不是缺陷。

### D.28.6 前后对比

720×1280@420dpi（density 2.625）用同一份 `ui_tabs` / `ui_settings` 分别
以 v1.22 与 v1.23 渲染：标签页指示条端头、卡片大圆角、单选圆环、复选
方框、滑块拇指的台阶都消失，弧边出现 1 px 过渡。文字、对勾、键盘图标
仍是 1bpp 阶梯——这是本版有意保留的范围（见 D.28.1）。

### D.28.7 边界

- 不做文字抗锯齿，也不做对勾/键盘图标的线段抗锯齿（`paint_line` 仍是
  逐点小方块）。
- 覆盖率用距离线性近似面积，不是精确面积积分：小半径（1~3 px）的
  斜向角落会略微高估，视觉上只是过渡稍软；大半径的弧边与水平/垂直
  切点处与理想面积基本一致。
- 没有 gamma 校正、没有 4×/16× 超采样、没有多层 alpha 的预乘；深色
  主题下的过渡色按 sRGB 直接线性插值，与 v1.22 的半透明混合保持一致。

### D.28.8 真机首帧（v1.23）

用户提供的 trace（1216×2688、density 3.25、sdk 36、安全区 24/24）第二行
`V0000300C`；`N00000018` / `P00000018` 在四次点按 + 区域、一次重置、两次
提醒开关、两次拖动和一次窗口重建（`W` → `J0`/`Y0` → `N L P F`）期间保持
不变，说明 AA 只改边界像素，没有改变布局、命中或命令列表。截图中卡片
16 dp 圆角、按钮、开关轨道/拇指与进度条端点的弧边过渡自然，没有发灰或
毛边；文字仍是 1 px 台阶。窗口重建后界面恢复正常，无崩溃。这次没有覆盖
`ui_settings` 的 1 dp 边框、`ui_tabs` 的 2 dp 指示条与深色背景，也没有
1:1 像素放大，留待下一轮截图。

---

## D.29 v1.24.0：横向分页（Pager）

### D.29.1 对照 HuxerUI 的 pager.cpp

HuxerUI 的 Pager 是一个保留型控件：内部维护当前页、拖动偏移、吸附动画，
子页通过适配器提供，只保留视口附近的三页。AsterUI 是立即重建架构，节点树
每帧都可能被应用重新声明，因此不能把「当前页/偏移」放在节点里，也不能
让库持有子页对象。v1.24 的做法是：

- 页仍然是普通节点（`aui_page`，kind 22），由应用在 build 里重新声明；
- 偏移按容器 key 存在库内的 32 槽表里，跨 rebuild 保留；
- 所有页都排进布局（不像 Huxer 只保留三页），靠绘制裁剪保证只画视口内的
  像素。页数很少（示例 3 页），这个取舍让布局与命中都简单；
- 选中页由应用传入（`selected`），库只负责手势、吸附和回调；这与 tabs /
  segmented / switch 的「状态由应用持有」约定一致；
- 回调只提议**相邻**一页，应用可以接受也可以忽略。

参数直接采用 HuxerUI 的手感：8 dp 方向锁、35% 页宽位移阈值、600 px/s
速度阈值、200 ms ease-out 吸附。

### D.29.2 布局与绘制：页并排、绘制时裁剪

`aui_pager` 的测量与滚动容器类似：宽度取可用宽度，高度取最高一页；
`aui_page` 按列容器测量。排列阶段：

```
iw = 容器宽 - pad*2
maxoff = (页数-1) * iw
第 i 页 x = 容器 x + pad + i*iw - offset
第 i 页 w = iw, h = 容器高 - pad*2
```

首帧 `offset = selected*iw`，直接落在目标页，不播动画；之后若 selected
变化、且没有正在拖动、也没有正在吸附，就调用 `pager_anim_to(key,
selected*iw, 200)`。偏移在 `arrange` 里写回节点（`aux2` 仅测试/调试用），
每帧位置都由它算出。

绘制时 kind 21 追加一条容器裁剪命令，视口外的页由光栅阶段丢弃；页里的
scroll 仍有自己的视口裁剪，二者嵌套。页高固定为分页视口高，因此页内的
滚动容器必须给 `weight(1)` 才能拿到确定高度——这是 v1.24 测试夹具踩到的
第一个坑：测试的最外层 column 忘了 `weight(1)`，列高退化成内容高，
分页容器又因为自身 `weight(1)` 不参与固有高度，最终拿到 0 高。库的行为
是正确的，但「分页容器要给 weight、页内滚动也要给 weight」写进了文档与
示例。

### D.29.3 手势：候选、方向锁与吸附

DOWN 时同时记录分页候选与滚动候选，但不立即决定谁接管。MOVE 的第一个
超过 8 dp 的位移做方向锁：

- `|dx| > |dy|`：分页接管。清掉按压态与滚动候选，偏移按 `off0 - dx`
  实时更新，并 `aui_invalidate_layout()`（位置与命中都变了，必须重排）。
- 否则：锁定纵向，分页退出，滚动候选按原逻辑继续；同时清掉按压态，
  纵向拖动超过 8 dp 后即使手指仍在按钮矩形内，松手也不再算点击。
- 8 dp 以内：谁都不动，保留点击的可能性。

偏移来源是按下时的快照 `off0`，不是上一帧的偏移，这样动画被打断时手势
也不会跳。拖动过程中偏移允许越过 0..maxoff，由松手后的吸附拉回。

UP 时若分页已接管：

```
速度 >= 600 px/s        -> 按速度方向提议相邻页
否则位移 >= 35% 页宽    -> 按位移方向提议相邻页
否则                    -> 留在当前页
首尾不越界，一次只走一页
```

提案与当前页不同时，先写 `g_aui_pager_prop_key/val` 再调用一次 `cb(user)`，
应用在回调里用 `aui_pager_value(key)` 读；随后无论应用是否接受提案，
偏移都吸附到提案页。CANCEL 与「按下但没有横向拖动」走
`pager_gesture_end()`：吸附回按下时所在页，不写提案、不回调。

吸附动画与 fling / 页面转场共用帧泵：`pager_anim_count()` 非零时
`aui_frame` 继续出帧，`pager_step` 按线性时间求 ease-out 插值，期间置
need_layout/need_paint；动画结束、`onPause`、窗口销毁、新导航都会清状态。
与 ALPHA/TX/TY 动画不同，分页动画会改变布局，所以它走
`g_aui_need_layout` 而不是只叠加绘制偏移。

### D.29.4 命中：只有当前页可交互

`hit_test` 遇到 kind 21 时不再递归所有子页，而是找到 `aux2 == aux`
（当前 selected）的那一页再下钻；点到邻页露出的窄条时返回容器本身，
不会命中邻页的按钮。拖动中的邻页只是画面，松手吸附完成、应用把 selected
改过来之后才可交互。这个规则与 HuxerUI 的「只把当前页当内容」等价，
也避免了「拖到一半点到隔壁按钮」的经典误触。

### D.29.5 测试：pager_test 与 pager_harness

`pager_test`（离屏 320×240、density 160、三页红/绿/蓝各 288×188）覆盖：

- 初始偏移 0、三页位置、首屏只有红页、视口右外是底色；
- 点当前页按钮命中 A+；拖到 60 px 时红页左移、绿页进入、裁剪仍生效；
- CANCEL 回弹不回调；左拖 150 px 松手提议第二页、200 ms 后偏移 288；
- 第二页按钮命中 B+、第一页按钮不触发；
- 短拖 50 px 回弹不回调；第二页再左拖只提议相邻的第三页；
- 末页继续左拖不回调；纵向拖动锁定滚动、偏移不变；
- 应用把 selected 改回 0 后自动吸附；未知 key 返回 -1；
- 最后用注入的单调时钟做 50 px 快速轻扫：位移不到 35% 页宽，但
  `pager_sample` 平滑后的速度超过 600 px/s，同样提议下一页；
- 从按钮上纵向拖 15 px 再松手，锁定为纵向且不触发按钮回调。

为了测试速度阈值，`tests/fake_ndk.ast` 增加了可注入的
`g_fake_clock_ns`（默认 0，旧测试行为不变）与 `fake_set_clock(t)`；
`clock_gettime` 从它拆出 sec/nsec。这样不需要真实等待就能构造
20 ms / 10 ms 的 MOVE 间隔。

`pager_harness` 跑真实 `ui_pager`（720×1280、density 420）：左滑一页后
Tab 与 `aui_pager_value(20)` 都变成 1，第二页贴住视口；点 Settings Tab
后分页容器自动吸附到第三页；同时断言 `aui_version() == 12602`（v1.25 时
为 12500，v1.26 起跟随库版本）。

### D.29.6 一个提案值生命周期 bug

pager_harness 第一次运行卡在「点 Settings 后 `aui_pager_value(20)` 仍是 1」。
原因不是布局，而是「刚松手提议值」缓存 `g_aui_pager_prop_key/val` 一旦写入
就再也没清：横滑后应用把 selected 改成 2，读 pager 时仍返回上一次的提案
1。tabs 的 `g_aui_tab_key` 有同样的问题，只是既有测试没有在重建后读
「最后点击的那个 key」，所以没暴露。

修复放在 `aui_root`：每次重建开始时清掉 tab/pager 的提案缓存。语义变成
「提案值只保证在当帧回调里可读；回到 build 后 `aui_tabs_value` /
`aui_pager_value` 回读节点上的真实 selected」。这既修了 pager，也让 tabs
的 API 行为与文档一致。

### D.29.7 版本、示例与边界

`ui_pager.ast`（第 11 个 APK，`dev.aster.uipager`）把 Tab 与分页共用一个
`s.tab`：点 Tab 只改状态，分页下一帧自动吸附；横滑回调把提议页写回
`s.tab`，Tab 立即高亮。三页分别是可刷新的 Feed、属性/进度的 Stats、
复选/开关/深色的 Settings，每页内部是独立 scroll。

边界：

- 不做循环分页（首尾不越界），HuxerUI 默认也不是无限循环；
- 不支持一次跨多页，也不支持页面之间的 3D/缩放转场；
- 页宽固定为视口宽，不支持 peek（露出邻页一部分）或按内容宽度分页；
- 分页容器只认直接子节点 `aui_page`，其他 kind 会被当作普通子节点排列，
  不保证行为；
- 拖动时不做边缘阻尼（rubber band），越界部分在松手后由吸附拉回。

`aui_version()` 12400，十一个 APK 以 versionCode 31 / 1.24.0 重打包，
qemu 28 项（26 个既有 + pager_test + pager_harness）全过。真机验证待
用户安装 `uipager.apk` 后提供截图/trace：第二行应为 `V00003070`，
横滑与点 Tab 时节点数/命令数应保持稳定（分页只改布局与裁剪，不改变树）。

## D.30 v1.25.0：模态对话框（Dialog）

### D.30.1 对照 HuxerUI 的 presentation.cpp

HuxerUI 的 `Dialog` 是叠在内容上的一个居中卡片：背景压暗、圆角、
标题/正文/操作区，点遮罩或返回键关闭。AsterUI 之前只有页面栈
（`aui_nav_*`），没有“盖在当前页上、但又不离开当前页”的层。v1.25
补上这一层，节点类型 23（遮罩）与 24（卡片），公共 API 只有三行：

```aster
if (open != 0) {
    aui_dialog(key, open, cb, user);   // 返回卡片句柄
    /* 标题、正文、按钮…… */
    aui_end();
}
let reason: i32 = aui_dialog_reason(); // 1 遮罩 / 2 BACK
```

选择“游离层”而不是“往根树里塞一个 stack”，原因有三个：

1. 页面栈/滚动/分页都以根树为坐标系，插一个满屏兄弟节点会改动它们的
   measure/arrange 结果，等于为对话框再写一遍布局分配；
2. 模态要求底层完全不可点。根树里多一层仍要改命中顺序，游离层直接把
   `hit_test(root)` 重定向，逻辑只有一行；
3. 对话框只在一帧内存在：应用在 `open == 0` 时不调用 `aui_dialog`，
   重建后节点自然消失，不需要“隐藏/恢复”状态。

### D.30.2 布局：内容区居中、宽高夹紧

`dialog_layout(cx, cy, cw, ch)` 在根树排完之后调用，参数是本帧内容区
（已扣安全区）：

- 遮罩节点 x/y/w/h 直接取整窗 `g_aui_sw/sh`，不参与内容区布局；
- 卡片宽 `min(cw − 48dp, 320dp)`，两侧各留 24 dp；高先按 column
  测量，再夹到 `ch − 48dp`，避免小屏上卡片顶到系统栏；
- 卡片 x = `cx + (cw − w)/2`，y = `cy + (ch − h)/2`；
- 卡片就是普通 column（kind 24 在 measure/arrange 里直接复用
  `measure_column` / `arrange_column`），默认 `pad 24dp`、`gap 12dp`、
  `radius 16dp`，`SURFACE` 底；应用可以在 `aui_dialog` 之后用
  `aui_pad/aui_gap/aui_bg/aui_radius` 覆盖。

### D.30.3 绘制与命中：整棵树之后、整体接管

绘制顺序是：根树（含分页裁剪、系统栏条带）→ 遮罩矩形（
`0x99000000`，全窗）→ 卡片（圆角矩形 + 子节点）。遮罩不推进
`g_aui_paint_bg`，卡片的底色由 kind 24 自己设置，所以卡片里的
checkbox/radio 内衬仍然是卡片色。

命中测试在入口处重定向：

```aster
if (i == g_aui_root && g_aui_dialog >= 0) {
    return hit_test(g_aui_dialog, px, py);
}
```

对话框节点本身占满整窗，落在遮罩上返回遮罩的负 key（`-key`），落在
卡片里返回子节点或卡片 key。卡片的 `cb` 是一个内部空回调
`dialog_noop`，所以点卡片空白不会关闭；按钮的命中优先级天然高于卡片。
遮罩的 UP 把 `g_aui_dialog_reason` 置 1 再调用应用回调。

BACK 在焦点/页面栈之前处理：有对话框时只调一次回调、置 reason=2、
`aui_invalidate()` 后返回 1，不再收键盘、不再 pop 页面。应用在回调里
把 `open` 置 0，下一帧 `aui_root` 清空 `g_aui_dialog*`，对话框消失。
关闭原因只在回调当帧有效，重建时清零。

### D.30.4 边界

- 同时只支持一层：`g_aui_dialog >= 0` 时再次调用返回 -1；
- `key <= 0` 或 `open == 0` 返回 -1，不创建任何节点；
- 卡片使用应用传入的正 key，遮罩使用 `-key`，测试里可用
  `aui_debug_hit` 区分“点遮罩”和“点卡片”；
- 对话框内不支持 `aui_text_field`：焦点、键盘、文本池都以根树 key 为
  坐标，模态层尚未接入输入法；
- 卡片高度超过内容区时只做夹紧，不做内部滚动；内容特别多时应用应
  自己拆成更短的文案；
- 没有进出场动画（HuxerUI 有淡入）。动画槽作用于绘制属性，遮罩/卡片
  是独立节点，后续可以给 kind 23/24 加 alpha 槽而不改布局。

### D.30.5 测试：dialog_test 与 dialog_harness

`dialog_test`（离屏 320×240、density 160、字体 scale 2）：

- 打开前 4 个节点；打开后 9 个（遮罩 + 卡片 + 4 标签 + 行 + 2 按钮）；
- 卡片 `(24,58,272,124)`：320 宽减两侧 24，240 高居中；
- 遮罩像素 `0x626263`（`F6F6F8` × 0.4），卡片中心是 `SURFACE`；
- `aui_debug_hit(5,5) == -20`（遮罩）、`aui_debug_hit(160,60) == 20`（卡片）；
- 点卡片 padding 不关闭；点 OK 只触发 OK 回调，不关闭；
- 点遮罩关闭、reason=1，底层按钮计数仍为 0；关闭后卡片矩形消失，
  底层按钮恢复可点；
- 重开后按 BACK 关闭、reason=2，底层计数不变。

`dialog_harness` 跑真实 `ui_dialog`（720×1280、density 420）：

- 点 Delete draft 后卡片宽 594 px（720 − 2×63）、水平/垂直居中，
  节点数从 base 变 base+7，左上角像素被遮罩压暗；
- 点 (5,5) 关闭后节点数回到 base，左上角恢复 `F6F6F8`；
- 重开后 BACK 关闭；第三次打开点 Cancel 关闭；`aui_version() == 12602`。

### D.30.6 版本、示例与边界

`ui_dialog.ast`（第 12 个 APK，`dev.aster.uidialog`）是一个列表页：
“Delete draft” 打开确认框，卡片里 Cancel/Delete 各占一半（`weight(1)`），
状态行显示最近一次关闭路径（遮罩 / BACK / 取消 / 删除），删除后
“Drafts left” 数字减一；底部还有深色开关，用来确认对话框跟随主题。

`aui_version()` 12500，十二个 APK 以 versionCode 32 / 1.25.0 重打包，
qemu 30 项（28 个既有 + dialog_test + dialog_harness）全过。真机验证
待用户安装 `uidialog.apk` 后提供截图/trace：第二行应为 `V000030D4`，
打开对话框时 `N` 应比关闭时多 7 个节点（ui_dialog 的卡片内容），
点遮罩/按 BACK 后应回到原来的节点数。

## D.31 v1.26.0：下拉选择（Select）

HuxerUI 的 `dropdown.cpp` 是“触发器 + 锚定列表面板”。难点不在画列表，
而在两个约束：面板必须贴着触发器、又必须能挡住底下的内容；而 AsterUI
的节点树只有一层普通布局，节点不能脱离父容器自由定位（对话框已经证明
“游离层”是最省事的做法）。v1.26 的选择是：**触发器留在普通流里，
选项仍是它的子节点，但只在展开的那一帧被 `select_layout` 重新摆到
锚定位置**。这样节点数在展开/关闭时完全不变，不引入第二套树。

### D.31.1 节点与 API

新增 kind 25（select 容器）与 26（option 叶子）：

```aster
fn aui_select(key: i32, selected: i32, open: i32,
              placeholder: ptr, cb: fn(ptr) -> i32, user: ptr) -> i32;
fn aui_option(key: i32, text: ptr) -> i32;
fn aui_select_value(key: i32) -> i32;   // 刚点中的选项下标，0 起
fn aui_select_reason() -> i32;          // 0 触发器 / 1 选项 / 2 外部或触发器 / 3 BACK
```

`aui_select` 是容器：应用随后声明若干 `aui_option`，再 `aui_end()`。
`selected` 是当前下标，`open != 0` 时把节点记进 `g_aui_select_open`
（只记第一个，保证同时只展开一个）；选项只在 build 时记录文本，不
单独回调——点中后统一走 select 的 `cb`，用 `aui_select_value(容器 key)`
读取下标，语义与 segmented/tabs/pager 的“父 key + 子下标”一致。

### D.31.2 测量与布局

`measure_select`：

- 触发器文字 = 选中项文本；`selected` 越界（含 `-1`）时用 placeholder；
- 高 = `max(文字行高 + 20dp, 48dp) + pad*2`，与输入框同高；
- 宽：parent 是 column/root/scroll 时撑满可用宽；row/stack 里取
  `max(文字宽 + 42dp, 160dp)` 的固有宽度；
- 选项不参与 measure（它们的位置由 `select_layout` 决定）。

`select_layout(cx, cy, cw, ch)` 在根树 arrange 之后、对话框布局之前跑：

- 浮层宽 = 触发器宽，夹到 `内容宽 − 16dp`；x 先对齐触发器，越界往
  左推，最小 `cx + 8dp`；
- 浮层高 = `vis × 48dp + 12dp`，`vis` 初始为选项数，超过
  `内容高 − 16dp` 时按 `(maxh − 12dp) / 48dp` 截断（不滚动）；
- y = 触发器底 + 4dp；放不下时尝试触发器顶 − 浮层高 − 4dp，仍放不下
  就夹到 `cy + ch − 8dp − 浮层高`，最后不高于 `cy + 8dp`；
- 每个可见选项 arrange 到 `(px + 4dp, py + 6dp + i×48dp, 浮层宽 − 8dp,
  48dp)`；不可见的选项 arrange 到 0×0，绘制与命中都跳过。

节点坐标仍是 Q16.16，4 dp / 6 dp 的半数像素不会丢精度。

### D.31.3 绘制

- 触发器：1 dp HINT 描边 + 内缩 1 dp 的 SURFACE 圆角块（radius 10），
  按下换 PRESSED；文字左内边距 16 dp，右侧留 16 dp + 10 dp 给三角；
  文字裁剪到三角左侧，超长不压到箭头。
- 三角：3 行矩形，宽 10/6/2 dp、每行高 2 dp、圆角 1 dp，HINT 色。
  不用字体，避免依赖某个字形。
- 浮层：1 dp HINT 边框 + SURFACE 内衬，radius 11；先设裁剪到浮层矩形，
  再逐项绘制，最后恢复裁剪。这样选项文字不会溢出圆角。
- 选项：选中时先画内缩 4 dp、radius 8 的 TINT 块；按下时同位置画
  PRESSED。文字 TEXT（选中 PRIMARY），左内边距 12 dp，垂直居中。
- 绘制顺序：根树 → 浮层 → 对话框。对话框打开时浮层直接跳过（不绘制、
  不命中），保证 v1.25 的模态语义优先。

### D.31.4 命中与输入

展开时 `hit_test(root)` 在入口处分流：

1. 点在浮层矩形内：逐项比较可见选项，命中返回 option 的下标；否则
   返回 `-2`（padding，吞掉）；
2. 点在触发器矩形内：返回 select 节点；
3. 其他：`-1`（外部，关闭）。

DOWN/UP 在通用派发之前拦截（与对话框同层）：DOWN 只记录
`g_aui_select_press`（选项）或按在触发器上；UP 时：

- 命中选项：写 key/下标/reason=1，调 `cb`；
- 命中触发器：reason=2，调 `cb`（“再点一次关闭”）；
- `-2`：什么都不做；
- `-1`：reason=2，调 `cb`；
- 其他节点（理论上不会出现）：吞掉。

BACK 在焦点/导航之前处理：展开时 reason=3、调一次 `cb`、返回 1，
不 pop 页面、不收键盘。CANCEL 清掉按下态，不改变展开状态。

**状态提交时机**：`g_aui_select_open` 只在 build 时由 `aui_select` 写入。
回调里应用把 `open` 置 0 后，要等下一次 build 才真正收起；因此同一帧内
紧接着的下一次点击仍会被当作模态处理（这与对话框一致，真实宿主每帧
都会重建）。测试里每次关闭后要先 `aui_frame` 再点下一次。

### D.31.5 边界

- 同时只展开一个；两个 `open != 0` 的 select 只有第一个生效（应用应
  用单个 `open` 字段管理）；
- 一屏放不下时不滚动，只显示前 `vis` 项；应用应控制选项数量，或改用
  页面；
- 浮层宽度跟触发器，不随最长选项变宽；超长选项文字按浮层宽裁剪；
- 浮层不参与滚动/分页/页面栈布局，滚动页面里展开时会浮在视口上，
  滚动本身被模态层挡住（需要先关闭）；
- 不做进出场动画；三角是三个矩形，不支持自定义图标；
- 对话框打开时 select 的浮层不显示，BACK 先给对话框。

### D.31.6 测试：dropdown_test 与 select_harness

`dropdown_test`（离屏 320×240、density 160、字体 scale 2）：

- 树：root/column + select 20 + 3 个 option + 底层按钮 30，共 7 个节点，
  展开前后不变；
- 触发器 `(8,8,304,48)`；展开后浮层 `(8,60,304,156)`，首项
  `(12,66,296,48)`；
- 首项选中：`(20,90)` 是 TINT `EDF1FA`，浮层下方仍是页面底色 `F6F6F8`；
- 命中：三个选项 21/22/23、触发器 20；空白 `(5,5)` 与 padding `(10,62)`
  分别是 -1 / -2；
- 点 padding 不关闭、不回调；点第二项 reason=1、下标 1，应用更新并
  关闭；重开点外部 reason=2、底层按钮计数不变；再点触发器 reason=2；
  BACK reason=3；关闭后底层按钮恢复可点；`aui_version() == 12602`。

`select_harness` 跑真实 `ui_select`（720×1280 假宿主）：

- 假窗口只有 720×1280，示例整页在 density 420 下放不下（深色开关在
  y≈1463），所以先把密度降到 240（480×853 dp），让三个下拉、汇总卡片
  和开关都进入视口；
- 打开 Language：浮层宽等于触发器、在触发器下方、不出屏；首行 TINT；
  节点数不变；
- 点 German：浮层关闭、节点数不变；重开后第 1 行不再是 TINT、第 2 行
  是 TINT；点外部关闭；
- Theme：展开后按 BACK 关闭；
- 深色：浮层 padding `1E1E24`、选中底色 `232A3D`；
- 最后把密度调回 420：Sort 触发器贴近底部，展开后浮层必须翻到触发器
  上方（`py + ph <= 触发器 y`）；
- 全程 `aui_version() == 12602`。

### D.31.7 版本、示例与边界

`ui_select.ast`（第 13 个 APK，`dev.aster.uiselect`）：三个下拉
（Language / Theme / Sort）+ 汇总卡片实时回显 + 深色开关。`open`
字段只存一个 key，`select_event` 按 reason 分支：0 展开、1 更新并
关闭、2/3 关闭。深色面板与选中底色都随主题变化。

`aui_version()` 12600，十三个 APK 以 versionCode 33 / 1.26.0 重打包，
qemu 32 项（30 个既有 + dropdown_test + select_harness）全过。真机验证
待用户安装 `uiselect.apk` 后提供截图/trace：第二行应为 `V00003138`；
展开/关闭时节点数 `N` 不变（选项始终在树里），但浮层展开后 `P`
（绘制命令数）会增加 4 + 选项数：浮层外框、内衬、每项文字，加上
选中项的 TINT 底色（真机 3 项：`P` 从 0x28 的 40 条涨到 0x2E 的 46 条）。
点选项/外部/BACK 后 `N` 不变、`P` 回落。

## D.32 v1.26.1：文本下伸部裁剪修复 + 中文选项

### D.32.1 问题与根因

用户真机截图（Theme=Dark，`V00003138`）里，触发器文字 “English” 的 g
下勾被水平切平。根因在文本命令的裁剪矩形：`cmd_add(2, tx, ty, w, gh)`
用 `text_glyph_h()`（字高，Latin48 为 48 px）作为命令高度，光栅化时
`draw_cmd_list_from` 直接把命令矩形当作文字裁剪框。Latin48 的 g/y/p
墨迹最多到行内 +58 px（行高 60），所以第 48 px 以下全部被裁掉。
浮层选项同样按 `ty + gh` 显式收窄裁剪框，问题一致。

### D.32.2 修法

保持文字位置不变（`ty` 仍按 `text_glyph_h()` 居中），只把**裁剪高度**
改成 `text_line_h()`：

- `emit_text_lines`（标签/按钮/标签页文字）：命令高度 `gh → lh`；
- `paint_field`、`paint_key`、`paint_check_text`：同上；
- `paint_select` / `paint_option`：显式裁剪底 `ty + gh → ty + lh`，
  文字命令高度同改。

行高正好贴到下一行，多行标签不会互相侵入；触发器高
`max(line_h + 20dp, 48dp)`、选项行高 48 dp，在当前密度下都容得下
60 px 行内墨迹。`select_harness` 增加回归点：密度 240 时在触发器
g 的第 35 行墨迹（文字顶 +54，老裁剪底 +48 之下）采样文字色，
返回码 34。

### D.32.3 示例：日语换中文

`ui_select.ast` 的语言列表第三项从 “Japanese” 改为 “中文”，摘要行
同步；示例嵌入 `font_cjk48.auf` 并在 `app_init` 调
`aui_set_fallback_font(g_cjk, 1)`。拉丁主字体缺的码点走 48 px 汉字
图集，行高/字高与 Latin48 同为 60/48，不改变布局。代价是
`uiselect.apk` 增大约 2 MB。

### D.32.4 验证

`aui_version()` 12601，trace 第二行 `V00003139`；十三个 APK
versionCode 34 / 1.26.1；qemu 32 项全过。截图重渲染：列表页触发器
g 下勾完整，Language 浮层第三项显示 “中文”，选中后汇总行回显
“中文”。

## D.33 v1.26.2：下拉手势归属 + 选项按下视觉

### D.33.1 真机 trace 里的两个问题

用户提供的长 trace 仍是 `V00003138`（1.26.0，尚未装 1.26.1），窗口
1216×2688、密度 3.25。整体健康：`N00000027` 恒定 39 节点，浮层开
`P` 40 → 46、关回来，深色切换、BACK `k00000004`、窗口重建都正常，
无崩溃。但有两组 DOWN/UP 坐标暴露了下拉的手势 bug：

- DOWN `x000002F9 y000003CB`（中文行）→ UP `x000003A3 y000002A3`
  （English 行），结果选中 English；
- DOWN `x00000314 y000005B2`（浮层外）→ UP `x0000039A y0000049D`
  （Dark 行），结果选中 Dark。

两次 DOWN 与 UP 相距约 91 dp。旧实现只在 `ACTION_UP` 做命中：UP 落在
哪个选项就选哪个，完全忽略 DOWN 目标，也没有 8 dp 拖动阈值。于是
“按下后滑动再松手”被当成点击，且从浮层外滑进来也能选中。

同一条 trace 里，按在非选中项上时 `P` 没有从 0x2E 再增加（选项没有
PRESSED 底色）。根因在 `aui_root()`：每次重建都把
`g_aui_select_press` 清成 -1；而 DOWN 命中选项后会 `aui_invalidate()`
触发重建，刚写入的按下下标立刻被抹掉，`paint_option` 永远看不到它。

### D.33.2 修法

- 新增输入状态：`g_aui_select_down`（DOWN 命中：-3 无 / -2 padding /
  -1 外部 / 节点下标）、`g_aui_select_dx/dy`（DOWN 像素坐标）、
  `g_aui_select_drag`。
- DOWN 在模态分支里记录以上状态；MOVE 在 `g_aui_select_open >= 0` 时
  只做拖动判定：`|dx|` 或 `|dy|` 超过 `dp2q(8) >> 16` 就置 drag、清
  press/pressing 并重绘，随后直接返回（不滚底层）。
- UP 先把 press 清掉，再看 drag 标志或实际位移：拖动则整次手势作废，
  不选中也不关闭；否则以 DOWN 的 `dec` 决定——padding 吞掉、外部/
  触发器 reason=2 关闭、kind 26 选项按 `dec` 的 `aux2` 选中。只有完全
  没有 DOWN（窗口重建后补发的 UP）才退回按 UP 位置判断，行为与旧版
  一致。
- `aui_root()` 不再清 `g_aui_select_press`；它由 DOWN（先清后设）、
  UP、CANCEL（action 3）与 BACK 关闭负责清除，只在浮层打开期间有效。

按下视觉因此恢复：非选中项 DOWN 后，重建仍保留按下下标，
`paint_option` 用 `theme_pressed()`（浅色 `E8EEFF` / 深色 `2A3550`）
画内衬底色，UP 选中后再换成选中项 TINT。

### D.33.3 回归与验证

`select_harness` 增加三条（版本断言 12602）：

- 返回 36：DOWN 在 German 上、重建后该行必须是 PRESSED `E8EEFF`，
  且浮层仍展开；随后抬起才选中并关闭。
- 返回 35：从 English 行拖到中文行，浮层保持展开，German 仍是选中项
  （TINT），中文行没有 TINT。
- 返回 37：从浮层外 `(5,5)` 拖进中文行，同样不选中、不关闭。

三条都先在有旧行为的临时实现上验证过会失败（36 / 35），再在新实现上
全过。`aui_version()` 12602，trace 第二行 `V0000313A`；十三个 APK
versionCode 35 / 1.26.2；qemu 32 项全过。

## D.34 v1.27：工具提示（Tooltip）

### D.34.1 对照 HuxerUI

HuxerUI 的 `tooltip.cpp` 把提示做成“修饰器 + 浮层”：目标控件或容器声明
提示文本与方向，指针按住一段时间后出现，不参与布局、不影响命中。AsterUI
沿用同一套语义，API 为：

```aster
aui_button(10, "Above", cb, user);
aui_tooltip("Above: tooltip above, center-aligned.",
            AUI_ANCHOR_ABOVE, AUI_TIP_ALIGN_CENTER);
```

- 挂载目标：最近创建的节点；如果刚 `aui_end()` 关闭了容器，则挂到该容器。
  这与 `aui_pad/gap/weight/align/bg/radius` 的修饰目标一致。
- `side`：`AUI_ANCHOR_ABOVE/BELOW/RIGHT/LEFT`；`align`：
  `AUI_TIP_ALIGN_START/CENTER/END`。越界值回落为上方/居中。
- 同一节点重复声明只覆盖不新增；每帧 `aui_root()` 清空登记表，最多 32 条。

### D.34.2 状态机与计时

| 状态 | 触发 | 行为 |
| --- | --- | --- |
| 空闲 | — | 无气泡、无计时 |
| 待定 | DOWN 命中带提示的节点（含祖先） | 快照文本/方向/对齐/锚点矩形，500 ms 计时 |
| 显示（按住） | 待定满 500 ms | 气泡进入布局与绘制，持有本次手势 |
| 停留 | 显示期间 UP/CANCEL | 1.5 s 后收起；多留 0.1 s 给最后一帧 |
| 取消 | 待定期间移动 > 8 dp | 回到空闲，不显示 |

细节：

- DOWN 先 `tip_dismiss()`（新按下收起旧气泡/待定），再命中测试；文本与
  锚点矩形在 DOWN 时固定，之后应用 rebuild 不影响正在显示的气泡。
- 待定期间 UP：按短按处理，不显示气泡，点击照常派发。
- 显示期间 UP：清 `g_aui_pressing/press_key`，本次抬起不触发按钮点击；
  `until = now + 1.6 s` 进入停留。
- BACK 在焦点/导航之前先收气泡，返回 1 表示已消费；`nav_changed`、
  `aui_dialog`、`aui_select` 打开时也调用 `tip_dismiss()`。
- `pump_ui` 每帧起点调用 `tip_tick()`；`tip_busy()` 让帧泵在待定/停留
  期间保持 16 ms 节拍，气泡出现与消失不依赖下一次输入。
- 气泡不是节点：节点数不变，只增加绘制命令；`hit_test` 完全不知道它。

### D.34.3 几何与配色

- 文本按 `min(320 dp, 内容宽 - 16 dp)` 换行，宽度 = 文本宽 + 16 dp，
  高度 = 行数 × 行高 + 8 dp，最小 24 dp；超出内容高时夹到可用高度。
- 默认上方居中：`y = ay - 4dp - h`，放不下翻到下方；下方也放不下时
  夹进内容区。右侧/左侧同理，反向放不下就翻到对侧，最后整体夹进
  `8 dp` 边距。水平/垂直对齐由 `tip_align_off` 计算。
- 气泡底色 `#1F2328`、alpha 240（94%），文字白色，内边距 8/4 dp，
  圆角 4 dp；绘制在对话框之后，属于最上层浮层。

### D.34.4 验证

`tooltip_test`（离屏 320×240、density 160）覆盖：

- 三处提示共存（按钮 / `aui_end()` 后的容器 / 底部标签），节点数不变；
- 300 ms 仍待定、510 ms 显示；按住抬起点击数为 0，停留 1.5 s 后消失；
- 短按照常点击且不显示；按住移动超过 8 dp 取消；
- 容器提示默认下方 4 dp、start 对齐；底部目标下方放不下翻到上方并夹在
  8 dp 边距内；右侧/start 与左侧/end 的锚点关系；BACK 只收气泡；
- 气泡深色底与白色文本像素。

`tooltip_harness`（`ui_tooltip`，720×1280、density 420）走真实宿主路径：
长按 Above 按钮在 520 ms 后出现上方气泡（4 dp 间距、居中或夹边距），
抬起不点击、停留后消失；短按照常点击；容器气泡贴容器、start 对齐；
底部提示 end 对齐；BACK 只收气泡；`aui_version() == 12700`。

### D.34.5 多行换行一致性（开发中修复）

第一个版本的测量与绘制用了两个不同的换行宽度：`tip_layout` 按
`min(320 dp, 内容宽 - 16 dp)` 换行并把气泡宽度定为“最长行 + 16 dp”；
`paint_tooltip` 却用气泡内宽（即最长行宽）重新换行。只要某一行恰好
用满最大宽度、后面紧跟一个空格，绘制时这个空格就会触发“在行内最后
一个空格处折行”，把本已放下的词挤到下一行，行数比测量时多；气泡高度
仍按旧行数计算，最后一行被裁掉。320 dpi 截图里
“Above: tooltip above, center-aligned.” 就只剩前两行。

修复：`tip_layout` 把实际使用的最大文本宽存进 `g_aui_tip_tw`，
`paint_tooltip` 用同一个宽度换行，两次 `layout_text` 得到完全相同的
行。新增 `aui_debug_tooltip_lines()` 返回最近一次布局/绘制的行数；
`tooltip_test` 场景 3 用 “Multiline tooltip text must wrap identically
in layout and paint.” 断言 `气泡高 == 行数 × 20 + 8`（返回码 26）。
该断言在旧实现上返回 26，新实现通过。同批修正里，`ui_tooltip` 的
Clicks 状态文案缩短为 “no click” / “button tap”，避免 320 dpi 下
横向挤出卡片。

测试侧的两个注意点（都曾在开发中造成误判）：

- 同一个长按辅助函数被多个阶段复用时，不能在里面断言“命中的一定是
  第一个按钮”；各阶段的目标节点不同，命中下标与 `find_tip` 结果也不同。
- `aui_tooltip` 挂的是“最近创建的节点”。在 `aui_label(42, ...)` 之后又
  创建了 spacer 再声明提示，会挂到 spacer 上，按标签自然什么都命中不到；
  声明要紧跟目标节点（或紧随容器的 `aui_end()`）。

`aui_version()` 12700，trace 第二行 `V0000319C`；十四个 APK
versionCode 36 / 1.27.0；qemu 34 项全过。

## D.35 v1.28：日期选择（DatePicker）

### D.35.1 对照 HuxerUI 与 API

HuxerUI 的 `date_time_picker.cpp` 是“表头 + 7 列网格”的月历：左右箭头
换月、点标题切 4×5 年视图直接选年。AsterUI 这一版只做日期，时间留给
后续的 TimePicker：

```aster
extern fn aui_date_picker(key: i32, y: i32, m: i32, d: i32,
                          cb: fn(ptr) -> i32, user: ptr) -> i32;
extern fn aui_date_min(y: i32, m: i32, d: i32) -> i32;
extern fn aui_date_max(y: i32, m: i32, d: i32) -> i32;
extern fn aui_date_week_start(wd: i32) -> i32;
extern fn aui_date_selected(key: i32, out: ptr) -> i32;
```

`aui_date_picker` 每次 build 传入应用侧当前值，库内按 key（容量 8）记住
可见年月、月/年视图、范围与每周首日。应用值变化时置 `init` 标记，下一次
布局把可见月份回中到选中月；越界值先夹紧再回中。因此应用不需要自己
维护“翻到哪个月”这类瞬态状态，rebuild（切深色、窗口重建）也不会把用户
翻到的月份弹回去。`aui_date_min` / `aui_date_max` / `aui_date_week_start`
是声明式修饰器，只作用于最近创建的日期选择器，每次 `aui_date_picker`
调用时先恢复默认（`1-1-1..9999-12-31`、周日开头），所以要在每次 build
里紧跟其后调用。`aui_date_week_start(1)` 改为周一开头，其它值按 7 取模。

回调只在“选中日真的变化”时触发一次：换月、切年视图、选年、重复点同一天
都不回调。回调里用 `aui_date_selected(key, out)` 读回 `[y,m,d]` 三个 i32
（应用也可以直接记下点中的日期参数）。选中日被 min/max 夹紧时同样不
回调——夹紧是应用传值出错时的兜底，不是用户操作。

### D.35.2 日期换算与网格

不依赖标准库，全部用 i32 做 Hinnant civil-days 算法：

- `date_days(y,m,d)` → 纪元日（1970-01-01 = 0），`date_civil(days)`
  写回 `g_aui_date_cy/cm/cd`；
- `date_dim(y,m)` 返回 28/29/30/31，闰年规则完整；
- `date_weekday(days) = mod(days + 4, 7)`，周日 = 0；
- `date_parse(y,m,d)` 把年夹到 1..9999、月夹到 1..12、日夹到
  1..当月天数——2024-02-31 会变成 2024-02-29，不会溢出到 3 月；
- 网格首格偏移 `mod(weekday(当月 1 日) - week_start, 7)`，42 格里的
  前后邻月日期照常显示（置灰），点中会跳到相邻月并选中；
- min > max 时自动交换，避免空范围。

范围判定按“整格日期”而不是可见月份：范围外的日子置灰且命中返回 -1；
只有当上一月/下一月的**整月**都落在范围外时，箭头才不生效。年视图同理，
按年与 min/max 的年份比较。

### D.35.3 几何与两套视图

节点默认 `pad = 12 dp`、`gap = 2 dp`、圆角 12 dp，可被 `aui_pad/gap/
radius` 覆盖。内部几何（`date_geom`）：

- 表头高 44 dp；格宽 `cell = (宽 - 6×gap) / 7`，上限 36 dp；网格整体
  水平居中（`gx`）；
- 节点高 = 上下 pad + 表头 + 7 行格 + 6 个 gap；第一行是星期名，
  下面 6 行是日期；
- 年视图 4 列 × 5 行，共 20 年；列宽 `colw = (gw - 3×gap) / 4`（比日格
  宽，形成横条），行高仍用 `cell`；首行 y 与日网格首行相同
  （`year_y = weekday_y + cell + gap = day_y`），因为 5 行比 7 行矮两行，
  这样上下留白相等；
- 表头点击区按左/中/右三等分：左右各一个 44 dp 方形箭头区，中间是
  标题；按下时对应区域画 PRESSED 圆角底；
- 选中日/年画主色胶囊（半径 = cell/2），文字用 on_primary；范围外
  日期用 hint 色；范围外年份同样用 hint 色。

标题文本是“Oct 2026”或“2020-2039”，箭头是 `<` / `>`，都写进每个
slot 独立的 512 B 文本区（标题 32 B、42 个日期 4 B、20 个年份 8 B），
不占节点树、不做堆分配。

### D.35.4 手势与冲突

日期块内部全部自己处理命中，不注册子节点：

- DOWN 记录 `(key, 目标)`，目标编码为 0 上月 / 1 标题 / 2 下月 /
  10..51 日格 / 100..119 年格；
- MOVE 位移超过 8 dp 即取消激活（`g_aui_date_drag`）并清掉按下态，
  后续 UP 不选中，让滚动/分页接管；DOWN 时同时登记 pager 候选，
  所以在日历上横滑仍能翻页；
- 只有同一目标上的 UP 才生效；UP / CANCEL / BACK 都会清掉按下态。

### D.35.5 字符串字面量的链接坑

月份名、星期名、箭头最初写成字符串字面量，结果所有“示例 + 库”的
`link-obj` 都报 `duplicate global symbol '__aster_string_0'`。原因是
`link-obj` 只按目标文件拼接符号，不像 `link-so` 会重命名 `__aster_string_N`；
库和示例各有一份字面量就撞名。修法：库里不放任何字面量，月份/星期/
箭头在首次绘制时写进全局字节表（`g_aui_date_mon[48]`、`g_aui_date_wd[28]`、
`g_aui_date_arrow[4]`，`date_names_init()` 只执行一次）。现在
`aui_impl_nopic.o` 的 `readelf` 里没有任何 `__aster_string` 符号。

### D.35.6 验证

`date_picker_test`（离屏 360×700、density 160）覆盖：

- 默认 2026-10-15：块 360×332、格 36 dp、表头 44 dp、网格首格
  2026-09-27、15 日下标 18；白色卡面、1 px 边框、标题/表头墨迹、
  选中胶囊的主色与白字像素；
- 箭头换到 11 月；标题进年视图（2020-2039，2020-2023 与 2028+ 置灰），
  点 2030 回 10 月；选 2027-01-01 回调一次，重复点不回调；点相邻月
  9 月 27 日跳月并选中；按下后拖 8 dp 松手取消；
- 范围 2026-10-10..2026-11-20：9/21 日置灰不可点，9 月与 12 月的
  箭头被挡住，选 11-05 回调；周一开头首格 2026-09-28、15 日下标 17；
- 夹紧与归一化：传 2024-01-05（早于 min）夹到 2026-03-10 并显示 3 月；
  2024-02-31 归一化为 02-29（闰日下标 32）；4 月超过 max 的日期置灰；
  两个 key 的可见月份互不影响。

`date_picker_harness`（`ui_date`，720×1280、density 420）走真实宿主：
日期块 573×688 px、格 68 dp；右箭头到 2026-11，标题进年视图后点 2025
回到 2025-11；点 2025-11-10 后状态 901 回读 20251110、回调 1 次，
重复点仍 1 次；切深色后卡片亮度骤降、切回恢复；`aui_version() == 12800`。

`aui_version()` 12800，trace 第二行 `V00003200`；十五个 APK
versionCode 37 / 1.28.0；qemu 36 项全过。

## D.36 v1.29：时间选择（TimePicker）

### D.36.1 对照 HuxerUI 与 API

HuxerUI 的 `date_time_picker.cpp` 把日期与时间放在同一个文件：时间部分
是“时 : 分”表头（12 小时制再加 AM/PM 组）加一个圆表盘，选时/选分用
同一个表盘切换标签。AsterUI 的 v1.29 按同一骨架实现：

```aster
extern fn aui_time_picker(key: i32, hour: i32, minute: i32,
                          cb: fn(ptr) -> i32, user: ptr) -> i32;
extern fn aui_time_step(minutes: i32) -> i32;
extern fn aui_time_12h(on: i32) -> i32;
extern fn aui_time_selected(key: i32, out: ptr) -> i32;
```

`aui_time_picker` 每次 build 传入应用侧当前时刻（0..23 / 0..59，越界
夹紧），库内按 key（容量 8）记住“选时/选分”“12/24 小时制”“步长”和
每个 slot 256 B 的文本区。`aui_time_step` 只接受 1..60 且整除 60 的
分钟数（否则返回 -1），`aui_time_12h(1)` 打开 12 小时制；二者是声明式
修饰器，作用于最近创建的时间选择器，每次 `aui_time_picker` 先把步长
恢复 1、12 小时制恢复关，所以要在每次 build 里紧跟其后调用。

与 HuxerUI 一致，**受控值不强制吸附**：step=15 时传入 10:07 会原样
显示，只有点/拖表盘才把角度四舍五入到 15 的倍数。这样库内值和应用值
不会在 rebuild 时悄悄分叉；应用要初始吸附就自己取整后再传入。

回调只在值真的变化时触发一次；重复点同一角度、点 AM/PM 已选中的一半、
切换字段都不回调。回调里用 `aui_time_selected(key, out)` 读回
`[hour, minute]` 两个 i32。

### D.36.2 几何与表盘

内部几何与 HuxerUI 的 Material 默认值一致：`pad = 12 dp`、表头 52 dp、
时/分字段各 64 dp、冒号 16 dp、AM/PM 组宽 44 dp、组间距 8 dp、
内容间距 16 dp、表盘直径至多 208 dp，圆角 12 dp。表头总宽
`64×2+16 (+8+44)`，连同表盘在内容区里水平居中；表盘直径取
`min(208 dp, 内容宽)`，所以窄卡片里表盘会缩小，节点高也随之为
`pad×2 + 52 + 16 + 直径`。纵向容器里撑满可用宽度；在行/栈里保持
固有宽 232 dp。

24 小时制表盘画 24 个标签：外圈 1..12（12 在正上方），内圈 00 与
13..23，半径分别是 0.78R / 0.52R；12 小时制只画一圈 1..12，AM/PM
由表头右侧的两段组控制。分钟表盘每 5 分钟一个标签（00..55），
选择点仍然按 1 分钟插值，手柄指向精确分钟。

手柄没有画线原语，用 128 个 2 dp 小圆点从表心连到选择点（64 个点时
在 160 dpi 下点与点之间会露抗锯齿缝，128 个点完全覆盖）；中心再画
一个 2 dp 圆点；选择点画 14 dp 主色圆，选中标签再用圆角胶囊托底，
数字用 on_primary。长标签（如 12 小时制的 “12”）胶囊按文本宽扩展，
最短 28 dp，和 HuxerUI 的 `max(text, selection_radius*2)` 一致。

24 小时制在 160 dpi + 8×8 测试字体下内圈 “23 00 13” 会挨得很近，
这是双圈 24 标签在小直径表盘上的固有密度；420 dpi 的比例字体下
内圈中心间距约 147 px、两个数字宽约 46 px，实际示例里没有重叠。
保留双圈而不改成两页，是为了与 HuxerUI 的 24 小时表盘一致。

### D.36.3 角度计算（开发中修复）

没有浮点/三角函数，角度用八分区 + 45° atan 查表：

- 12 个 30° 单位向量预计算成 Q16.16（`(0,-65536)`、`(32768,-56756)`…），
  分钟选择点在这 12 个向量之间按 `m%5/5` 线性插值；
- `time_angle` 按 `(|dx|,|dy|)` 与象限分八区，`t = minor/major` 取
  Q16.16，用 9 项 atan 表（0°..45°，单位是“分钟”的 1/60 圈）线性插值；
- 结果满圈 3,932,160 = 60×65536，`time_round_div` 四舍五入到 60 或 12 份。

开发中首版把八个分区都写成“45° + atan(短/长)”，其中 1/3/5/7 区实际
应从 45° 往 90°/180°/270°/360° **回退**，导致右上方 10 分钟位置被算成
75 分钟。现在奇数区用 `45° - atan(...)`，测试里 05/10/25 分、外圈
12/9 点、内圈 00/13 全部通过。24 小时制内圈判定用距离阈值
`d² < (0.66R)²`；内圈 12 点位置是 00，其余 k 映射到 13..23；外圈
12 点位置映射到 12。

### D.36.4 手势与冲突

- DOWN 记录 `(key, 目标)`：0 时字段 / 1 分字段 / 2 AM / 3 PM /
  10 表盘；头部只记录目标，表盘立即捕获本次手势并取值；
- 表盘捕获后 MOVE 连续 `time_dial_apply` 并吞掉事件，父滚动容器不能
  抢手势；头部 MOVE 超过 8 dp 取消目标，继续走分页/滚动分支；
- UP 时表盘做最后一次取值；如果仍在选时态，自动切到选分（HuxerUI
  的 `SetMode(Minute)` 行为）。字段/AM/PM 只有 UP 在同一目标上才激活；
- CANCEL、BACK、长按提示的 UP 都会清掉时间按压状态。

### D.36.5 验证

`time_picker_test`（离屏 360×700、density 160）覆盖：

- 09:30 / 24 小时制：块 360×300、表心 (180,184)、半径 104、表头 52；
  选中字段主色、另一字段 tint、表盘 tint、手柄与选中胶囊像素；白字
  计数；字段切换不回调；
- 分钟表盘：05 分 -> 09:05 回调 1 次；拖到 10 分连续更新；松手不切回
  选时；23/24/25 分逐点回读，24 分时 5 dp 圆头手柄不覆盖 25 分标签
  （v1.29.1）；
- 选时表盘：外圈 12 -> 12:10 且松手自动进选分；内圈 00 -> 00:10；
  外圈 9 点 -> 09:10；
- 12 小时制：21:30 下 AM/PM 高亮，点 AM -> 09:30、点 PM -> 21:30，
  各回调一次；12 点/9 点表盘刻度正确；
- 步长 15：受控 10:07 原样显示；10 分角度吸附到 15、25 分吸附到 30；
  非法步长 7 返回 -1；
- 双卡 key 100/101 互不影响；深色主题像素；应用侧值始终由回调更新。

`time_harness`（`ui_time`，720×1280、density 420）走真实宿主：
选择器 573×751 px、表盘半径 255 px；点分字段后点 05 分回读 905，
拖到 10 分回读 910 且回调 ≥2 次；选时点外圈 12 -> 1210 并自动进
选分；开 12 小时制后 AM/PM 把 12:10 在 00:10 与 12:10 之间切换；
24 小时制内圈 00/13 正确；开步长 15 后 10 分角度吸附到 13:15、25 分
到 13:30；深色卡片亮度骤降；页面底部 1280 内。

`aui_version()` 12900，trace 第二行 `V00003264`；十六个 APK
versionCode 38 / 1.29.0；qemu 38 项全过。

## D.37 v1.29.1：时间表盘“偏移”修复

真机截图反馈选中 20:23 / 20:24 / 20:25 时手柄“有偏移”。复现与定位：

- 角度计算本身正确：在 520 dpi（1216×2688 窗口）下逐点点击
  00/05/.../55 与 23/24 分，`time_angle()` 回读的分钟全部精确；
  520 dpi 渲染的 23 分手柄中心测得 138.1°（期望 138.0°，即 23.02 分）；
- 视觉问题来自尺寸：表盘半径 104 dp，0.78R 上 1 分钟弧长约 8.5 dp，
  而选中圆直径 28 dp，约占 3.3 分钟。画在 23/24 分时它必然压住相邻
  的 25 分标签；标签又在手柄之后绘制，于是白色“25”落在大圆里，看起来
  像选中了 25。23/24 分与用户的三张截图正好对应这个区间；
- `ui_time` 示例还有一处布局偏移：`aui_weight(1)` 写在了 12h 开关
  之后，作用对象是开关本身（`modify_target()` 是最近创建的节点），
  把开关从 48 dp 拉到约 78 dp，并把右侧 15m 组挤到边缘。

修复：

- `paint_time` 仅在分钟正好等于 5 分钟标签（`m % 5 == 0`）时画
  14 dp 选中圆——此时它与 28 dp 标签胶囊重合；其余分钟只画 5 dp
  圆头手柄。圆心仍由 `time_sel_point()` 按精确角度计算，取值语义
  完全不变；
- 示例选项行改为 `aui_spacer(16, 0); aui_weight(1);`，weight 落在
  空位上，两个开关同宽、15m 右对齐；
- 测试：`time_picker_test` 增加 23/24/25 分回读、24 分手柄中心像素
  与“旧 14 dp 圆覆盖点应回到 tint”的断言；`time_harness` 增加同样
  的分点回读、手柄像素断言，以及 `aui_debug_rect(26/27)` 同宽断言。

`aui_version()` 12901，trace 第二行 `V00003265`；十六个 APK
versionCode 39 / 1.29.1；qemu 38 项全过。

## D.38 v1.30.0：下拉刷新（RefreshBox）

### D.38.1 对照 HuxerUI 与 API

HuxerUI 的 RefreshBox 把内容放在一个可下拉容器里：顶部继续下拖时内容
跟手下移，松手超过阈值触发刷新，指示圈收进固定刷新位旋转。AsterUI
保留这套观感与常量，去掉浮点与 Java 动画对象：

| 项 | 值 | 说明 |
|---|---|---|
| 阻尼 | 0.45 | 原始下拉距离 × 45% 变成内容位移 |
| 最大下拉 | 96 dp | 超过部分不再下移 |
| 触发阈值 | 68 dp | 松手时位移 ≥ 68 dp 才回调 |
| 刷新位 | 52 dp | 触发后收进 52 dp 旋转 |
| 反馈窗口 | 700 ms | 回调后至少转这么久，应用可在此期间把 refreshing 置 1 |
| 收起动画 | 200 ms ease-out | 不足阈值 / refreshing 清 0 |
| 容器 | 36 dp 圆 | surface 底，随位移渐显 |
| 指示器 | 20 dp 环 / 3 dp 笔画 | 轨道 on_surface 16%，弧线 primary |
| 不定量弧 | 28% 圆 | 900 ms 一圈 |

公共 API：

```aster
aui_refresh_box(key, refreshing, cb, user)   // 内容唯一子节点；key > 0
```

`refreshing` 由应用持有；回调里可以先保持 0，库会用 700 ms 反馈窗口
完成一次可见的刷新动画，也可以在回调里置 1 并等异步完成后再清 0。
测试辅助为 `aui_debug_refresh`（当前位移 px）、`aui_debug_refresh_state`
（0 空闲 / 1 下拉 / 2 旋转 / 3 吸附）、`aui_debug_refresh_phase`
（0..65535）。容量 16 个 key，和分页/动画槽一样是固定数组。

### D.38.2 位移模型与状态

滚动偏移继续使用 `scroll_get/set/max`，刷新容器只多一个
`g_aui_ref_disp`。手势开始记录 `off0 = scroll_get(key)`；MOVE 时：

```
desired = off0 - dy * 65536
  desired >= 0 : 普通滚动（夹到 max），同时清掉下拉位移
  desired <  0 : 滚动归 0，disp = min((-desired) * 45 / 100, 96 dp)
```

这样“先上滑离开顶部、再下拖回到顶部、继续下拖”会无缝从滚动切到下拉，
不需要额外的方向判定。`ref_set_disp` 直接写入位移；动画进行中的手势
会先清 `g_aui_ref_anim`，避免两个来源同时改同一个值。

状态机：

- **下拉**：位移来自手指，`state = 1`；
- **旋转**：`g_aui_ref_on`（应用 refreshing）或 `g_aui_ref_ack`
  （700 ms 反馈窗口）非 0，`state = 2`；每帧相位增加
  `dt × 65536 / 900 ms`，单帧 dt 夹在 32 ms，避免后台回来后跳一大圈；
- **吸附**：`g_aui_ref_anim` 非 0，200 ms ease-out 到目标；`state = 3`；
- **空闲**：位移 0 且无动画。

`ref_sync` 在每次 build 时比较应用传入的 `refreshing` 与上一帧：
0→1 收进 52 dp（150 ms），1→0 清掉反馈窗口并收起。回调触发时
`ack = now + 700 ms`；窗口到期后 `ack = 0` 并开始 200 ms 收起。
因此应用完全不处理异步也能看到完整的“转一圈再收回”。

### D.38.3 绘制

`paint_refresh` 在子树绘制之后执行，内容下移由 `arrange_refresh`
完成（`cy = n.y + n.pad - off + disp`）。指示器：

- 容器圆心 `cy = n.y + disp - 18 dp`，直径 36 dp；用圆角矩形
  `radius = size / 2` 画圆，颜色 surface，alpha 按 `disp / 36 dp`
  渐显；
- 轨道半径 `20/2 - 3/2 = 8.5 dp`，36 个 3 dp 圆点，颜色 text
  16% alpha 再乘显示比例；
- 弧线：旋转态占 28%，起点为相位；下拉态占 `disp / 68 dp`，
  从 0 点开始长出来；仍用 36 个圆点，步长 1/36 圈，最后一颗对齐。

没有 arc 原语，圆点法与时间表盘手柄一致；36 点在 20 dp 环上相邻圆心
间距约 1.5 dp，3 dp 笔画足以连成平滑弧线。

比例计算必须先降到像素：`disp` 与 `size` 都是 Q16.16，直接写
`disp * 65536 / size` 在位移超过约 0.5 px 时就会 i32 溢出，alpha 变成
0，整圈看起来完全没画。现在用 `dpx = disp / 65536`、
`spx = size / 65536` 后再算 `ca = dpx * 255 / spx`；弧长同理用
`dpx * 65536 / (68 dp 的像素数)`。测试也改为扫描主色弧线像素，而不是
只看背景亮度——深色背景本来就暗，亮度断言会把漏绘放过去。

### D.38.4 手势与冲突

- `find_scrollable` 同时认 kind 9 和 29，命中节点向上找最近的可滚动
  祖先；DOWN 时刷新容器记录 `g_aui_ref_drag_key`、起点 y 与 off0；
- 移动超过 8 dp 才进入拖动，清掉按钮按压；不足 8 dp 的抖动不改变位移；
- 刷新容器的回调不是点击目标：`find_clickable` 跳过 kind 29，否则
  容器空白处的 UP 会误触发刷新；
- UP 只在“本次手势真的产生过下拉位移”（`moved != 0` 且 disp > 0）时
  结算；指示器已经停在 52 dp 时普通点按会照常落到行按钮上；
- 不足阈值 settle 到 0；达到阈值且未在刷新、无反馈窗口时回调一次并
  收进 52 dp；应用 refreshing 已为 1 时保持不动；反馈窗口内松手只
  吸附，不重复回调；
- 没有下拉位移但拖动过（例如上滑）沿用普通 fling；CANCEL 收起；
  BACK、页面切换、对话框等上层逻辑不变。

### D.38.5 帧泵

刷新动画并入统一的 `refresh_busy()`：`aui_frame` 在没有 fling/转场/
动画/分页时，只要还有刷新位移或反馈窗口就继续用 `clock_ns()` 推进；
`pump_frame_once` 的激活条件、空闲停帧、帧定时器 arm/sync/disarm、
`fling_stop` / `anim_step` / 页面结束清理也都把它算进去。测试里则用
`aui_debug_set_time` + `aui_frame(t)` 显式推进，保证离屏与真实宿主
走同一条路径。

### D.38.6 验证

`refresh_test`（离屏 360×700、density 160）覆盖：容器几何与初始状态、
空白区点按不误触、行按钮点击、100 px→45 dp、96 dp 上限、68 dp 阈值、
回调一次、52 dp 刷新位、相位推进、700 ms 后收起、应用 refreshing
保持与清除、上滑滚动/回到顶部不混入位移、深色背景与指示圈内的主色
弧线像素。
`refresh_harness`（`ui_refresh`，720×1280、density 420）走真实宿主：
点行计数、200 px 下拉不触发、900 px 超长下拉回调并收在 136 px、相位
旋转、反馈结束归零、上滑偏移 >250 px、回滚到顶部、深色页面与容器
采样，并在指示圈范围内扫到主色弧线像素（而不是只测背景亮度）。

`aui_version()` 13001，trace 第二行 `V000032C9`；十七个 APK
versionCode 41 / 1.30.1；qemu 40 项全过。

### D.38.7 v1.30.1：长距离下拉的定点溢出

真机 trace（`V000032C8`，1216×2688 / density 3.25）在一次长下拉里
记录到位移由 `R0134B333`（308.7 px）突然变成 `RFEC30A3E`（约
-315.9 px）。原因在 MOVE 分支：

```
let rd: i32 = (0 - rdes) * 45 / 100;   // 旧
```

`rdes` 是 Q16.16，`0 - rdes = dy × 65536`。dy 超过约 728 px 后
`× 45` 越过 i32 上限，结果回绕成负数；位移写成负值后指示圈立即消失，
UP 又把这次手势当普通 fling，列表会自己滑一段。改为先减后除再乘：

```
let rm: i32 = 0 - rdes;
let rd: i32 = rm / 100 * 45;           // 新；再夹到 96 dp
```

截断误差小于 0.01 px，观感不变。`refresh_test` 增加 dy=1000 px 用例
（density 160 下同样越过 728 px），断言 `g_pull` 落在 90..96 dp、
只回调一次；`refresh_harness` 的触发用例从 500 px 改为 900 px
（density 420 下 900 px 也越过溢出边界），其余断言不变。

## D.39 v1.31.0：标签片（Chip）

### D.39.1 对照 HuxerUI 与 API

HuxerUI 的 `DefaultChipStyle` 是：水平/垂直 padding 16/4，最小高度
28 dp，圆角 14 dp；未选 surface 底 + `on_surface` 24% 的 1 dp 描边，
选中主色底 + `on_primary` 文字且不画边框；标签单行不换行、水平垂直
居中；`selected` 由调用方控制，点击发出 `Changed(!selected)`。
AsterUI 对应 API：

```
aui_chip(key, text, selected, cb, user)
```

和开关/复选/单选一样，控件不持有状态：点按只调 `cb(user)`，应用翻转
自己的 `selected` 后 `aui_invalidate()`。单选组的互斥、多选位掩码都由
应用维护，库不收集组信息。节点类型 30，`aux2` 存 0/1 选中位。

### D.39.2 尺寸与布局

`measure_chip` 给固有尺寸：

```
w = text_measure(text, 0) + 2 × 16 dp
h = max(28 dp, text_line_h() + 8 dp)
```

文字测量传 `maxw = 0`（不换行），`n.pad = 16 dp` 同时用于左右留白和
`emit_text_lines` 的内宽，因此内宽正好等于文字宽，不会折行。控件在
行里并排；在 column / root / scroll 里**不拉伸**，按固有宽左对齐——
这与复选框（纵向容器里撑满整行、便于整行点击）是刻意不同的取舍。
圆角固定 14 dp，28 dp 高时就是胶囊；字体行高较大时保持 14 dp 圆角。

### D.39.3 绘制

选中：

```
cmd_add(1, x, y, w, h, primary, radius)
emit_text_lines(... on_primary, center=1 ...)
```

按下时填充换成 `primary_dark`。未选时没有描边原语，沿用输入框/复选框
的做法：

```
cmd_add(1, x, y, w, h, ref_alpha(theme_text(), 61), radius)       // 24% 边框
cmd_add(1, x+1dp, y+1dp, w-2dp, h-2dp, surface, radius-1dp)       // 挖空内层
```

按下未选时内层换成 `theme_pressed()`。文字用 `emit_text_lines` 的
`center=1`，`ytop = y + (h - line_h)/2` 垂直居中；颜色随选中态切换。

### D.39.4 输入与状态

Chip 是普通叶节点：`find_clickable` 认 `cb != 0 && kind != 29`，DOWN
时写 `g_aui_pressing / g_aui_press_key`，绘制读它显示按下态；UP 在同一
节点上松手才调用 `cb(user)`。没有内部选中状态，重建树不会丢失应用
状态。命中区域就是整枚胶囊，没有额外扩大热区。

### D.39.5 验证

`chip_test`（离屏 320×240、density 160、8px 字体 2 倍）覆盖：
节点/命令计数；"All" 80×28、"Off" 80×28、列内 "Hi" 64×28；列内
宽度不随可用宽变化；选中主色、未选 surface 内层与 24% 描边像素；
选中白字 / 未选深字；点未选项切换选中且回调一次；点回已选项；
按下未选时内层变 pressed；深色下选中主色与未选 surface 换色；
未知 key 返回 -1；版本号 13100。

`chip_harness`（`ui_chip`，720×1280、density 420）走真实宿主：
筛选行三枚同高、8 dp 间隔；初始 All 选中；点 New / Flag 切换筛选
状态（950）；Wi-Fi 多选位开关两次（951）；NFC 位为 4；列内 Chip
保持固有宽；深色背景变暗且选中主色 / 未选 surface 一起换色。

`aui_version()` 13100，trace 第二行 `V0000332C`；十八个 APK
versionCode 42 / 1.31.0；qemu 42 项全过。

## D.40 v1.32.0：环形进度（ProgressCircle）

### D.40.1 对照 HuxerUI 与 API

HuxerUI 的 `DefaultProgressCircleStyle` 是：直径 24 dp、描边 3 dp、轨道
`on_surface × 0.16`、指示色 primary、不确定进度固定 0.28 弧、周期
`slow × 3`（900 ms）。本版照此实现，API 只有三个参数：

```
extern fn aui_progress_circle(key: i32, value: i32, size: i32) -> i32;
```

`value` 是千分比 0..1000（大于 1000 夹紧）；`value < 0` 表示不确定进度。
`size` 是直径 dp，0 → 24 dp，夹在 8..240。描边 = max(1, size/8) dp，
24 dp 时正好 3 dp，与 HuxerUI 一致。控件是**固有正方形**，与标签片
一样不撑满列宽；列里需要居中/右对齐时由应用用 `aui_align(1/2)` 指定。
控件不接收点击（`cb` 永远为 0），只是显示。

### D.40.2 尺寸与布局

节点类型是 31。`aui_progress_circle` 把值写进 `aux`、直径 dp 写进
`aux2`；值 < 0 时累加 `g_aui_spin_live`，供帧泵判断本帧是否有动效。
`measure_circle` 直接令 `w = h = dp2q(size)`，高度即测量结果。与进度条
（横向、撑满列宽）不同，环形是固定正方形，因此行里并排、列里左对齐，
需要居中时用 `aui_align`。

### D.40.3 绘制：点阵圆环

光栅器没有圆弧原语，只有矩形与圆（`cmd_add(1, ..., radius = 半宽)`）。
环形用 72 个圆点拼——每个点直径等于描边，圆心落在半径
`r = size/2 - stroke/2` 的圆周上：

```
a = i * 65536 / 72                    // Q16.16 角度，0 = 12 点，顺时针
(cx,cy) + r * ref_uv(a)
```

`ref_uv(a)` 在 12 个锚点间线性插值（表项 0 = 向上，顺时针每 30°）。
锚点之间只是直线插值，直接拿来铺点会让 72 个点落在 12 边形的边上，
肉眼能看到 30° 一个拐点。`ref_ring_dot` 因此把插值出的向量归一化到
Q16.16 单位长度：先除以 4 再 `isqrt` 避免 Q32 平方和溢出 i32，结果乘 2
回到 Q16.16，再 `fx_mul(r, u)` 求坐标。归一化后 72 个点落在真圆上。

轨道不能直接用半透明的 `on_surface × 16%`：72 个点相互重叠，半透明
叠加会让交叠处越叠越深，轨道出现斑点。做法是先用 `mix_bg` 把
`theme_text()` 以 16% 压到**当前绘制底色** `g_aui_paint_bg` 上，得到一个
不透明色再画点。深色主题下这个合成值自动跟随背景。

确定进度从 12 点起画 `span = value/1000 × 65536`，按 72 份切分、向上
取整得到点数（至少 1 个，最多 72），再把 `span` 均分给这些点，保证
100% 时首尾点正好闭合。不确定进度取固定 28% 弧，起点是当前相位。

### D.40.4 帧泵与相位

不确定进度不需要应用定时器：`refresh_busy()` 在末尾加上
`g_aui_spin_live`，于是现有的帧泵（`aui_frame` / `frame_timer_sync`）
会自动请求帧。`spin_phase_at(t)` 用假时钟友好的 `anim_now()` 算
`ms mod 900`，映射到 0..65535；`spin_step(t)` 在相位变化时置
`g_aui_need_paint`，绘制时 `spin_phase_now()` 再按同一公式取相位，
所以离屏测试只要把注入时钟拨到 450 ms 就能断言相位为 180°。

### D.40.5 验证

`progress_circle_test`（离屏 320×240、density 160、8px 字体 2 倍）
覆盖：5 个并排 40 dp 圈的矩形与 24 dp 默认尺寸；0% 不出现 primary；
25% 顶部/右侧有 primary、底部是轨道；100% 左侧有 primary；不确定进度
初始 12 点有 primary、底部轨道；注入 450 ms 后顶部变轨道、底部变
primary；50% 与 1500%（夹紧满分）；96 dp 大圈的描边与相位；深色下
primary 换成 `6E96FF`；未知 key 返回 -1；版本号 13200。

`progress_circle_harness`（`ui_progress_circle`，720×1280、density 420）
走真实宿主：三个 48 dp 圈同高、间距与水平居中；状态初值 600；受控圈
顶部 primary；点 "+25%" 后状态到 850 且弧扫到左侧；默认 24 dp 圈为
63 px；不确定圈 `aui_debug_spin_phase()` 为 0，拨 450 ms 后为 32768；
深色背景变暗、primary 变 `6E96FF`。所有采样点先做几何边界检查，
避免示例布局超出 1280 px 时读到帧缓冲外。

`aui_version()` 13200，trace 第二行 `V00003390`；十九个 APK
versionCode 43 / 1.32.0；qemu 44 项全过。

## D.41 v1.32.1：环形进度的抗锯齿（op 4 解析圆环）

### D.41.1 问题

v1.32.0 的环由 72 个直径 = 描边的圆点沿圆周铺成。每个圆点自身有覆盖率
抗锯齿（`fill_px_cov`），但相邻圆点的边缘会互相重叠：同一个像素被两次
部分混合，覆盖率不是相加而是“再叠一层”，于是环上每隔约 5° 出现一道
深浅交替的波纹。24 dp（r≈13 px、点直径 3 px）和 40 dp 的旋转圈最明显，
真机 520 dpi 下的截图能直接看到“齿轮边”。另外每帧要发 144 条命令
（72 轨道 + 弧），旋转圈每帧重画一次全屏。

### D.41.2 新原语

绘制命令增加 op 4：`x/y` 是外接正方形左上角、`d` 是直径、`radius` 存
内半径、`aux` 存 `起点 | 跨度 << 16`（Q16.16 圈，0 = 12 点，顺时针，
跨度 65535 表示整圈）。API 与 v1.32.0 完全一致，应用不需要改。

`fill_ring` 逐像素算一次覆盖率：

1. 半径方向：`co = clamp(128 + (r_out16 - d16) * 16, 0, 255)`、
   `ci = clamp(128 + (d16 - r_in16) * 16, 0, 255)`，相乘得到环带内的
   覆盖率（内外边界各 0.5 px 过渡，与 v1.23 的圆角算法同一手法）；
2. 角度方向：`time_angle` 已有八分区 + 1/8 段线性 atan（v1.29 时间表盘
   用的同一张表），把像素换算成 3932160 单位的圈内角度，判断是否落在
   `[start, start+span]`；再取到两端的角距离，乘周长换成 1/16 px 做
   0.5 px 过渡，弧外 0.25 px 归零；
3. 三个覆盖率相乘后只调用一次 `fill_px_cov`。整圈（span = 65535）跳过
   角度计算，只有半径方向的两次比较。

弧两端各补一个 `ref_ring_dot(cx, cy, r_mid, angle, stroke, color)` 当
圆头，和 v1.32.0 的圆点观感一致；同一颜色的不透明圆点叠在环上不会被
看见，只有半透明的下拉刷新指示器会在圆头处略深一点点，可接受。

### D.41.3 顺带修好的下拉刷新

`paint_refresh` 的 20 dp / 3 dp 指示环也用同一原语：轨道一条命令、
指示弧一条命令 + 两个圆头。好处有两个：旋转时不再有波纹；轨道从
“72 个 16% 半透明点叠加”变成单次 alpha 混合，颜色不再越叠越深。

### D.41.4 验证

`progress_circle_test` 除原有像素断言外，新增命令数范围 12..40：
v1.32.0 的点阵实现会远超这个上限（每个环 144 条），这样任何回退都会
被测出来。`progress_circle_harness` 的三圈并排、600→850、旋转相位、
默认 24 dp、深色全部通过；`refresh_test` / `refresh_harness` 也通过。
离屏截图对比：24 dp 与 40 dp 旋转圈的外缘波纹消失，边界过渡像素均匀
（同一行上 `f6f6f8 → e9e9eb → d4d4d6`）。

`aui_version()` 13201，trace 第二行 `V00003391`；十九个 APK
versionCode 44 / 1.32.1；qemu 44 项全过。

## D.42 v1.33.0：树视图（TreeView，容器 32 + 行 33 + op 5 三角）

### D.42.1 形状与用法

对齐 HuxerUI 的 `TreeViewStyle`。`aui_tree(key)` 是固定行高、可滚动的
容器（节点类型 32）；`aui_tree_item(key, text, depth, flags, cb, user)`
是一行（节点类型 33）。展开/选中的**状态由应用持有**：每帧按当前展开位
和选中 id 重新 build 可见行，点按回调只负责改状态并 `aui_invalidate()`。
这与 HuxerUI 的受控 TreeView 一致，也避免库内再存一份树结构（固定池
4096 节点不能承受两套状态）。

布局参数：行高 32 dp；缩进 = 8 + 20×depth dp（深度夹在 0..32）；分支行
左侧 24 dp 的指示槽里放 12 dp 三角，文字从槽右侧开始，右边留 8 dp 裁剪
边。行宽铺满容器，行间无间隙；容器内容总高 = 上下 padding + 行数 ×
32 dp，滚动量沿用 scroll 表（`scroll_store_max` / `scroll_get`），所以
滚动条、拖动、fling 都直接复用现有实现。

底色：选中行 14% primary（alpha 36/255）、按下 8%（alpha 20/255），
圆角 8 dp；未选中且未按下时完全透明，露出树/页面的背景。禁用行文字用
`ref_alpha(theme_text(), 97)`（约 38%），并且构造时就不挂回调，点按不会
派发。

### D.42.2 三角指示（op 5）

新绘制命令 op 5：`x/y/w/h` + `aux = dir`（0 右指、1 下指）。`fill_tri`
逐行求覆盖：

- 右指三角的宽度随纵坐标线性收窄，行内左边界固定、右边界按
  `w * (1 - |2y/h - 1|)` 求；下指三角则相反（宽度随横坐标收窄）；
- 内缩 0.5 px 得到左右覆盖过渡，两端不足一个像素时按剩余宽度比例混合，
  避免 12 dp 小图标出现台阶。

三角用文字色（禁用时同步降透明度），不额外占命令数：每个分支行一条。

### D.42.3 布局坑：权重子项需要父容器也占满

示例第一版只给树加了 `aui_weight(1)`，没有给外层 column 加权重。列测量
时权重子项不计入固有高度，于是列的测量高度只等于标题 + 底栏；到 arrange
时 `remain = 列高 - 固定子项 - 间距` 被夹到 0，树拿到 0 高，`paint_node`
把子树裁剪成空矩形，整棵树一条命令都画不出来——但行矩形的调试接口仍然
正常（arrange 已执行），很容易误判成绘制函数的问题。修法是常规的
“column 也 `aui_weight(1)`”。`tree_harness` 现在断言树高 >= 200 px，
同类回归会直接报出来。

### D.42.4 验证

`tree_test`（离屏 320×240、density 160）：23 个节点、命令数 20..30、
树矩形铺满视口、首行/第六行矩形、缩进层级与标志位、禁用位、最大滚动
408 px、选中底色 r 212..228 且 b >= 240、展开/收起三角的深色取样、
点行选中、点分支翻转展开位（标志 5）、滚动 120 px 后首行 y = -116、
滚到底末行 y = 204、禁用行点按不回调、版本 13300。

`tree_harness`（`ui_tree`，720×1280、density 420、真实宿主）：树 x = 42、
宽 636、行高 84 px、行首尾相接；选中行 102 的 14% primary 底
（r 212..228、b >= 240）；点 stdlib 后展开位 ^4 且 aui.ast 行消失；
点 generated 后 ^4096 且 chunk 行消失；禁用行点按状态不变；重新展开后
滚动 200 px，首行上移 200；深色下背景变暗、选中行主色换成 `6E96FF`
（b > r 且 b >= 45）。截图 initial / collapsed / scrolled / dark 四张
一并归档，深色与滚动裁剪都正常。

`aui_version()` 13300，trace 第二行 `V000033F4`；二十个 APK
versionCode 45 / 1.33.0；qemu 46 项全过。

## D.43 v1.34.0：Toast / SnackBar（不挂树的底部浮层）

### D.43.1 形状与职责

对齐 HuxerUI 的 `presentation.h`。两者都不是布局子项，不进入节点树、
不参与页面/滚动/对话框排版，只在布局末尾按内容区算矩形、在绘制末尾
叠加，因此增删提示不会改变页面节点数，也不会触发页面重建。

- **Toast**：被动反馈。底部居中，最多 4 条同时存在（固定池
  `g_aui_toast_*[4]`），新的在下、旧的按 8 dp 间距向上叠。底色
  `#1F2328` 94% 不透明，白字、16/12 dp 内边距、8 dp 圆角、最大宽
  480 dp（同时不超过内容区 − 32 dp），底边距 24 dp。完全穿透触摸。
- **SnackBar**：内容层浮层，同一时刻只有一条。底色 `#1F2328` 不透明，
  白字、动作文字 `#79C0FF`；左右 16 dp、上下 8 dp 内边距，消息与动作
  间距 8 dp，最大宽 600 dp（同时不超过内容区 − 32 dp），最小高 48 dp，
  动作最小 48×36 dp、圆角 6 dp，底边距 24 dp。新调用替换旧的。

时长：`duration_ms > 0` 精确毫秒，`0` 用默认值（Toast 2000 ms、
SnackBar 4000 ms），`< 0` 常驻。计时由 `present_tick()` 在每帧
`pump_ui` / `pump_frame_once` 开头推进，不需要应用自己开定时器；到期
只置 `need_paint` / `pump_need`，下一帧自然消失。

### D.43.2 指针策略

- Toast 是可穿透的：输入路径完全不查询 Toast 矩形，命中测试照常落到
  下面的按钮。`toast_test` 与 `toast_harness` 都断言“点被 Toast 盖住的
  按钮，计数 +1 且 Toast 仍在”。
- SnackBar 是内容层：`DOWN` 先查 `present_snack_hit()`（动作 = 2、
  表面 = 1）。命中表面会取消底层按压并吞掉整次手势；命中动作则进入
  按下态、倒计时暂停，`MOVE` 超过 8 dp 取消按下视觉但仍独占手势。
  `UP` 只有在 DOWN/UP 都命中动作时才触发：先把 SnackBar 状态清空
  （`on=0`、清 text/action/cb/user），再调用 `cb(user)`——回调里立刻
  再开一条提示不会被旧状态覆盖（HuxerUI 的 Activate 顺序）。
- `CANCEL` 清掉手势并恢复倒计时；BACK 不专门处理 SnackBar（它没有
  模态语义），沿用页面自己的 BACK 行为。

### D.43.3 时间基准

SnackBar 的剩余时间与 `present_tick` 共用 `anim_now()`（真实运行时是
`CLOCK_MONOTONIC`，测试里可用 `aui_debug_set_time` 注入）。输入路径里
按压暂停/恢复也写同一个时间基准；早期版本误用了 `clock_ns()`，在离屏
测试里 `aui_debug_set_time` 与假宿主时钟不同步，松手后第一次 `present_tick`
会把 4 s 倒计时一次性扣完，表现为“点一下表面 SnackBar 就消失”。改为
`anim_now()` 后离屏与假宿主两条路径一致。

### D.43.4 验证

`toast_test`（离屏 320×240、density 160、latin 8px ×2）：Toast “Saved”
为 `(104,172,112,44)`、底边 216；深色底与白字取样；点 Toast 覆盖的按钮
计数 +1；第二条 “Second” 128 px 宽，旧条升到 y=120、新条仍在 172；
1.999 s 仍在、2.001 s 全部收起；常驻与手动收起；SnackBar 288 px 宽、
56 高、底边 216，动作 88×36 位于 x=200，剩余 4000 ms；点表面不穿透、
按住动作跨 5 s 不消失、松手回调一次且先收起、纯消息与 800 ms 到期、
无效参数返回 0。

`toast_harness`（`ui_toast`，720×1280、density 420、真实宿主）：
版本 13400；Toast 水平居中、底边 1280 − 63 px（24 dp）；覆盖底部
“Tap Under Toast” 时点击穿透；两条堆叠间距 21 px（8 dp）；2.5 s 后
归零；SnackBar 表面吞点击、UNDO 后弹出 Restored；4 s 到期；深色主题
下浮层底色仍为 `#1F2328`。截图 initial / single / stacked / snackbar /
pressed / restored / dark 七张归档。

`aui_version()` 13400，trace 第二行 `V00003458`；二十一个 APK
versionCode 46 / 1.34.0；qemu 48 项全过。

## D.44 v1.35.0：菜单（Menu，浮层 34 + 条目 35 + 分隔线 36 + op 6 粗线段）

### D.44.1 形状与职责

对齐 HuxerUI 的 `MenuStyle`。菜单与 Toast/SnackBar 一样不挂布局树：每帧
由应用在构建回调里用 `aui_menu` / `aui_menu_at` 重新登记，子项用
`aui_menu_item` / `aui_menu_separator` 追加，`aui_end()` 收口。菜单节点
（kind 34）只存在于节点池，不参与父容器排版，所以开关菜单不会改变页面
几何和滚动位置。

- 尺寸：内容内边距 4 dp；条目左右 12 dp、上下 8 dp，最小高 36 dp
  （分隔线固定 1 dp）；最小宽 180 dp，自然宽 = 最长文字 + 24 dp 文本槽
  + 状态列；上限为内容区宽 − 16 dp。有勾选条目时状态列占 18 + 8 dp，
  没有时文字直接靠左（HuxerUI 的 icon/state 槽只在需要时保留）。
- 定位：默认锚在 `anchor_key` 节点正下方 4 dp；下方放不下先尝试翻到
  锚点上方，上方也放不下就夹到底部；左右同样夹在内容区 8 dp 边距内。
  `aui_menu_at` 用 Q16.16 左上角，之后同样夹紧。
- 配色：`theme_surface` 表面 + `theme_hint` 1 px 描边、8 dp 圆角；
  没有高斯模糊，用向右 1 dp、向下 2 dp 的 20% 黑矩形近似阴影；分隔线
  为文字色 12% alpha、左右各内缩 8 dp。深色主题下表面/文字自动反转。
- 条目：`AUI_MENU_CHECKED` 画勾选标记，`AUI_MENU_DISABLED` 文字降到
  38% 不透明且点按无效；按下条目铺 12% 黑（深色为 12% 白）圆角 6 dp。

### D.44.2 op 6：抗锯齿粗线段

勾选标记用两笔带圆头的粗线段。新增 `cmd_seg(x0,y0,x1,y1,color,half)`
（op 6），x/y 为 Q16.16 端点、`radius` 存半宽。光栅器把像素中心换算到
1/16 px 定点，先投影到线段（点积夹在 [0,len²]），再算到投影点的距离
平方：内半径 `r−0.5 px` 内满覆盖，外半径 `r+0.5 px` 外用二次近似过渡，
最后一次性混合。全程 i64，没有 sqrt；端点自然形成圆头。

这一版顺带修了三个只在真机 dpi 下才暴露的问题：

1. 覆盖率公式在窄带下会算出 >255 的 alpha，负的 `(255-a)` 参与混合后
   把像素写成白色——表现为勾选标记只剩一个小点。现在 `cv` 夹到 255。
2. 包围盒初始化把 `bx1/by1` 设成了终点，线段朝左上时 y 范围退化成一条
   线，只剩端帽。改成从起点开始再与终点取 min/max。
3. 投影方向取反（`start − pixel`），`t` 在起点之前一直为 0，线段只会
   在起点附近留下一个圆点。改成 `pixel − start` 后长度才能正常展开。

### D.44.3 指针、滚动与顺序

菜单是内容层模态浮层，优先于 SnackBar 和页面：

- 打开时先收起工具提示，并拒绝在对话框/下拉展开期间创建。
- `DOWN` 记录落点与命中条目（面/内边距 = 吞掉，外部 = 待关闭）。
  `MOVE` 超过 8 dp 进入拖动，按位移滚动内部内容并取消按下态；`UP`
  只有 DOWN/UP 命中同一条目且未拖动才激活；外部松手 reason=2；
  `CANCEL` 清手势保留滚动位置；BACK 先关菜单（reason=3）。
- 激活顺序遵循 HuxerUI Activate：先把菜单状态清空并调菜单回调
  （`aui_menu_reason()` 读到 1），再调条目回调（`aui_menu_item_key()`），
  条目回调里立刻开新菜单不会被旧状态覆盖。
- 按压/拖动/滚动偏移属于输入状态，跨重建保留；只有真正新开一层菜单
  （`g_aui_menu_had == 0`）才归零。否则 DOWN 触发的 pump 重建会把刚
  按下的条目抹掉——v1.26.2 在下拉选择上踩过同一个坑。

### D.44.4 验证

`menu_test`（离屏 320×240、density 160）：默认菜单 (8,48,186,117)、
条目 61 (12,52,178,36)、勾选条目 y=88、禁用条目 y=125、分隔线 y=124
高 1；白底/深色文字、勾选两笔、禁用置灰；选 62 时 reason=1 且菜单回调
先于条目回调、禁用 64 不回调；点外 reason=2、BACK reason=3；16 条菜单
`maxoff > 0`，拖 80 px 后 offset=80、夹紧到 max、拖动不选条目；屏幕点
菜单 (100,50) 宽 180；锚点靠底翻上 y=49；dismiss 记 reason=2；无效
参数返回 -1。

`menu_harness`（`ui_menu`，720×1280、density 420、真实宿主）：Actions
菜单宽 ≥ 472 px、贴按钮下方 10 px；勾选/禁用/白底深字；点 Rename 后
reason=1、item=21、顺序计数证明菜单回调先跑；禁用 Delete 不关菜单；
外部 reason=2、BACK reason=3；屏幕点菜单 (60,400)；16 条菜单溢出后
拖 160 px、offset ≥ 100 px 且不误选；滚到底部后底部按钮的 3 条菜单
翻到按钮上方并可选；深色下表面变暗、文字变亮。截图 initial / actions /
pressed / point / scrolled / flipped / dark 七张归档。

`aui_version()` 13500，trace 第二行 `V000034BC`；二十二个 APK
versionCode 47 / 1.35.0；qemu 50 项全过。

## D.45 v1.36.0：图标与图标按钮（22 个内置矢量图标）

### D.45.1 形状与职责

图标不是位图，也不进字体图集：每个图形都用已有的绘制原语现场画，
换 dpi 只是把归一化坐标重新乘一遍。新增节点类型 37 `icon_button`、
38 `icon`：

- `aui_icon_button(key, icon, size_dp, flags, cb, user)`：触控方块
  （默认 40 dp，夹在 24..96 dp），图形边长 = 方块一半（默认 20 dp），
  无背景，按下时铺边长 4/5、圆角 4 dp 的 `PRESSED` 指示层，图形绘制在
  指示层之上。`AUI_ICONBTN_DISABLED` 把图形 alpha 降到 97 并让
  `find_clickable` 直接跳过（不回调、不按下）。
- `aui_icon(key, icon, size_dp)`：只读图形（默认 20 dp，8..96 dp），
  量测为 边长 + pad*2，透明背景，可放进行/列/滚动容器当工具条、列表
  前缀或图例。两种节点都用 `aux` 存图标 id、`aux2` 存边长（Q16.16 px）。

未知 id 在构造时兜底为 `PLUS`，所以 `AUI_ICON_*` 之外的值不会画出
空白，也方便调用方用变量传图标。

### D.45.2 归一化几何

所有坐标写成“半格 = 1000”的整数：

- `icon_px(c, s, u) = c + (i64(s) * u) / 2000`：c 是图形中心（Q16.16），
  s 是边长（Q16.16），u 是归一化偏移；用 i64 避免大 dpi 溢出。
- 描边半宽 `s/20`（20 dp 图形 = 2 dp 笔画），圆点半径 `s/14`；
  线段统一走 op 6（抗锯齿圆头），所以端点、拐角天然圆滑。
- 加号/减号/勾/叉/单箭头/菜单/编辑/主页/设置/日历/下载 = 圆头线段；
  搜索 = op 4 圆环（外径 11/20 s、内径再减 1/10 s）+ 45° 手柄；
  播放 = op 5 三角形；暂停 = 两个圆角竖条；星形 = 10 段折线；
  垃圾桶 = 桶盖/提手/桶身/三条竖线；日历 = 外框 + 顶栏 + 两条挂环 +
  两个日期点；“更多”= 三个圆点。
- 播放/暂停的宽高原来写成 `s * 600 / 2000`、`s * 720 / 2000`，在
  48 dp 以上会超过 i32（`s` 是 Q16.16），导致图形整块消失；改为
  `i32((i64(s) * 600) / 2000)` 后 96 dp 也正常。这个 bug 是 qemu
  harness 在 720×1280@420 下把 32 dp 图标改成 48 dp 才暴露的。

颜色只取主题角色：正常 `theme_text`，禁用是同一颜色乘 97/255 alpha，
深色主题自动反转，不为图标单独设调色板。

### D.45.3 量测、点击与绘制顺序

`measure_icon_button` 返回 `w = h = aux2`（正方形），`measure_icon`
返回 `边长 + pad*2`；两者都不参与拉伸，行内按顺序排列。绘制顺序：
先背景（`n.bg` 非零时）、再按下指示层、最后图形；`paint_glyph` 只
产生命令不做量测，因此滚动裁剪、转场位移、子树 alpha 都自动生效。
点击命中沿用统一矩形测试，禁用按钮在 `find_clickable` 入口直接返回
-1，避免落点被吞。

调试接口：
`aui_debug_icon_button` → `[x,y,w,h,icon,disabled,size_px]`，
`aui_debug_icon` → `[x,y,w,h,icon,size_px]`（都是屏幕像素）。

### D.45.4 验证

`icon_test`（离屏 320×240、density 160）：按钮 40×40、间距 6 px，
图标 24/32/16 dp 的矩形；加号横竖两笔、勾选两笔、星形轮廓、搜索环 +
手柄都有近黑像素；禁用垃圾桶有浅灰笔画但无近黑；按住时指示层变深、
图形仍压在上面，松手恢复；点加号/勾选各一次、禁用不回调；56 dp
自定义尺寸；深色下背景变暗、图形变亮、禁用保持中灰；版本 13600。

`icon_harness`（`ui_icon`，720×1280、density 420、真实宿主）：工具条
5 个 40 dp（105 px）方块、间距 21 px，图形都不缺；点加号/勾选/关闭后
状态 980 = 1/3/4、981 = 1/2/3；禁用垃圾桶点按后 982 仍为 0；按住
加号出现指示层；22 个网格图标滚进视口后都有笔画；尺寸行 16→48 dp
宽度递增（42/52/63/84/126 px）；统计行与深色开关滚到底可见；深色下
图标变亮、禁用仍是中灰；滚动范围与裁剪正常。截图 initial / pressed /
tapped / close / disabled / scrolled / dark 七张归档。

`aui_version()` 13600，trace 第二行 `V00003520`；二十三个 APK
versionCode 48 / 1.36.0；qemu 52 项全过。

## D.46 v1.37.0：流式布局与分隔线（Flow 39 / Divider 40）

### D.46.1 形状与职责

对照 HuxerUI 的 `Flow` 与 `Divider`，新增节点类型 39 `flow`、40 `divider`：

- `aui_flow(key)`：换行容器。孩子按主轴依次摆放，一行放不下就换行；
  列间距与行间距共用 `aui_gap`（默认 0），`aui_pad` 作用于四边。
- `aui_flow_align(AUI_FLOW_START/CENTER/END/SPACE_BETWEEN)`：设置
  **每一行**的主轴排列方式，值写进 `aux2`（0..3，越界夹紧）。默认
  START；CENTER/END 用整行剩余空间做偏移；SPACE_BETWEEN 在只有一个
  孩子的行退化为 START（没有可分配的间隔）。
- `aui_divider(key)`：水平 1 dp 细线，宽度铺满可用宽，颜色默认取
  `theme_text` 的 12% alpha（`0x1F......`），可用 `aui_bg` 覆盖、
  `aui_pad` 控制左右内缩；节点不接输入，也不会吃掉点击。
- `aui_divider_v(key)`：竖线，宽 = 粗细，固有高 24 dp，默认
  `align = 3`，父行/列会把它拉伸到整行高；左右内缩用 `aui_pad`。
- `aux` 存方向（0 水平 / 1 垂直），`aux2` 存厚度（Q16.16 px，默认
  1 dp，绘制前至少抬到 1 px）。

分隔线的量测很轻：水平线高度 = 厚度 + 上下 pad，宽度在给定可用宽时
铺满；竖线宽度 = 厚度 + 左右 pad、高度 = 24 dp + 上下 pad。因为没有
孩子，`arrange` 直接返回。

### D.46.2 量测：严格大于才换行

`measure_flow` 一趟扫描，维护当前行宽 `line_w`（含孩子之间的 gap）、
行高 `line_h`（该行最高孩子）与行数：

```
若 line_n > 0 且 line_w + gap + child.w > inner  →  收行，重新开始
否则 line_w += (line_n > 0 ? gap : 0) + child.w，line_h = max(line_h, child.h)
```

三个细节：

1. 换行判定用 **严格大于**：一行恰好填满时不换行，避免 dpi 取整导致的
   无意义空行。
2. 孩子先按 `inner` 宽度量测；有 `weight` 的孩子仍先按自身固有宽参与
   换行，权重只在该行内部分配剩余空间（与 Row 语义一致，不跨行）。
3. 总高 = 上下 pad + Σ行高 + gap×(行数−1)；行数写进 `aux`。容器宽度
   在 `avail > 0` 时铺满（与列/行一致），否则取最宽行 + 左右 pad，
   便于放进固有宽度的父容器。

### D.46.3 排布：两遍确定每行

`arrange_flow` 以 `start` 为行首孩子循环，每行做两遍：

- 第一遍用与量测相同的规则确定本行成员、`line_w/line_h/line_n`、
  权重和 `wsum`，并把溢出孩子记为 `next_start`。
- 计算 `remain = inner - line_w`。没有权重孩子时按 `just` 取整行偏移：
  `xoff = remain/2`（CENTER）、`remain`（END）、或
  `extra = remain/(line_n-1)`（SPACE_BETWEEN，仅 >1 个孩子）。
  有权重孩子时 `remain` 负值先夹到 0，剩余宽度按权重分配。
- 第二遍逐个落位：有 `weight` 的孩子
  `cw += i32((i64(remain) * i64(weight)) / i64(wsum))`，用 i64 乘积避免
  大屏 + 大权重下的 i32 溢出（同 D.45 的教训）；交叉轴按 `align`
  取顶部/居中/底部/拉伸（`cch = line_h`）。
- 行末 `cy += line_h + gap`，换行游标前进。除不尽的余数留在右侧，
  不做二次分配，保证同一行内每个孩子的宽度只由其权重决定。

### D.46.4 绘制与调试

容器背景在 `paint_node` 里与列/行/栈同一路径处理；分隔线在同一处调用
`paint_divider`：水平线在盒内垂直居中、左右各留 `pad`，竖线在盒内水平
居中、上下各留 `pad`。颜色只取 `n.bg` 或主题文字色的 12%，所以浅色
背景上是浅灰、深色主题上自动变成浅灰白，不需要额外调色板。

调试接口：

- `aui_debug_flow(key, out)` → `[x, y, w, h, 行数, 对齐]`，其中
  x/y/w/h 为屏幕像素（Q16.16 → px），行数与对齐来自 `aux/aux2`。
- `aui_debug_divider(key, out)` → `[x, y, w, h, 方向, 厚度_px]`。

### D.46.5 验证

`layout_test`（离屏 320×320、density 160）：7 个 40 dp 图标在 304 px
内宽排成 2 行，行高 84、行距 4，第 8 个图标换到第二行；行内按钮点按
命中；第二行 CENTER、第三行 SPACE_BETWEEN（首尾贴边），20 dp + weight=1
吃满剩余 280 px；水平分隔线 304×1、竖直分隔线 1×40；`pad=20` 的
自定义红色分隔线在 (28,277) 有红色像素、(12,277) 是底色；深色下背景
亮度 < 60，而分隔线比背景更亮。

`layout_harness`（`ui_layout`，720×1280、density 420）：版本 13700；
6 个标签片在 615 px 内宽换行并逐枚切换选中（970 计数、971 末次 key）；
7 个图标按 5+2 换行，点按切换 START/CENTER/SPACE_BETWEEN 后首行 x
依次左移/居中/贴边（972 = 对齐值）；三个图标按钮更新末次动作
31/32/33；分隔线 615×2、竖线 2×105，16 dp 与红色 32 dp 内缩线都有
墨迹；滚动范围与裁剪正常；深色下背景变暗而分隔线更亮。

`ui_layout.ast`（第 22 个 APK，`dev.aster.uilayout`）：换行标签片、
五种对齐模式（Start/Center/End/Between 放在一个 flow 里自身换行）、
图标流、图标按钮 + 竖直分隔线、内缩分隔线、统计与深色开关。
截图 initial / pressed / selected / center / between / dividers / dark
七张归档。

`aui_version()` 13700，trace 第二行 `V00003584`；二十四个 APK
versionCode 49 / 1.37.0；qemu 54 项全过。

## D.47 v1.38.0：底部弹层 Bottom Sheet

### D.47.1 目标与边界

对照 HuxerUI `presentation.h` 的 `BottomSheet`：从屏幕底部升起的模态
表面，带遮罩、顶部拖拽手柄、下拉关闭，内容区由应用自由构建。AsterUI
没有 View 层级，弹层和 dialog 一样是**游离在根树之外**的节点，由库在
布局/绘制/命中三个阶段单独处理。

两个硬边界：

- 同时只允许一层弹层，且与 dialog 互斥。`aui_dialog` 在弹层已开时
  返回 -1，`aui_sheet` 在 dialog 已开或弹层已开时返回 -1。
- 弹层内容只能放普通控件，不能放 `aui_text_field`：焦点/键盘仍是根树
  坐标，与 dialog 的限制相同。

### D.47.2 两个节点：遮罩与表面

`aui_sheet(key, open, cb, user)` 创建：

- 类型 41（`-key`）：全屏遮罩，颜色 `0x6B000000`（约 42% 黑）。它不
  参与普通布局，由 `sheet_layout` 直接铺满内容区；命中返回 -20。
- 类型 42（`key`）：贴底表面，是返回给应用的节点，后续 `aui_label` /
  `aui_row` 等都挂到它下面。回调挂在表面节点上；`sheet` 自身再挂一个
  空回调 `sheet_noop`，避免命中测试把遮罩当成可点击的普通节点。

关闭时两个节点一起消失，应用在回调里把 `open` 置 0 并
`aui_invalidate()` 即可。`aui_root()` 每次重建前记录上一帧是否有弹层
（`g_aui_sheet_had`），用于判断“新打开”并启动滑入动画。

### D.47.3 几何与手柄

`sheet_layout(cx, cy, cw, ch)`：

```
w = min(cw - 32dp, 640dp)
h = min(内容测量高, ch * 85%)
x = cx + (cw - w) / 2
y = cy + ch - h
```

表面内部 `pad 20dp`、孩子 `gap 12dp`、圆角 14 dp；绘制时只给**顶部**
两角做圆角，底部两角保持直角，形成与屏幕底边相接的“贴底带”。手柄是
32×4 dp、圆角 2 dp 的短条，水平居中、距顶 10 dp，颜色为文字色的 30%
alpha（`(77<<24)|text`）。`aui_sheet_handle(0)` 只清除 flags 位 0，
手柄不再绘制，但 32 dp 抓取区仍然存在，方便“无手柄但可下拉”的用法。

### D.47.4 拖拽与关闭

输入路径：

- DOWN：若仍在滑入保护窗口（`anim_now() < g_aui_sheet_until`）则吞掉；
  否则命中表面顶部 32 dp 时记 `g_aui_sheet_drag = 0` 与起点 `dy0`。
- MOVE：`g_aui_sheet_drag = (py - dy0) << 16`，并请求重布局。绘制时
  类型 41/42 都加上这个向下位移，但遮罩保持不动。
- UP：阈值 `max(表面高/4, 96dp)`。未超过则回到 0、保持打开；超过则
  先置 `g_aui_sheet_drag = -1`，写 reason=3，调用一次表面回调。
- CANCEL：清掉拖拽位移，不关闭。
- 遮罩空白点按：reason=1；BACK：reason=2，两者都先重置拖拽状态再
  回调。BACK 在焦点/导航之前处理，不会 pop 页面。

关闭原因由 `aui_sheet_reason()` 读取；重新打开时归零。

### D.47.5 动画与输入保护

打开的第一帧在 `sheet_layout` 里启动
`aui_anim(key, AUI_ANIM_TY, h, 0, 240, AUI_EASE_OUT)`：表面从屏底
（+h）滑到最终位置。动画只作用于绘制，布局位置仍是最终矩形，因此
滑入过程中命中测试已经按最终位置生效；为防误触，DOWN 在
`anim_now() + 280 ms` 之前直接吞掉。这里用 `anim_now()` 而不是真实
时钟，是为了让离屏测试（注入假时钟）与真机行为一致。

关闭是**即时移除**，没有 HuxerUI 的 180 ms 退出动画：本实现每帧重建
节点，回调里 `open=0` 后节点不再存在，保留快照做退出动画会引入一整
套额外的生命周期与输入吞噬逻辑。这一点在文档与示例里明确写出。

### D.47.6 调试与验证

`aui_debug_sheet(out)` 输出 `[x, y, w, h, 拖拽位移_px, flags]`，关闭时
首元素为 -1；flags 位 0 表示手柄已隐藏。`aui_debug_node_count()` /
`aui_debug_cmd_count()` 仍可用于统计遮罩与表面带来的节点/命令增量。

`sheet_test`（离屏 320×320、density 160）：

- 表面 `(16,172,288,148)` 贴底，遮罩像素 `(0x8F,0x8F,0x90)`（42% 黑
  与浅色底 `0xFFF6F6F8` 的混合结果，分量四舍五入）。
- 顶部圆角外侧是遮罩、底部两角是白色表面；表面外命中 -20、表面内 20，
  卡片空白点按不关闭；按钮命中 23 且回调一次、reason=0。
- 手柄灰条亮度在 120..240；下拉 40 px 回弹并保持打开；下拉 100 px
  关闭且 reason=3；点遮罩 reason=1 且底层不可点；BACK reason=2。
- `aui_sheet_handle(0)` 后 flags 位 0 置位、手柄像素消失；深色表面
  `0x1E1E24`。

`sheet_harness`（`ui_sheet`，720×1280、density 420）：版本 13800；
打开动画中点采样顶部为遮罩、结束后为表面；几何 sx=42、sw=636、底边
贴 1280；滑块拖到 4/5 后状态 973 落在 650..900；Confirm 关闭且
971=21；从卡片顶部向下拖 (h/4+260) 后关闭、reason=3、971=20；遮罩
点按 reason=1；`aui_on_input(2,...)` 发 BACK 关闭 reason=2；隐藏手柄
后 flags 位 0 置位、原手柄位置为白色；深色表面 `0x1E1E24`。

`ui_sheet.ast`（第 23 个 APK，`dev.aster.uisheet`）：页面按钮打开弹层，
状态回显 Opens / Last action / Close reason；弹层内标题、说明、滑块、
Cancel/Confirm 等宽按钮；Hide handle 与 Dark 两个开关即时生效。截图
initial / entering / open / slider / dragging / no_handle / dark 七张归档。

`aui_version()` 13800，trace 第二行 `V000035E8`；二十五个 APK
versionCode 50 / 1.38.0；qemu 56 项全过。

## D.48 v1.39.0：锚定浮层 Popup

### D.48.1 目标与边界

对照 HuxerUI `presentation.h` 的 `Popup`：挂在某个锚点旁边、内容任应用
自由构建的模态浮层。它与既有的菜单/选择器不同——那两者是条目列表；
Popup 只有一个 surface，孩子按列排列，可以是标签、滑块、按钮的任意
组合。

边界：

- 一个类型 43 的游离节点，不挂进页面树，由 `popup_layout` /
  `paint_popup` / `popup_hit` 单独处理。
- 同时只允许一层，且与 dialog / sheet / menu / 已展开的 select 互斥。
  `popup_open` 在任一方已开时返回 -1；`aui_dialog` / `aui_sheet` /
  `aui_menu` 在浮层已开时同样返回 -1。
- 浮层里不要放 `aui_text_field`：焦点与键盘仍以根树坐标为准。

### D.48.2 节点与状态

`aui_popup(key, anchor_key, open, cb, user)` 与
`aui_popup_at(key, px, py, open, cb, user)` 只在 `open != 0` 时创建
类型 43 节点，`aux` 存锚点 key（或 0）、`aux2` 标记屏幕点锚定，`cb/user`
挂在节点上。节点 `pad 16dp`、`gap 12dp`、`radius 12dp`；子项按列排列。
`aui_root()` 重建前把上一帧是否有浮层记到 `g_aui_popup_had`，用于首帧
清理命中/矩形缓存。

状态全局：`g_aui_popup_side/align/fixed` 在每次 `popup_open` 里归零，
随后由 `aui_popup_place` / `aui_popup_width` 设置；因此应用要在
`aui_popup` 之后、`aui_end` 之前调用它们。

### D.48.3 几何

`popup_layout(cx, cy, cw, ch)`：

```
pad = 16dp; margin = 8dp; gap = 4dp
maxw = min(cw - 16dp, 360dp)
natural = max(孩子测量宽)
pw = fixed > 0 ? fixed : natural + 2*pad
pw = clamp(pw, 96dp, maxw)
ph = min(measure(popup, pw), ch - 16dp)
```

锚点矩形来自 `popup_find_anchor(key)`（排除浮层自己、菜单、对话框、
弹层表面等不挂树的类型）；屏幕点锚点宽高为 0。方向与对齐：

```
below: y = ay + ah + gap,  x = ax / 居中 / 右对齐
above: y = ay - ph - gap, 同上
right: x = ax + aw + gap, y = ay / 居中 / 底对齐
left:  x = ax - pw - gap, 同上
```

首选方向放不下时翻到反方向（below↔above、right↔left），翻过去也放
不下则贴到对应内容边；最后统一夹进 `[cx+margin, cy+margin, cw-16dp,
ch-16dp]`。矩形写回 `g_aui_popup_px/py/pw/ph` 并 `arrange` 孩子。

### D.48.4 绘制

`paint_popup` 先把裁剪设到浮层矩形，画一层偏移 (1dp, 2dp)、12 dp 圆角
的 `0x33000000` 近似阴影，再画 1 dp `theme_hint` 描边与内缩 1 dp 的
`theme_surface` 表面（圆角 11 dp），然后把 `g_aui_paint_bg` 切成
surface，用同一套 `paint_node` 画孩子——按钮、滑块、开关、文本在浮层
里与页面完全一致。最后恢复裁剪与背景色。

### D.48.5 输入与关闭

- DOWN：先清 `g_aui_popup_down`；根命中前调用 `popup_hit`：矩形外
  返回 -1（记 -1），矩形内但命中到浮层自身（内边距/空白）返回 -2，
  内容孩子返回自身下标。命中 -1/-2 时清按下态并直接返回，不再下传。
- MOVE：`down` 为 -1/-2 时直接返回，避免拖动底层页面。
- UP：读取并清空 `down`；若 DOWN 没在浮层上（-3）用当前点补一次
  `popup_hit`。-1 → `popup_close(1)` 并重绘；-2 → 只重绘；否则走普通
  点击派发（内容里的按钮/滑块正常回调）。
- CANCEL：清 `down`。
- BACK：在页面/焦点处理之前，浮层打开即 `popup_close(2)` 并返回 1。

`popup_close(reason)` 先清空 `g_aui_popup` 与矩形、命中状态，再写
`g_aui_popup_reason`，最后调回调；因此回调里可以安全地重新打开。
`aui_popup_reason()` 读取 1 外部 / 2 BACK / 3 dismiss；
`aui_popup_dismiss()` 用于编程关闭。

### D.48.6 调试与验证

`aui_debug_popup(out)` 输出 `[x, y, w, h, side, align, reason]`；没有
浮层时返回 -1，但 side/align/reason 保留最后一次值，方便测试关闭原因。

`popup_test`（离屏 320×320、density 160）：

- 默认下方/左对齐、与锚点间距 4 px、固定宽 120；固定 400 被夹到内容区
  304，自然宽落在 96..304；点锚在底部自动翻上、右缘夹到 192。
- 首选上/右/左与右缘翻左、左缘翻右；节点锚居中/末尾按公式落位。
- 内边距空白吞点击；内容按钮回调一次且不关闭；点外部 reason=1、
  BACK reason=2、`aui_popup_dismiss` reason=3；关闭后 debug 返回 -1。
- 浮层打开时 dialog/sheet/menu 均返回 -1；对话框打开时 `aui_popup`
  返回 -1；深色表面 `0x1E1E24`。

`popup_harness`（`ui_popup`，720×1280、density 420）：版本 13900；
默认浮层在按钮下方 9..12 px、宽 420、表面白色；滑块写回 973 落在
650..900；Apply 关闭且 971=21；外部 reason=1、BACK reason=2；Above
记录 side=1 且在按钮上方；Right 翻左夹到 279、Left 夹到 21；Center
记录 align=1；深色表面 `0x1E1E24`。

`ui_popup.ast`（第 24 个 APK，`dev.aster.uipopup`）：Show popup 打开
浮层，内含标题、滑块、Cancel/Apply；Below/Above/Right/Left 与
Start/Center/End 设定首选方向与对齐；状态回显 Opens / Last action /
Close reason / Side-align。截图 initial / below / above / right /
center / slider / dark 七张归档。

`aui_version()` 13900，trace 第二行 `V0000364C`；二十六个 APK
versionCode 51 / 1.39.0；qemu 58 项全过。

## D.49 v1.40.0：顶部应用栏 TopAppBar

### D.49.1 目标与边界

对照 HuxerUI `navigation.h` 的 `TopAppBar`：页面顶部的固定高度条，左侧
可选 leading（通常是返回箭头），中间标题，右侧若干动作按钮，可选底部
1 px 提示线。它只是普通容器，动作直接复用 `aui_icon_button`；标题、对齐
与提示线由应用栏自己绘制。

边界：

- 类型 44 的容器，参与正常布局与命中；不是浮层，也不接管返回键。
- 只处理单行标题：换行符之后的文本不绘制，超宽部分按区间裁剪。需要
  多行标题时应改用普通 label + 自定义列。
- 标题起点与动作区间由库计算，应用不要给标题额外加 child；动作按钮按
  自己的尺寸参与栏高。
- `title` 是常量字符串指针，不复制、不参与文本池，因此可安全放在
  rodata；应用每帧重建 UI 时直接传同一个指针即可。

### D.49.2 节点与状态

`aui_top_bar(key, title, leading_icon, cb, user)` 用 `push_container(44,
key)` 创建容器，把 `title` 写进 `n.text`、`n.aux = -1`、`n.aux2 =
AUI_TOP_BAR_START`。`leading_icon != 0` 时自动创建 key = `-key` 的
`aui_icon_button`（40 dp），并置位 `AUI_TB_LEADING`；随后把
`g_aui_last_created` 恢复成应用栏本身，保证后续 `aui_top_bar_align` /
`aui_top_bar_divider` / `aui_gap` 作用在栏上。

`aui_top_bar_align(a)` 把 `n.aux2` 夹到 0（start）/ 1（center）；
`aui_top_bar_divider(show)` 设置或清除 `AUI_TB_DIVIDER`。两者都只修改
最近创建的节点，且要求 `kind == 44`，否则静默返回 0。

### D.49.3 几何

```
hp = n.pad > 0 ? n.pad : 8dp          // 水平内边距
inner_x = n.x + hp; inner_r = n.x + n.w - hp
leadw = leading ? leading.w : 0
xs = inner_x + (leading ? leadw + 4dp : 16dp)
xe = inner_r - actions_w - 4dp
hh = max(48dp, 所有子项测量高)
n.h = hh; n.w = avail（无约束时用内容自然宽）
```

`actions_w` = 除 leading 外所有子项宽之和 + `gap × (个数 - 1)`。标题宽
用 `text_measure` 加 0.5 dp 的粗体偏移。`arrange_top_bar` 把 leading
放在 `inner_x`、垂直居中；动作从 `max(inner_x, inner_r - actions_w)`
开始从左往右排（方向由子项顺序决定，顺序本身是从右到左的视觉槽位），
每个动作按自身高度垂直居中。内边距只作用于水平方向，栏高等于最高子项
或 48 dp，不再加垂直内边距。

### D.49.4 绘制

`paint_top_bar` 先铺 surface（`n.bg` 可覆盖），需要时在底边画 1 px、
12% 文字色的提示线；然后计算标题区间与单行标题宽。start 对齐时
`tx = xs`；center 时 `tx = xs + (xe - xs - tw)/2` 并夹到 `xs`。标题
基线按 `n.y + (n.h - text_glyph_h())/2` 垂直居中，用两条
`cmd_add(2, ...)`（第二条偏移 0.5 dp）模拟粗体。

绘制标题前把全局裁剪临时收窄到 `[xs, xe] ∩ 祖先裁剪` 与栏的 y 区间，
这样超长标题在区间边缘干净截断，不会压到动作按钮；绘制后恢复原裁剪。
`cmd_add` 会把当前裁剪写进每条命令，因此不需要额外的剪切节点。

### D.49.5 输入

应用栏本身没有回调；命中走普通容器规则，最终落到自动创建的 leading
图标按钮或应用自己添加的动作按钮上。`find_clickable` 会从最深节点向上
找第一个带 cb 的祖先，所以点标题区域（无回调）不会误触发 leading。
应用在回调里翻转状态并 `aui_invalidate()`，下一帧按新标题/对齐重绘。

### D.49.6 调试与验证

`aui_debug_top_bar(key, out)` 输出 16 个整数（像素）：

```
[x, y, w, h, align, leading_key, actions, divider,
 title_x0, title_x1, leading_x, leading_w,
 title_w, title_len, title_tx, title_ty]
```

`title_len` 在第一个换行符处截断；没有 leading 时 `leading_key = -1`、
`leading_x/leading_w = 0`。找不到节点返回 -1。

`top_bar_test`（离屏 320×320、density 160）：

- 版本 14000；栏 320×48；leading key = -50、rect (8,4,40,40)；两个动作
  x=232/272；标题区间 52..228 且有墨迹；三个回调各触发一次。
- center 公式、底部 1 px 提示线（上一 px 仍为 surface）。
- 无 leading 时区间 24..228；动作高 56 dp 时栏高 56、leading 仍垂直
  居中；无动作时右端留 4 dp（xe=308）。
- 长标题（act=0）只画在区间内、起点贴左，右侧 309..320 无墨迹。
- 嵌套 8 dp 内边距：栏 x=8、w=304、区间 60..220、leading x=16、动作
  224/264；深色 surface `0x1E1E24`。

`top_bar_harness`（`ui_top_bar`，720×1280、density 420）：版本 14000；
栏 720×126、leading rect (21,10,105,105)、动作 x=489/594、标题区间
136..478（半像素 `>>16` 取整）；leading/Search/More 回调计数；居中
（±1 px 容差）、提示线、长标题裁剪、深色表面。

`ui_top_bar.ast`（第 25 个功能 APK，`dev.aster.uitopbar`）：leading
返回箭头 + Search/More，两个开关分别控居中与提示线，另有长标题与深色
开关；状态回显 Back/Search/More 次数与 Last action。截图 0-initial / 1-leading / 2-center / 3-divider / 4-long / 5-dark /
6-actions 七张归档。

`aui_version()` 14000，trace 第二行 `V000036B0`；二十七个 APK
versionCode 52 / 1.40.0；qemu 60 项全过。

## D.50 v1.41.0：底部导航栏 NavigationBar

### D.50.1 目标与边界

对照 HuxerUI `navigation.h` 的 `NavigationBar`：底部固定一条 64 dp 的
导航栏，若干等宽项，每项一个图标 + 一行文字，选中项有 56×32 dp 的
指示胶囊。选择由应用控制（受控组件），点按只发出「请求下标」，界面
在回调里更新状态后重建。不引入角标、动画指示器或滑动切换——这些
留给后续版本。

与 TopAppBar 一样，导航栏不创建 Java View，只是节点树里的普通容器，
参与列布局并占满可用宽度。

### D.50.2 节点与状态

新增两种节点：类型 45（导航栏容器）与类型 46（导航项叶子）。

- `aui_nav_bar(key, selected, cb, user)`：`push_container(45, key)`；
  `n.aux = max(selected, 0)` 存放应用给的选中下标；`cb/user` 存在容器上。
- `aui_nav_item(key, icon, label, flags)`：`push_leaf(46, key)`；
  `n.aux = icon`、`n.text = label`、`n.aux2` 由 `arrange` 写入项下标；
  `n.flags = flags & AUI_NAV_ITEM_DISABLED`，并从父栏复制 `cb/user`。
- `aui_nav_labels(show)`：容器标志位 `AUI_NAV_HIDE_UNSELECTED = 1`；
  `show == 0` 置位，否则清位。只作用于最近创建的导航栏。

栏自身的标志位与项的标志位数值都为 1，但作用域不同：容器上是
「隐藏未选中文字」，项上是「禁用」。

### D.50.3 几何

```
block = 32dp（胶囊）+ 4dp（间距）+ text_line_h()
item_natural_w = max(56dp, text_measure) + 8dp，且不小于 64dp
item.h = max(block, 64dp)
n.h = max(64dp, 最高子项) + 2 × pad
n.w = avail（无约束时 = 子项宽和 + 2 × pad）
```

`arrange_nav_bar` 在 `n.w - 2 × pad` 的可用宽里等分：`cw = iw / cnt`，
最后一项拿走余数，保证总宽精确。每项写入 `aux2 = 下标`，再按
`(x, n.y + pad, cw, n.h - 2 × pad)` 递归排列。栏高不固定死在 64 dp：
内容（例如大字号）更高时随之增高，避免文字被裁掉。

### D.50.4 绘制

`paint_nav_bar` 先铺 surface（`n.bg` 可覆盖），随后每个子项由
`paint_nav_item` 自绘：

- `sel = (父.aux == 自己.aux2)`；`dis = flags & DISABLED`；
  `hide = 父.flags & HIDE_UNSELECTED`。
- 内容块高 `block`，在项内垂直居中；胶囊 56×32 dp 水平居中。
- 胶囊底色：选中项主色 12%（按下 20%）；未选中项按下时文字色 8%。
- 图标 24 dp，画在胶囊中心；选中主色、未选中 hint 色、禁用文字色 38%。
- 文字单行、水平居中，位于胶囊下方 4 dp；选中主色、未选中 hint 色、
  禁用文字色 38%。`hide` 且未选中时不画文字。
- 绘制文字前把全局裁剪收窄到项自己的矩形，超长标签不会压到相邻项。

### D.50.5 输入

命中沿用普通叶子规则。`ACTION_UP` 派发到类型 46 时先做两道检查：

1. 项带 `AUI_NAV_ITEM_DISABLED` → 不回调。
2. 父栏的 `aux` 已等于项下标（点的是当前选中项）→ 不回调。

否则把 `(栏 key, 项下标)` 写入 `g_aui_nav_key / g_aui_nav_val`，再调用
容器回调；应用在回调里用 `aui_nav_value(key)` 读取请求值。没有待处理
请求时 `aui_nav_value` 回落到该栏当前的 `aux`。`aui_root()` 会把
这两个全局清零，跨页面不会串值。

### D.50.6 调试与验证

`aui_debug_nav_bar(key, out)` 输出 8 个整数：

```
[x, y, w, h, selected, items, labels_visible, pad]
```

`aui_debug_nav_item(key, out)` 输出 8 个整数：

```
[x, y, w, h, index, flags, selected, disabled]
```

找不到节点返回 -1。

`nav_bar_test`（离屏 320×320、density 160）：

- 版本 14100；栏 320×64；4 项各 80×64，下标 0..3。
- 选中项左侧指示胶囊有主色墨迹，未选中项同位置仍为白色；图标与文字
  都有墨迹。
- 点第二项回调一次，`aui_nav_value` 回读 1；重绘后选中标记与胶囊转移。
- 再点已选中项不回调；禁用 Star 不回调且 `disabled` 标记可读。
- `aui_nav_labels(0)` 后未选中项文字带无墨迹，选中项仍有。
- `selected = 9`（越界）时没有选中项与胶囊；单项时铺满 320；列内
  8 dp 内边距下栏 304 宽、项 76 宽；深色 surface `0x1E1E24`。

`nav_bar_harness`（`ui_nav_bar`，720×1280、density 420）：版本 14100；
栏贴底 720×168（y = 1112）、4 项各 180 宽；点 Search 后状态 980/981 = 1、
last = 11，再点不回调；隐藏未选中文字后 Home 的文字带无墨迹而 Search
仍有；禁用 Star 后标记可读且点击不回调；深色 surface `0x1E1E24`。

`ui_nav_bar.ast`（第 26 个功能 APK，`dev.aster.uinavbar`）：内容区展示
选中下标 / 变更次数 / 点按次数 / Last action，三个开关分别控制隐藏
未选中文字、禁用 Star 与深色；状态写 980..984 与 990/991。截图
0-initial / 1-search / 2-hide-labels / 3-disabled / 4-settings / 5-dark /
6-pressed 七张归档。

`aui_version()` 14100，trace 第二行 `V00003714`；二十八个 APK
versionCode 53 / 1.41.0；qemu 62 项全过。

## D.51 v1.42.0：侧边导航栏 NavigationPane

### D.51.1 目标与边界

对照 HuxerUI `navigation.h` 的 `NavigationPane`：屏幕左侧一条固定宽度的
侧边栏，收缩态只显示图标，展开态显示图标 + 文字；若干等宽项纵向排列，
选中项有指示胶囊。选择由应用控制（受控组件），点按只发出「请求下标」，
界面在回调里更新状态后重建。不引入宽度动画、二级展开或拖拽调整——
这些留给后续版本。

与底部导航栏不同的是，侧边栏在行里占一列而不是占满整行：宽度是组件
自己的常量（72 / 256 dp），不跟随可用宽，避免被行拉伸成整屏宽。

### D.51.2 节点与状态

新增两种节点：类型 47（侧边栏容器）与类型 48（侧边项叶子）。

- `aui_nav_pane(key, selected, expanded, cb, user)`：`push_container(47, key)`；
  `n.aux = max(selected, 0)` 存放应用给的选中下标；`expanded != 0` 置
  `AUI_NAV_PANE_EXPANDED = 1`；`cb/user` 存在容器上。
- `aui_nav_pane_item(key, icon, label, flags)`：`push_leaf(48, key)`；
  `n.aux = icon`、`n.text = label`、`n.aux2` 由 `arrange` 写入项下标；
  `n.flags = flags & AUI_NAV_ITEM_DISABLED`，并从父栏复制 `cb/user`。
- 请求槽复用底部导航栏的 `(g_aui_nav_key, g_aui_nav_val)`：`aui_root()`
  仍只需清一次；`aui_nav_value` 同时识别类型 45 与 47，两个组件同屏也
  不会互相踩。

### D.51.3 几何

```
pw = 72dp（收缩）或 256dp（展开）
hp = pad > 0 ? pad : 8dp
item.w = pw - 2 × hp
item.h = 48dp
n.h = 2 × pad + Σ item.h + gap × (cnt - 1)
```

`measure_nav_pane` 固定宽度、按列测量子项，高度取自然高；放进 `row`
时需要 `aui_align(3)` 才会被行拉伸到整高（行内子项的 align 表示纵向）。
`arrange_nav_pane` 从 `(n.x + hp, n.y + pad)` 开始逐个下放 48 dp 项，
间距取 `n.gap`，并写入 `aux2`。横向内边距与纵向内边距分开：前者叫
`hp`（默认 8 dp），后者直接用 `n.pad`，这样 `aui_pad(8)` 能得到四周
等宽的内缩。

### D.51.4 绘制

`paint_nav_pane` 先铺 surface（`n.bg` 可覆盖），随后每个子项由
`paint_nav_pane_item` 自绘：

- `sel = (父.aux == 自己.aux2)`、`dis = flags & DISABLED`、
  `expanded = 父.flags & EXPANDED`。
- 胶囊：收缩态 `min(56dp, 项宽) × 32dp` 水平居中；展开态铺满项宽。
  半径 16 dp。选中主色 12%（按下 20%），未选中项按下文字色 8%。
- 图标 24 dp：收缩态画在项中心；展开态画在 `项左 + 24dp`。选中主色、
  未选中 hint、禁用文字色 38%。
- 文字只在展开态绘制：从 `项左 + 48dp` 起、垂直居中（行高取
  `text_line_h()`），选中主色 / 未选中 hint / 禁用文字色 38%。
  绘制前把全局裁剪收窄到 `[tx, 项右 - 8dp] × 项高`，超长标签不会压到
  相邻列。

### D.51.5 输入

命中沿用普通叶子规则。`ACTION_UP` 派发到类型 48 时先做两道检查：
禁用项直接吞掉；`父.aux` 已经是自己下标时也不回调。否则写入
`(父.key, aux2)`，随后调用父栏的 `cb`。因为请求槽共享，应用在回调里
统一用 `aui_nav_value(栏 key)` 读取，无需区分底部栏还是侧边栏。

### D.51.6 验证与交付

`nav_pane_test`（离屏 320×320@160）覆盖：版本 14200；收缩栏 72×320、
项 56×48、胶囊 56×32、收缩态无文字；选中回读与胶囊转移；已选中/禁用
不回调；展开栏 256 宽、项 240 宽、文字区间与右侧裁剪；越界下标无胶囊；
行内 8 dp 内边距下的缩进；深色表面。`nav_pane_harness`
（720×1280@420 真实宿主）覆盖：收缩 189×1280、项 147×126；点 Search
的状态回读；禁用 Star；深色；展开 672 宽、项 630 宽与文字墨迹。

截图 720×1280@420：navpane-v1420-0-initial / 1-search / 2-disabled /
3-settings / 4-dark / 5-pressed / 6-expanded 七张归档。

`aui_version()` 14200，trace 第二行 `V00003778`；二十九个 APK
versionCode 54 / 1.42.0；qemu 64 项全过。

## D.52 v1.42.1：侧边栏展开后收不回去的修复

### D.52.1 现象

真机 trace（`V00003778`）里点 Expanded 后，侧边栏变成 256 dp，内容列被挤到
约 48 px，三个开关随内容列一起缩到屏幕外；再想点 Expanded 收回已经没有
可点区域，只能杀进程重开。这是示例 `ui_nav_pane.ast` 的布局问题，不是
`NavigationPane` 本身的缺陷：库只按固定 72/256 dp 画栏，宽度分配由应用的
行布局决定。

### D.52.2 原因

v1.42.0 的示例把 Expanded / Disable Star / Dark theme 三个开关放在右侧
滚动内容列里。`row` 给侧边栏固定宽、给滚动列 `weight(1)`，展开时侧边栏
吃掉 672 px（720 px 视口、420 dpi），滚动列只剩 48 px；开关按行的右对齐
排布，中心点落到视口外，命中测试自然收不到。

### D.52.3 修复

把三个开关移出行，放到根列底部、整宽的一栏（`aui_column(60)` + 三条
`aui_row`），始终占满 1080/720 宽度；行只保留侧边栏与内容列，内容列继续
`weight(1)`。这样无论收缩还是展开，开关都在同一位置可见可点，Expanded
随时能收回。侧边栏高度随之变成“视口高 − 开关栏高”（420 dpi 下 1007 px），
`nav_pane_harness` 的期望值同步改成 189×1007 / 672×1007，并新增一条
「展开后再次点 Expanded，栏宽回到 189、项宽回到 147」的断言（返回码 26）。

库代码不变，只把 `aui_version()` 升到 14201、trace 第二行改为
`V00003779`，二十九个 APK 以 versionCode 55 / 1.42.1 重打包；截图换成
`navpane-v1421-*` 七张，能看到展开态底部开关仍然完整。

## D.53 v1.43.0：可编辑组合框（ComboBox）

### D.53.1 对照与取舍

HuxerUI 的 `ComboBox` 是受控文本值 + 建议源（`ComboBoxSuggestionSource`），
`Selected` 事件带「零基下标 + 完整替换值」。AsterUI 没有闭包/委托工厂，
建议也由应用在 `build` 里按当前文本过滤后声明成节点，因此这一版采用
「触发器 + 应用声明建议 + 锚定浮层」：库负责文本编辑、几何、命中、
浮层与回调原因，匹配规则完全留给应用（示例用前缀过滤）。下标在过滤后
会指向当前序列，所以额外提供 `aui_combo_pick_key()` 回读建议 key，
应用用稳定 id 映射选项，避免「可见的是 Banana、下标 0 却对应 Apple」。

### D.53.2 API 与状态

- `aui_combo(key, hint, open, cb, user)`：类型 49 容器，hint 是空文本
  占位符；文本与 `text_field` 共用按键文本池（`text_slot(key,0)`），
  所以 `aui_text_*` 直接可用。
- `aui_combo_suggestion(key, text)`：类型 50 叶子，始终是容器的子节点，
  只有展开时才在浮层里布局/绘制/命中。
- 回调原因：`FIELD=0`（点触发器，应用展开）、`PICK=1`、`OUTSIDE=2`、
  `BACK=3`。`aui_combo_value(key)` 返回当前建议序列下标，
  `aui_combo_pick_key()` 返回被点建议的 key（外部/BACK 时为 0）。
- 全局状态：`g_aui_combo_open/key/val/pick/reason/press/down/dx/dy/drag`
  与浮层矩形 `px/py/pw/ph/vis`。`aui_root()` 每帧重置 open/key/val/pick/
  reason 和矩形；按压/拖动属于输入状态，由 DOWN/UP/CANCEL 清理。
- 互斥：与对话框、底部弹层、菜单、下拉选择、锚定浮层互斥；打开一个新
  组合框会先 `tip_dismiss()`。

### D.53.3 几何

- 触发器高度 = max(48 dp, 行高 + 20 dp) + `pad*2`；默认 pad 12 dp，
  160 dpi 为 72 px，420 dpi 为 189 px（48 dp 行 = 126 px，pad = 31.5 px）。
- 宽度：父级是列/根/滚动（kind 1/2/9）时铺满可用宽，否则取
  「提示/文本宽 + 左右 pad + 左 16 dp + 箭头槽 10 dp + 右 16 dp」，
  最小 160 dp。
- 浮层：宽 = 触发器宽并夹到内容区左右 8 dp 边距以内；每项 48 dp、
  上下 pad 6 dp、项左右缩 4 dp；放不下下方时翻到上方，最后夹进内容区。
  内容超高时 `vis` 只摆得下多少，`ph = vis*item + pad*2`（Q16 计算后
  取整，420 dpi 两项为 283 px、一项为 157 px）。
- 触发器聚焦时边框 2 dp 主色；否则 1 dp HINT。右侧画 10×6 dp 下三角。

### D.53.4 半模态与输入

展开的浮层会盖住屏幕键盘上方区域，但键盘仍需可点。做法：`hit_test`
在根分支里先处理组合框——命中触发器/浮层/建议返回节点或 -1，浮层
padding 返回 -2，**键盘键（`find_kind(...,11)`）回退到普通命中**；
DOWN 分支记录 `g_aui_combo_down`，UP 分支只在 `find_kind(hit,11)<0`
时走组合框逻辑。于是点键盘键不会先把列表关掉，打字后应用重建、
建议按新文本过滤。BACK 优先关闭组合框（reason=3），再交给页面栈。

### D.53.5 绘制与测试

触发器表面 SURFACE、按下 PRESSED、占位符 HINT、文字 TEXT 并裁剪到箭头
左侧；浮层是 1 dp HINT 边框 + 11 dp 圆角 SURFACE，逐条画建议，按下项
用 PRESSED 圆角块。建议项文字 TEXT、垂直居中、裁剪。

验证：

- `combo_test`（离屏 320×320@160）：版本 14300；触发器
  `[0,0,320,72]`、3 条建议；占位符/箭头墨迹；点按 reason=0 且聚焦；
  浮层 `[8,76,304,156]`、首项 `[12,82,296,48]`；聚焦底边主色；点建议
  reason=1、下标 0、key 11；输入 "Ap" 剩 2 条、浮层高 108、点第二条
  key 12；输入 "B" 剩 1 条、高 60；外部点击与再点触发器 reason=2；
  清空后深色触发器/浮层表面 0x1E1E24。
- `combo_harness`（720×1280@420 假宿主）：触发器 `636×189`；点开聚焦、
  空文本无浮层、键盘出现；点键 9045（b）后过滤成 2 条，浮层
  `[42,424,636,283]`、首项 `[52,434,615,126]`；BACK reason=3 且文本保留；
  再展开点第一条写回 Banana（6 字符、key 13）、键盘收起；只剩 1 条时
  浮层高 157；点外部 reason=2；Clear 清空并保持展开；深色下触发器与
  浮层都是 0x1E1E24，建议文字有墨迹。
- 版本升到 14300 / trace `V000037DC`；全部 30 个 APK 用 versionCode 56 /
  1.43.0 重打包，qemu 66 项全过。

## D.54 v1.44.0：文本抗锯齿与输入光标位置

### D.54.1 反馈里的两个现象

真机截图（`V000037DC`，420 dpi，ui_combo 聚焦态）暴露两点：

1. 空输入框聚焦时，**光标停在占位符末尾**（“Type a fruit name...|”）。
2. **文字发毛发虚**：笔画边缘有明显的台阶和断线，跟系统 UI 字体差得远。

第一点是逻辑错误。`paint_combo` 先取 `combo_text_len()`，空文本时把
`s` / `tlen` 就地替换成占位符字符串继续走绘制，后面算光标宽度
`text_measure(s + st, draw_len)` 用的正是替换后的长度，于是光标被推到
占位符右端。`paint_field`（v1.9 的普通文本框）是同一份代码结构，同样
有这个问题，只是之前的示例很少在空文本时聚焦。

第二点是格式与实现不一致。`.auf` 头 6 的 flags 从一开始就约定
“bit0 = 8bpp alpha，否则 1bpp”，但 `gen_latin_auf.py` 一直写 1 却输出
1bpp 位图（阈值 100 二值化），`gen_cjk_auf.py` 同样写错；解析器也
只会按位展开。48 px 下二值化把字形边缘拍成硬边，细笔画（i、l、r 的
竖）还会因为低于阈值被整段丢掉，于是“发虚”。

### D.54.2 光标与占位符

两处绘制都改成先记住真实长度：

```aster
let tlen: i32 = combo_text_len(n);
let s: ptr = combo_text_ptr(n);
let real: i32 = tlen;              // 占位符不算正文
if (tlen <= 0) { s = n.text; tlen = str_len(s); color = HINT; }

let tshift: i32 = 0;
if (real <= 0 && focused != 0) { tshift = dp2q(4); }   // 占位符让开光标位
...
if (focused != 0) {
    let tw2: i32 = 0;
    if (real > 0) { tw2 = text_measure(s + st, tlen - st, 0); }
    let cx: i32 = tx + tw2;        // real == 0 → cx == x + pad
    ...
}
```

- 空文本 + 聚焦：光标在 `x + pad`（首位），占位符右移 4 dp（2 dp 光标 +
  2 dp 间隙），两者不重叠；
- 空文本 + 未聚焦：占位符仍在 `x + pad`（`tshift = 0`），外观与旧版一致；
- 有正文：光标 = `pad + 截头后可见部分的宽度`，超宽文本仍停在右端
  （`lim` 夹住），行为不变。

### D.54.3 8bpp 覆盖度字形

格式（`.auf` v1，flags bit0 = 8bpp，字形记录 `+9` 的 flags 同义）：

- 1bpp：行 `ceil(w/8)` 字节，行字是小端整数、最左像素在最高位（旧行为）；
- 8bpp：行 `w` 字节，每像素一个覆盖度 0..255，按行优先顺序排。

生成器 `gen_latin_auf.py` 增加第 7 个位置参数 `bpp`（默认 8），8bpp 时
直接把 Pillow 的灰度图写进 bitmaps；advance（`round(font.getlength(ch))`）
与墨迹包围盒（`im.getbbox()`）的算法一字未改，所以重新生成的
`font_latin48.auf` / `font_latin24.auf` 与旧文件的 advance、bbox 完全
一致——**布局尺寸零变化**，`combo_harness` 的 636×189、浮层 283 / 157
等断言原样通过。文件从 11,342 → 69,480 字节（latin48）与 4,415 →
19,088 字节（latin24）。

1bpp 的四个图集（`font_latin.auf`、`font_cjk*.auf`）把文件头 flags
由误写的 1 修正为 0，`gen_auf.py` / `gen_cjk_auf.py` 同步；这样
“flags bit0” 才真正等于“8bpp”，解析器不必猜。

光栅器在 `draw_glyph` 入口分派：

```aster
let gfl: i32 = load_u8(f + goff + 9);
if ((gfl & 1) != 0 && bw > 0 && bh > 0) {
    return draw_glyph_aa(...);   // 覆盖度 × 颜色 alpha → blend_px
}
```

`draw_glyph_aa` 按 `sc` 复制像素、按 `cl/ct/cr/cb` 裁剪，混合公式是
`a = (cov * color_alpha + 127) / 255`，再交给 `blend_px`（RGB565 与
RGBA 两条路径共用）。主字体 8bpp、CJK 回退 1bpp，同一行里可以混排，
命中判定只看当前字形的 flags。

汉字为什么不做 8bpp：`font_cjk48.auf` 有 6932 个字形，转 8bpp 后
约 11 MB，带中文的 APK 每个都要多背这份 rodata；48 px 汉字的横竖
笔画本来就是整像素宽，二值化的损失远小于拉丁细笔画。留作已知边界。

### D.54.4 回归与验证

- `combo_test` 新增返回码 14：空文本聚焦后 `(pad, 中线)` 必须是 2 dp
  主色（`chan(12,36,2) ≥ 180` 且 `chan(12,36,0) ≤ 120`），`pad+2` 处
  必须是白底（`chan(14,36,0) ≥ 200`），把“光标在首位、占位符让开”
  钉成像素断言。
- `select_harness` 的 v1.26.1 回归（English 的 g 下伸部不能被裁）原来
  采样纯色 `0x1A1A1E`；AA 后墨迹内部是覆盖度混合值，改为 3×3 邻域取
  最小 luma 并要求 < 128，语义仍是“这里有字”，裁剪回归依旧有效。
- 版本 14400 / trace 第二行 `V00003840`；30 个 APK 以 versionCode 57 /
  1.44.0 重打包，qemu 66 项全过；7 张截图重渲染（`combo-v1440-*`）。

## D.55 v1.45.0：虚拟列表（VirtualList）

### D.55.1 对照与边界

HuxerUI `list.h` 的 `VirtualList` 只把可见行实例化，行高固定，靠
`onBind(index, row)` 让应用现场填内容。AsterUI 的约束是“每帧重建整棵树、
节点池 4096、无堆”，所以采用**构建期窗口**：`build` 时按当前偏移和
上一帧视口高算出 `[first, last]`，只调用 `on_bind` 建这些行；布局后
如果视口变了或窗口没盖住可见区，置 `need_build`，下一拍重建。

本版只做固定行高。可变行高需要前缀和/索引表，节点池也不允许缓存
所有行；粘性分组头、滚动到指定行、下拉刷新组合留到后续版本。

### D.55.2 节点与状态

- 容器 kind 51：`aux = count`，`aux2 = 行高（Q16.16）`，`cb = on_tap`；
- 行 kind 52：`aux = 行高（Q16.16）`，`aux2 = 行下标`，`cb` 与 `user`
  从容器继承；
- 注册表 `g_aui_vlist_*`（16 项）：`key / 上一帧视口高 / build 时视口高 /
  first / last / off(px) / max(px)`；
- 构建上下文 `g_aui_vlist_cur_*`：`on_bind` 期间读 first/last、建行时读
  行高与回调；嵌套 `aui_vlist` 时保存/恢复；
- 点击请求 `g_aui_vlist_tap_key / tap_idx`，回调里用
  `aui_vlist_tap_index()` / `aui_vlist_tap_key()` 读取。

kind 51 已加入 `find_scroll`、`find_scrollable`、裁剪收窄/恢复、容器
背景、滚动条判断、宽度铺满（`pk == 52`）等所有相关列表；行节点按
`arrange_column` 排列，宽度铺满内容区。

### D.55.3 超长偏移：整数像素

Q16.16 i32 的上限是约 32768 px，而 5000 行 × 168 px = 840,000 px，
`count * ih` 和 `content - h` 都会溢出。处理方式：

- 虚拟列表的 `off/max` 单独存在 `g_aui_vlist_off/max`，单位是**整数
  像素**；`scroll_get/set/max/store_max` 入口用 `vlist_idx(key)` 分派，
  普通滚动容器仍是 Q16.16；
- `arrange_vlist` 用 i64 算内容高 `i32(i64(count)*i64(ih)/65536)`，
  最大偏移 = 内容高 − 视口高（像素）；
- 行位置 `ry = n.y + pad + idx*ih − off*65536` 用 i64 求和后转 i32；
- 拖动 MOVE：虚拟列表 `nv = off0 − dy`（dy 是事件像素），普通容器仍是
  `off0 − dy*65536`；
- 惯性 `fling_step`：虚拟列表 `dv = dvq >> 16`，普通容器用 Q16.16；
- 滚动条 `paint_scrollbar` 对 kind 51 用 `count*ih/65536` 算内容高，
  比例 `off/max` 两者都是像素；
- `aui_debug_scroll_max` / `aui_debug_scroll` / `aui_vlist_scroll` /
  `aui_vlist_scroll_to` 对虚拟列表直接返回/接收像素。

### D.55.4 窗口校正

构建窗口公式（不扣 `pad`，`pad` 可能在这之后才由 `aui_pad` 设置，
忽略它只会多取一行）：

```
usedpx = max(viewport_px, 480)
first  = max(off / ihpx - 1, 0)
last   = min((off + usedpx) / ihpx + 1, count - 1)
```

`arrange_vlist` 结尾按真实 `n.h` 重算 `first/last`，与注册表里已构建的
范围比较；视口变化（`n.h != used_vp`）或需要更多行时只置
`g_aui_need_build / need_layout / pump_need`，**不在 arrange 里递归
pump**，避免重入。若 `first <= 0 && last >= count-1`（所有行已建），
跳过校正。首帧没有上一帧视口时用 480 dp，第二帧按真实值补齐，画面
最多晚一帧，测试里用两帧断言。

### D.55.5 验证与交付

- `vlist_test`（离屏 320×240，1000 行 × 32 dp）：版本 14500；列表
  [0,0,320,240]；窗口 `[count=1000, first=0, last=8, off=0]`；行 0
  [0,0,320,32]、行 8 y=256、行 9 不存在；选中行底色；点第 5 行写回
  `sel=5 / taps=1`、旧行恢复白底；`scroll_to(320)` 后 first=9/last=18、
  row10 y=0、row9 y=-32、row0 不存在；max=31760；末行 y=208；节点数
  39；fling 200 帧后偏移 > 0、窗口 first > 0、row0 不存在。
- `vlist_harness`（720×1280@420，5000 行 × 64 dp）：列表
  [0,144,720,992]；行高 168；窗口 0..6；点第 4 行写回 970=4；中段
  400000 px 窗口首行 2379、末行 2387；滚到底 max=839008、末行 4999
  y=968；节点数 ≤ 200；深色背景变暗。
- `ui_vlist.ast`：第 31 个功能 APK `dev.aster.uivlist`，5000 行、固定
  64 dp 行高、点行选中、深色；截图 `vlist-v1450-0..4.png`。
- 版本 14500 / trace 第二行 `V000038A4`；31 个 APK 以 versionCode 58 /
  1.45.0 重打包，qemu 68 项全过。

Aster 编译器两个坑：大十进制字面量按 i64 处理（赋给 i32 字段会报
`TypedIR MISMATCH`，用 `32760 << 16` 规避）；i64 的 `>> 16` 不能直接
`i32()`（用 `/ 65536`）。

## D.56 v1.46.0：虚拟网格（VirtualGrid）

### D.56.1 对照与边界

HuxerUI `containers.h` / `containers.cpp` 的 `VirtualGrid` 在虚拟列表
基础上按列切分：`Columns(GridColumns)` 支持固定列数与“最小格宽自适应”，
`RowExtent / RowSpacing / ColumnSpacing / CacheExtent` 控制行高和间距，
`ItemSpans` 支持跨列，`ScrollOffsetForItem` 按项定位。AsterUI 继续沿用
“每帧重建 + 构建期窗口”的做法，本版只做规则网格：固定行高、等宽格子、
统一的行/列间距，不做 `ItemSpans`、可变行高和按项定位。

默认布局计算：

```
cols  = cols > 0 ? cols : (inner_px + gap_px) / (min_cell_px + gap_px)
cellw = (inner - gap*(cols-1)) / cols
row   = idx / cols
col   = idx % cols
x     = 内容左 + col*(cellw + gap)
y     = 内容顶 + row*(rowh + gap) - off
```

`cols <= 0` 时首帧还不知道容器宽，按 1 列保守构建；布局后实测列数写回
注册表，列数变化触发下一拍重建（最多多一帧空白）。

### D.56.2 节点与状态

- 容器 kind 53：`aux = count`，`aux2 = 行高（Q16.16）`，
  `flags` 低 16 位 = 请求列数、高 16 位 = 最小格宽（dp），`cb = on_tap`；
  打包进 `flags` 是为了不增加 `AuiNode` 尺寸（仍 96 B / 4096 池）。
- 格子 kind 54：`aux = 行高（Q16.16）`，`aux2 = 格子下标`，`cb/user`
  从容器继承；按 `arrange_column` 排列。
- 注册表 `g_aui_vgrid_*`（12 项）：`key / 上一帧视口高 / build 视口高 /
  实测列数 / 实测间距 / first / last / off(px) / max(px)`。
- 上下文 `g_aui_vgrid_cur_*` 供 `on_bind` 里 `aui_vgrid_first/last`、
  `aui_vgrid_cell` 使用；支持嵌套（保存/恢复）。
- kind 53/54 加入 measure/arrange 分派、宽度铺满、裁剪收窄/恢复、
  容器底色、滚动条、`find_scroll/find_scrollable` 与点击派发列表。

### D.56.3 偏移与单位

网格直接复用 v1.45 的“虚拟容器偏移按整数像素”方案：新增
`g_aui_vgrid_off/max`，`scroll_get/set/max/store_max` 在 vlist 之后
再查 vgrid。所有需要判断“像素还是 Q16.16”的地方统一改用
`virtual_key(key)`（列表或网格任一命中），包括拖动 MOVE、`fling_step`、
`aui_debug_scroll*` 和 `vlist_touch` 对应的 `virtual_touch`。
滚动条内容高对网格按 `pad*2 + rows*rh + (rows-1)*gap` 计算；最大偏移
= 内容高 − 视口高，全部用 i64 中间量后夹到 i32。

### D.56.4 窗口校正

构建窗口先按行算再乘列：

```
pitch  = max(rowh_px,1) + gap_px
rows   = ceil(count / ecols)
firstr = max(off / pitch - 1, 0)
lastr  = (off + usedpx) / pitch + 1
first  = firstr * ecols
last   = min((lastr + 1) * ecols - 1, count - 1)
```

`arrange_vgrid` 用真实列数重算同样的窗口，并比较 `n.h`（视口高）、
列数、间距与已构建的 `first/last`；任一变化只置
`need_build / need_layout / pump_need`，不在 arrange 里递归 pump。
列数或间距变化也会触发重建，因此旋转和自适应收敛都走同一条路径。

### D.56.5 验证与交付

- `vgrid_test`（离屏 320×240，1000 格，4 列，行高 48）：版本 14600；
  网格 [0,0,320,240]；count=1000、cols=4、窗口 0..27、off=0；格 0
  [0,0,80,48]、格 5 [80,48]、格 28 不存在；选中格底色；点格 6 写回
  `sel=6 / taps=1`、旧格恢复；`scroll_to(480)` 后窗口 36..67、格 40
  y=0、格 39 y=-48、格 0 不存在；max=11760、末格 999 [240,192]；
  节点数 < 200；fling 200 帧后偏移 > 0、窗口 first > 0、格 0 不存在；
  切到 `cols=0 / min=100` 后自适应 3 列、窗口 0..20、格 2
  [213,0,106,48]。
- `vgrid_harness`（720×1280@420，3 列，行高 120 dp）：网格
  [0,144,720,992]；315 px 行高、21 px 间距、226 px 格宽；窗口 0..11；
  点第 4 格写回 970=4；中段 50000 px 窗口首格 441、末格 455；滚到底
  max=111211、末格 999 y=821 贴底；节点数 ≤ 250；深色背景变暗。
- `ui_vgrid.ast`：第 32 个功能 APK `dev.aster.uivgrid`，1000 格、3 列、
  行高 120 dp、点格选中、深色；截图 `vgrid-v1460-0..4.png`。
- 版本 14600 / trace 第二行 `V00003908`；32 个 APK 以 versionCode 59 /
  1.46.0 重打包，qemu 70 项全过。

实现注意：`i64(rows) * i64(rhpx)` 等中间量防止 `count × 行高` 在 i32
溢出；`vgrid_cols_for` 用像素整除而不是 Q16.16 右移，保证自适应列数
稳定；`flags` 打包列数与最小格宽（16 位各一）避免扩节点。

## D.57 v1.47.0：横向虚拟列表（HList）

### D.57.1 对照与边界

HuxerUI 的 `VirtualList` 提供 `ScrollAxis(Axis::Horizontal)`
（`examples/horizontal_virtual_list` 用 10000 张固定宽度卡片演示）。
AsterUI 已有纵向 `aui_vlist`（v1.45）与二维 `aui_vgrid`（v1.46），
本版补齐横向轴，作为独立容器而不是给 vlist 加 axis 参数：

- 纵向 vlist 的窗口按“视口高”算，行高固定、宽度铺满；横向 hlist 的
  窗口按“视口宽”算，项宽固定、高度可固定或撑满。两者定位公式、
  滚动条方向和手势轴都不同，合并会让 arrange/measure 出现大量分支。
- HuxerUI 的 ItemExtent 只约束主轴（横向宽度），交叉轴由内容或父约束
  决定；因此 `item_h_dp = 0` 表示“项高撑满容器内容高”，非 0 才固定。
- 横向内容可达数十万 px（1000 × 420 px ≈ 44 万），偏移必须继续用
  整数像素表，不能回到 Q16.16。

### D.57.2 节点与状态

- 容器 kind 55：`aux = count`，`aux2 = 项宽（Q16.16）`，`flags = 项高
  （Q16.16，0 = 撑满）`，`cb/user` 从 `aui_hlist` 继承。
- 项 kind 56：`aux = 项宽`，`aux2 = 项下标`，`flags = 项高`；
  按 `arrange_column` 排列子内容。
- 注册表 `g_aui_hlist_*`（12 项）：`key / 上一帧视口宽 / build 视口宽 /
  实测间距 / first / last / off(px) / max(px)`；上下文
  `g_aui_hlist_cur_*` 供 `on_bind` 使用，允许嵌套。
- kind 55/56 加入 measure/arrange 分派、宽度铺满、裁剪收窄/恢复、
  容器底色、滚动条、`find_scroll/find_scrollable` 与点击派发列表。

### D.57.3 偏移、手势与滚动条

`scroll_get/set/max/store_max` 在 vgrid 之后查 hlist；
`virtual_key` / `virtual_touch` 把列表、网格、横向列表统一视为
“整数像素虚拟容器”。拖动会话新增 `g_aui_drag_axis`：

```
DOWN:  命中 kind 55 → axis=1，记录 x0 与 off0
MOVE:  axis=1 时 dmain = px - x0，> 8 dp 进入拖动
       速度采样 drag_sample_x()，写入同一个 g_aui_vel
UP:    原有 fling 路径不变（virtual_key 已按像素处理）
```

`paint_scrollbar` 对 kind 55 画底部横条：轨道左右各留 4 dp，条宽 =
`视口宽 × 视口宽 / 内容宽`，最小 24 dp；位置按 `off/max` 在轨道内插值。
内容宽 = `pad*2 + count*项宽 + (count-1)*间距`，最大偏移 =
内容宽 − 视口宽，均用 i64 中间量后夹到 i32。

### D.57.4 窗口校正

构建窗口按主轴算：

```
pitch = max(itemw_px,1) + gap_px
first = max(off / pitch - 1, 0)
last  = min((off + usedpx) / pitch + 1, count - 1)
```

`arrange_hlist` 用真实视口宽重算窗口，并比较 `n.w`、间距与已构建的
`first/last`；任一变化只置 `need_build / need_layout / pump_need`，
不在 arrange 里递归 pump。首帧视口宽未知时用 480 dp 保守估计，
布局后自动收敛；项高撑满模式在 measure 阶段按子内容最大高度定容器高，
arrange 再把项高统一为内容高。

### D.57.5 验证与交付

- `hlist_test`（离屏 320×240，1000 项，项宽 80，项高撑满）：版本
  14700；列表 [0,0,320,240]；count=1000、窗口 0..5、off=0；项 0
  [0,0,80,240]、项 3 x=240、项 6 不存在；选中项底色；点项 3 写回
  `sel=3 / taps=1` 且旧项恢复；`scroll_to(480)` 后窗口 5..11、项 9
  x=240、项 8 x=160、项 0 不存在；max=79680、末项 999 x=240；
  节点数 < 200；fling 200 帧后偏移 > 0、窗口 first > 0、项 0 不存在；
  切到 100 px 项宽 / 48 px 项高 / 8 px 间距后窗口 0..3、项 2
  [216,0,100,48]、max=107672。
- `hlist_harness`（720×1280@420，项宽 160 dp，间距 8 dp，项高撑满）：
  列表 [0,144,720,992]；420 px 项宽、21 px 间距、992 px 项高；窗口
  0..2；点第 0 项写回 970=0；中段 50000 px 窗口 112..116；滚到底
  max=440259、末项 999 x=300 贴右；节点数 ≤ 250；深色背景变暗。
- `ui_hlist.ast`：第 33 个功能 APK `dev.aster.uihlist`，1000 张卡片、
  项宽 160 dp、横滑、点项选中、深色；截图
  `hlist-v1470-0..4.png`。
- 版本 14700 / trace 第二行 `V0000396C`；33 个 APK 以 versionCode 60 /
  1.47.0 重打包，qemu 72 项全过。

实现注意：`i64(count) * i64(iwpx)` 防止 i32 溢出；项宽与间距都按像素
取整后再算 pitch，保证窗口与 arrange 用同一套整数；`flags` 直接存
Q16.16 项高，不扩节点（AuiNode 仍 96 B / 4096 池）。

## D.58 v1.48.0：按压水波纹（Indication）

### D.58.1 对照与边界

HuxerUI 把点击反馈拆成 indication 层：按下时在控件内部画一圈主色状态层，
扩散并随松手淡出（`indication.h` / `src/components/indication.cpp`）。
AsterUI 本版只实现其中的“按压水波纹”，并且作为**行为层**而不是新控件：

- 不新增节点类型，`AuiNode` 仍 96 B、池仍 4096；波纹状态放在
  `g_aui_ripple_*` 一组全局量里，`paint_node()` 在画完节点自身内容、
  进入子树之前调用 `ripple_paint()`。
- 默认关闭（`g_aui_ripple_on = 0`），保证 v1.47 及以前的所有截图、
  像素断言与测试完全不变；应用调用 `aui_ripple(1)` 后才生效。
- 只挂在通用 clickable 路径（`find_clickable`）上：按钮、图标按钮、芯片、
  标签页、分段、导航项、列表行/格/横向项等自动获得；对话框、弹层、
  浮层、下拉、组合框、日期/时间、分页等自带按压/拖动逻辑的容器不画，
  避免状态层叠加。
- 颜色 = 主题主色，alpha 31（约 12%）；320 ms ease-out 扩散，按住保持
  满 alpha，松手后 220 ms 线性淡出。与 HuxerUI 的时长/透明度一致。

### D.58.2 状态与虚拟项身份

全局量：`on / phase(0 空闲,1 按住,2 淡出) / key / x,y（触点 px）/
t0 / up / rad / alpha / maxr / age`，以及虚拟项身份
`vkind / vidx / vbase`。按下时 `ripple_press()` 记录触点、`t0 =
anim_now()`、`phase = 1`，并用触点到节点四角的最远距离求 `maxr`；
`g_aui_need_paint = 1` 并 arm 16 ms 帧定时器。

列表行（kind 52）、网格格（54）、横向项（56）的 key 都是 0，不能用 key
区分。按下时若节点属于这三类，读取父容器 key 存入 `vbase`，并记录
`(kind, aux2)` 作为 `vkind/vidx`；绘制时按这三元组匹配，所以点击引起的
重建、滚动换窗后波纹仍跟随原来的项，不会画到相邻行。

松手检测放在 `ripple_step()`：当 `g_aui_pressing == 0` 或
`g_aui_press_key != g_aui_ripple_key` 时把当前帧时间写入 `up`、
`phase = 2`。拖动取消按压、点击导致重建都会走这条路径。淡出满 220 ms
后一次性清零 key/rad/alpha/虚拟身份，并置重绘。

### D.58.3 绘制：逐行扫描 + 三重裁剪

`ripple_paint()` 先按 key 或 `(vkind,vidx,vbase)` 判断当前节点是否命中，
然后取 `r = rad`、`a = alpha`，把节点矩形与 `g_aui_clip_x/y/w/h` 求交；
节点自身圆角按行内缩：上下两端每行用 `rad - isqrt(rad² - d²)` 往内收，
中间行不收。扫描从 `cy-r` 到 `cy+r`，行高
`step = max(1, r/96)`，每行求圆在该行的半宽 `isqrt(r²-dy²)`，再与裁剪
区间求交，生成一条 op=1 的矩形命令：

```
color = (a << 24) | (primary & 0xFFFFFF)
```

因此一个再大的控件最多约 96 条命令，4096 条命令池不会被单个波纹耗尽；
条带在圆边缘处仍是整数像素行，不做抗锯齿（状态层本身是半透明色块，
视觉上足够平滑）。绘制顺序保证波纹盖住节点背景与自身文字，但在子项
内容之下——列表行里的文字与图标仍清晰可见。

### D.58.4 帧泵与生命周期

`ripple_busy()` 在 `phase != 0` 且（已松手或半径未到 `maxr`）时返回 1。
它被加入：`aui_frame` 的补时钟条件、`pump_frame_once` 的 active 判定、
空闲分支、帧尾 idle 检查、`frame_timer_disarm/sync` 与 `fling_stop`
条件。效果是：按住时只在扩散阶段持续出帧，扩散完停在满 alpha 不再
要求 16 ms 节拍；松手后一直出帧到淡出结束。

`aui_ripple(0)` 立即清零相位与半径并置重绘，用于“减少动效”开关。
`aui_ripple_active()` 返回 0/1/2；`aui_debug_ripple(out)` 输出
`[key,x,y,rad_px,alpha,phase,max_r,elapsed_ms]`，其中 `elapsed_ms` 由
`ripple_step` 写入 `g_aui_ripple_age`，避免在调试函数里重算时间。

### D.58.5 验证与交付

- `ripple_test`（离屏 320×240，density 160；20 行 × 60 px 的 vlist key 30
  + 底部按钮 key 50）：默认关闭时按住 80 ms 无波纹且触点为白；打开后
  按 (250,30)，按下瞬间 `phase=1 / rad=0 / age=0`，80 ms 后 `rad>0`、
  `rad<maxr`、`alpha=31`、主色 12% 叠白（R<245 且 B>R）、相邻行纯白；
  松手后 220 ms 内 alpha 递减并清零、触点恢复纯白；`aui_ripple(0)`
  立即清除；按住按钮时 key=50、触点为 (36,216)；命令数 < 1000、
  节点数 < 200。
- `ripple_harness`（720×1280@420，`ui_ripple`）：列表行按住 80 ms 后
  `age≈80 / phase=1 / alpha=31`，半径在下一帧继续增长；旁边一行不染色；
  松手 220 ms 后恢复纯白且 `aui_ripple_active()==0`；按钮波纹 key=20；
  点 Tap 计数 +1；点 Toggle 关闭后按住不再出现波纹；节点数 ≤ 120。
- `ui_ripple.ast`：第 34 个功能 APK `dev.aster.uiripple`，20 行、
  按住扩散、Toggle 关闭、状态回显与深色；截图
  `ripple-v1480-top/hold80/hold240/fade/dark.png`。
- 版本 14800 / trace 第二行 `V000039D0`；34 个 APK 以 versionCode 61 /
  1.48.0 重打包，qemu 74 项全过。

实现注意：`ripple_press()` 只在 `ripple_allowed(kind)` 且开关打开时生
效；`maxr` 至少为 1，避免零尺寸控件除零；淡出阶段仍用同一个
`g_aui_ripple_rad`，所以松手后不会突然缩回；`elapsed_ms` 是按下至今的
毫秒数而不是淡出计时，淡出进度单独用 `up` 计算。

## D.59 v1.48.1：按压水波纹的节奏修正

D.58 是 v1.48.0 的记录；本节修正它在真机上的卡顿感，接口、默认关闭策略
与视觉构成都不变。问题不是单一的绘制耗时，而是时间曲线、帧泵节拍、松手
唤醒和扫描带高度四件事叠加。

### D.59.1 四个原因

1. **扩散曲线前冲**。`ease-out = 1-(1-t)²` 在 320 ms 里前 1/3 时间就跑完
   一半半径，后 200 ms 半径变化只剩几像素，观感是“冲一下、停住、再淡出”。
   HuxerUI `RippleEffect::expansion` 默认是 `320 ms / Linear`，参考实现
   并没有前冲。
2. **帧周期 = 绘制 + 16 ms**。泵线程画完一帧后固定 `poll(..., 16)`，软件
   光栅在 720×1280 上若花 10 ms，实际周期就是 26 ms（约 38 fps）；即使
   绘制只要 2 ms，也要 18 ms，容易错过 60 Hz 的 vsync。
3. **按住超时后松手不唤醒**。扩散结束后 `ripple_busy()` 返回 0，帧定时器
   disarm；UP 只置 `need_paint`，没有重新 arm。`ripple_step()` 只有在下一
   帧才会看到 `g_aui_pressing == 0`，而下一帧最坏要等 poll 的 250 ms 兜底，
   表现为“松手后停一下才开始淡出”。
4. **扫描带过粗**。`step = r/96`，在 420 dpi、半径 700 px 时一条带 7 px，
   圆边是 7 px 的台阶；动画推进时边缘在台阶之间跳，主观上也是“卡”。

### D.59.2 改动

- `ripple_step()` 直接用 `p = age/320ms` 乘 `maxr`，删除 `1-(1-t)²`。
- 泵线程新增 `g_aui_pump_tick`：每帧结束记时刻，下一拍
  `timeout = 16 - elapsed`（下限 1 ms）。这样绘制耗时被吸收进 16 ms 周期，
  绘制超过 16 ms 时下一拍立即重画，不再额外叠加一个完整睡眠。
- 新增 `ripple_release_now()`，在 `aui_on_input()` 处理完一批事件后调用：
  若相位为 1 且 `g_aui_pressing == 0`（或按压 key 已变），立即写 `up`、
  置相位 2、置重绘并 `frame_timer_arm()`。它覆盖所有松手/拖动取消分支，
  不依赖下一帧；`ripple_step()` 里的旧检测保留为兜底。
- `ripple_paint()` 的带高改为 `step = clamp(r/320, 1, 2)`：典型行内半径
  就是 1 px，一屏最多约 1280 条命令，仍远低于 4096 条命令池。

### D.59.3 验证

- `ripple_test`：UP 之后**不喂任何帧**，`aui_debug_ripple` 的 `phase`
  已经是 2、`alpha` 仍为 31；随后 10 ms 的首帧 alpha 已下降；450 ms
  （松手后 160 ms）仍大于 0，550 ms 清零并恢复纯白。
- `ripple_harness` 新增一段：按住到 400 ms（`rad == max_r`、`phase == 1`），
  UP 后不喂帧直接断言 `phase == 2 / alpha == 31`；+100 ms alpha 下降，
  +250 ms `aui_ripple_active() == 0` 且触点恢复纯白。原有点按、Toggle
  关闭、按钮 key、节点数断言保持通过。
- 版本 14801 / trace `V000039D1`；34 个 APK 以 versionCode 62 / 1.48.1
  重打包；qemu 74 项全部 `exit=0`；截图按线性节奏重出。

### D.59.4 边界

`g_aui_pump_tick` 只影响帧泵线程的等待时长，不改变动画的时间基准：
所有动画仍按 `clock_ns()` / 注入的 `aui_frame(t)` 求值，掉帧只会跳步，
不会变慢或变快。`ripple_release_now()` 在输入锁内调用 `frame_timer_arm()`，
与其他输入分支的唤醒方式一致；无宿主测试里 `frame_timer_arm()` 直接返回，
不影响离屏断言。

## D.60 v1.48.2：帧泵 tick 的位置修正

D.59 的等待公式写对了，但 `g_aui_pump_tick` 记在了 `pump_frame_once()`
之后。设绘制耗时 c，则循环是“画 c → 记 tick=结束 → 下一轮 el≈0 →
再睡 16 ms”，周期仍是 c + 16 ms，与旧实现完全相同。D.59 在真机上因此
没有改善。

D.60 把 tick 改记在 `pump_frame_once()` **之前**（即本帧开始），并把
timeout 下限从 1 ms 改为 0：

```
tick = clock_ns();            // 本帧开始
paint();                      // c ms
el   = now − tick;            // ≈ c
sleep(max(0, 16 − el));       // 补足到开始后 16 ms
```

于是 c=10 ms 时只睡 6 ms，周期约 16 ms；c≥16 ms 时 timeout=0，下一拍
立即重画，周期由绘制能力决定，不能再额外叠加 16 ms。`poll` 的 0 超时是
非阻塞检查，不会空转：只有 `g_aui_pump_need != 0` 时才走这条路径，空闲
仍是 250 ms 兜底。

版本 14802 / trace `V000039D2`；接口、波纹曲线、扫描带与测试断言不变，
qemu 74 项全过。真机是否达到 60 fps 取决于软件光栅单帧耗时；若 c 本身
超过 16 ms，只能保证“不额外等待”，不能凭空提速，需要继续优化绘制量或
做局部刷新。

## D.61 v1.48.2：波纹帧的局部呈现

D.60 只解决了帧间隔，没有减少单帧绘制量。设备轨迹里 1216×2688 的一帧仍要
铺满约 327 万像素的根底色，再叠十几行背景——即使帧泵按 16 ms 出帧，光栅
本身也可能超过 16 ms。波纹是“整屏只有一小块在变”的典型场景，因此这一版
在 present 阶段做 damage 裁剪。

帧泵在 `pump_ui()` 里记下本帧是否真的 build/layout 过（`g_aui_paint_full`），
`ripple_paint()` 把本次实际绘制的节点矩形（已与节点圆角/当前裁剪求交）写入
`g_aui_dmg_*`。`present_now()` 只有在以下条件全部成立时才做局部呈现：

- 没有 build/layout、没有页面转场、惯性、分页、刷新、Toast/SnackBar、
  工具提示等其它动画；
- 这一帧确实是波纹画出来的（generation 与 damage 对齐）；
- 相对上一张整屏帧，命令列表只有波纹那一段变了。

第三条靠一张整屏命令快照（`g_aui_snap_pool`，4096×64 B）实现：整屏帧
结束后保存命令；局部帧把当前列表的前缀、后缀分别与快照对齐比较。波纹
命令条数会随半径变化，所以后缀按“波纹起止下标 + 条数差”平移对齐。只要
波纹外有任何命令变化（例如 Toast 消失、输入框文字更新），就放弃局部、
退回整屏。这样“只改波纹”不是靠调用方自觉，而是每帧验证出来的。

绘制侧给每条命令的裁剪矩形再与 damage 求交（`g_aui_draw_*`），根节点的
满屏底色命令因此只填这一块，随后叠上行背景/文字/波纹，damage 内每个
像素都会被当前命令列表重新覆盖；damage 外保持不动。1216×2688 上，一条
列表行的 damage 约 1216×234 = 28 万像素，比整屏 327 万像素少一个数量级。

`ANativeWindow_lock` 的 `inOutDirty` 也传 damage 矩形，而不是全零：

- Surface 会把未重画区域从上一帧拷回新缓冲。BufferQueue 轮转时后缓冲可能
  还是两帧前的内容，没有这一步，局部帧会在 damage 外留下旧画面；
- Surface 可能因为“上一帧内容不可用”而**扩大**返回的矩形，最坏扩到全屏。
  所以锁之后按返回的矩形重画，而不是只信自己的 damage；返回空矩形时保守
  退回整屏。

快照与 damage 都只增加 BSS（256 KB 快照 + 少量标量），没有堆分配。
`ripple_harness` 新增“一条行淡出时按另一条行”段：旧行必须恢复纯白，
新行出现波纹；若局部呈现把旧波纹留在屏幕上会直接失败。假宿主是单缓冲，
像素仍与 v1.48.1 的整屏渲染逐字节一致（5 张截图 diff 为空），说明局部
绘制在 damage 内与整屏结果完全相同。

版本仍是 14802 / `V000039D2`（v1.48.2 同版修订），三十四个 APK 以
versionCode 63 重打包，qemu 74 项全过。

## D.62 v1.48.3：滚动不再被波纹拖慢

设备轨迹（仍是 v1.48.1）里每个触摸帧都是成对的：

```
N0000002E L P00000116 F
P00000116 F
```

第一帧带 N/L，是输入线程处理 MOVE 后同步 build/layout 并呈现；第二帧命令
数完全相同、没有 N/L，是帧泵在 16 ms 节拍上又画了一遍。也就是说波纹活着
的 540 ms 里（320 ms 扩散 + 220 ms 淡出），每一次滚动 MOVE 都要画两遍整屏
（1216×2688，约 327 万像素），并且波纹扫描带命令让每帧从 44 条涨到
278/161 条。这就是“上下滑动卡顿”的来源，和光栅本身无关。

两个修正：

1. **拖动/滚动立即清除波纹**。按压被手势取消时不再走 220 ms 淡出，而是
   直接清零。输入批次结束调用 `ripple_release_now()`：如果这一批里有 UP
   就淡出（正常点按），没有 UP 说明按压是被拖动/滚动/别的手势取消的，
   直接 `ripple_clear()` 并叫醒帧泵把清除结果画出来。`ripple_step()` 里
   也留了一道兜底：相位 1 且 `g_aui_dragging != 0` 时同样清零。列表一开
   始滚，波纹就消失，滚动帧不再为它绘制。

2. **有动效时输入线程不再自己画帧**。`draw_defer_to_pump()` 原来只在页面
   转场时把绘制交给帧泵；现在只要有动效在跑（转场、惯性、波纹、属性动画、
   分页、刷新）就只标脏并叫醒泵。这样同一个 16 ms 周期里只有泵画一帧，
   不会出现“输入画一帧 + 泵画一帧”。泵通过管道唤醒，不增加一整个节拍的
   延迟；泵不可用（未创建/失败）时仍回退到同步绘制。

`ripple_harness` 新增 G3 段：按住行后上拖 60 px（超过 8 dp slop），不喂帧
直接断言 `aui_ripple_active() == 0`，再喂帧、松手都保持 0。改回旧逻辑
（取消时淡出）该断言返回 35，说明测试确实覆盖到这一点。

版本 14803 / trace `V000039D3`；五张截图与 v1.48.1/1.48.2 逐字节一致，
qemu 74 项全过。真机上每帧绘制量回到滚动本身（44 条命令、一次呈现）。

## D.63 v1.48.4：滚动路径的成本拆解与削减

v1.48.3 去掉了“同一画面输入线程与帧泵各画一遍”，但滚动帧本身仍然很重：
每个 MOVE 都 `measure` 整棵树、`arrange`、全屏光栅，然后同步 present。
1216×2688 的满屏是 327 万像素，逐像素循环写 32 位在真机上就是十几毫秒，
触摸事件一密，输入线程连续被占住，表现为“上下滑动卡顿很严重”。

本版按成本从高到低做四件事：

1. **轻布局**。新增 `g_aui_layout_light` 与 `mark_scroll_dirty()`：滚动只改
   偏移，不改变节点尺寸和内容高度，`pump_ui` 见到轻布局标志就跳过
   `measure()`，直接 `arrange()`。虚拟列表/网格在 arrange 末尾发现可视窗口
   不够时仍会置 `need_build`，下一拍回到完整 build + measure，窗口纠正是
   异步的，和以前一致。任何 `aui_invalidate()` / `aui_invalidate_layout()`
   都会清掉轻布局标志，尺寸类变化不会被误跳过。
2. **拖动也交给帧泵**。`draw_defer_to_pump()` 增加 `g_aui_dragging != 0`：
   拖动 MOVE 只标脏 + `pump_wake()`，由泵按 16 ms 节拍出帧。滚动专用入口
   `aui_invalidate_scroll()` 在泵不可用时仍同步绘制，行为与旧版一致。
3. **泵唤醒节流**。输入通过管道唤醒泵时，如果离上一帧开始不到 15 ms，就
   只保留脏标志、不画这一拍；循环里的 `poll` 超时本来就补足 16 ms，于是
   120 Hz 触摸不会变成 120 次 present。定时器（惯性/动画）超时唤醒不受
   影响，因为只有管道唤醒（`poll` 返回 > 0）才节流。
4. **不透明整行宽写**。`fill_run` 的整行不透明路径一次写 4 个像素：
   RGBA8888 用两条 `store_i64`（`lo | lo << 32`），RGB565 用两条 32 位存
   （`v | v << 16`），尾部再按 2 像素/1 像素收尾。行首列任意，AArch64 的
   普通 STR 允许非对齐，不需要额外分支。半透明路径不变，圆角覆盖率路径
   仍走原来的 `fill_px_cov`。

**可观测性**：present 现在无条件记录 `w`（等窗口锁 ms）、`C`（光栅 ms）、
`t`（unlockAndPost ms），局部帧再记 `X = 宽 << 12 | 高`。这样下一份设备
轨迹能直接区分三种卡顿：`w` 大 = 等空闲缓冲/合成器；`C` 大 = CPU 光栅；
`t` 大 = 提交/合成；`X` 等于 1216×2688（`X04C00A80`）说明 Surface 把
局部矩形扩到了全屏，局部呈现在该设备上没有收益。

qemu 74 项全过；滚动/惯性/虚拟列表/拖动点击的像素与返回码不变；五张
波纹截图与 v1.48.1–1.48.3 逐字节一致。版本 14804 / `V000039D4`。

## D.64 v1.48.5：滚动不再强制重建虚拟列表

D.63 的轻布局有一个隐含前提：本帧没有 `build` 请求。设备轨迹（v1.48.3，
`V000039D3`）显示每个滚动事件后面都跟着 `N`：

    vFFFFF... N00000031 L P0000002F F

`N` 即 `g_aui_need_build`。也就是说滚动路径每次偏移变化都要重建整棵用户
树，`pump_ui` 见到 `had_build` 就把轻布局标志清掉，D.63 的“跳过 measure”
从未真正生效。根因是 `vlist_touch / vgrid_touch / hlist_touch`（经
`virtual_touch()`）无条件置 `g_aui_need_build = 1`，而拖动 MOVE 与
`fling_step` 每帧都调用。

本版三点：

1. **滚动不请求 build**。拖动 MOVE 与 `fling_step` 只
   `mark_scroll_dirty()`；`*_touch` 只留给程序化 `*_scroll_to`。
   虚拟列表可见窗口需要推进时，`arrange_vlist / arrange_vgrid / arrange_hlist`
   自己比较首末索引并置 `need_build`，下一拍完整 build。也就是说 build 的
   频率从“每帧”降到“每跨越一行窗口”。
2. **构建窗口 ±2 行**。build 阶段的首末行由 `±1` 放宽到 `±2`，
   覆盖“arrange 晚一拍才请求重建”的空档，不会露出空白行；arrange 的窗口
   判定仍用 `±1`，滚动行数/位置语义不变。
3. **滚动即清波纹**。`ripple_step()` 在 `g_aui_dragging != 0 ||
   g_aui_fling_active != 0` 时无条件 `ripple_clear()`，按压被滚动取消后
   不再保留淡出扫描带。

**回归手段**：新增 `aui_debug_build_count()` 累计 build 次数。`vlist_harness`
新增 F 段：一次 DOWN + 4×MOVE + UP 的拖动，断言 build 增量 ≤ 1、偏移确实
减小（返回 25/26）。qemu 驱动 40 步拖动对比：修复前 build 45 次，修复后
8 次，命令数仅因 ±2 窗口多出两行（0x84 → 0xA0）。

qemu 74 项全过；五张波纹截图与 v1.48.1–1.48.4 逐像素一致。版本
14805 / `V000039D5`。

## D.65 v1.48.6：持久帧缓冲与纯滚动直搬

D.64 把滚动帧的 build 和 measure 去掉了，但光栅化没动：每个滚动帧仍然
把整张命令表重放到 720×1280 的软件缓冲上，约 92 万像素/帧。真机拖动
时 `C`（绘制毫秒）居高不下，输入线程与泵线程都压在同一次全屏填充上，
观感仍是“跟手但抖”。

本版的核心判断是：滚动只改变一个偏移，画面中绝大多数像素只是整体平移。
于是把“上一帧的画面”留下来，纯滚动帧只搬移，再补新暴露的边。

### 1. 持久帧缓冲

`aui_impl.ast` 新增第 7b 节，BSS 里固定 `g_aui_fbuf: i32[1048576]`
（4 MiB）。Aster 全局数组上限 1,048,576 元素，按 RGBA 每像素一个 i32
正好覆盖 720×1280（921,600 px），再大就超出——`fb_fits()` 在
`w*h > 1048576` 时返回 0，整套快路径自动关闭，行为回到 v1.48.5。
帧缓冲记录 `g_aui_fb_w/h/ok`，窗口几何变化立即失效。

帧缓冲的保存点在 `present_now()`：整屏绘制（或直搬后的补边）完成后，
`fb_state_store()` 记录滚动 key、当前偏移（Q16.16）、视口四边、横向/
纵向，命令表快照另行保存（`g_aui_snap_*`）。

### 2. 直搬判定

`scroll_blit_plan(out)` 写 `l,t,r,b,delta`，失败码 1..13（99 = 被
`aui_debug_blit_off` 强制关闭）：

| 码 | 条件 |
|---|---|
| 1 | 本帧不是轻布局（偏移以外还改了别的） |
| 2 | 帧缓冲不可用 |
| 3 | 帧缓冲与窗口几何不一致 |
| 4 | 本帧或快照缺少滚动视口 |
| 5 | 本帧滚动 key 与快照不同 |
| 6 | 视口带圆角 |
| 7 | 视口四边与快照不同 |
| 8 | 正在翻页/波纹相位非零 |
| 9 | 动画/分页动画/下拉刷新/局部呈现/工具提示在动 |
| 10 | 选择器/组合框/对话框/底部弹层/菜单/浮层/工具提示打开 |
| 11 | 位移为 0（亚像素小数部分也会落到这里） |
| 12 | 位移 ≥ 视口尺寸 |
| 13 | 命令表快照不兼容（见下） |

`fb_cmds_ok()` 做命令层面的最后确认：

- 命令总数与快照相同；视口子树之前、之后的命令逐字节一致；
- 滚动子树之后的命令不得与视口相交（否则搬移会盖掉新画上去的浮层）；
- 紧邻视口上方（或横向时的左侧）必须是一条不透明、radius 0 的实色
  矩形：整块搬移对纯色是恒等操作，不会把底色搬出边界。

### 3. 搬移与补边

纵向（`bd != 0`）：

- 内容上移（`bd > 0`）：视口内 `[t+bd, b)` 的行搬到 `[t, b-bd)`，用
  `mem_copy_fwd`；随后重放 `[b-bd, b)` 这条新暴露的横带。
- 内容下移（`bd < 0`）：从下往上搬（`mem_copy_bwd` 按行倒序），再重放
  顶部的 `[t, t-bd)` 带。
- 无论方向，都再重放视口顶部 4 px、底部 4 px（列表的吸顶/吸底装饰与
  分隔线可能压在滚动内容上），以及视口最右 4 px 条带（滚动条/边缘）。

横向同理：`fb_shift_cols()` 按像素行搬移，补左右暴露带与上下固定条。

搬移用 8 字节整数拷贝（AArch64 允许非对齐访问），失败路径一律退回
整屏绘制，所以直搬只影响速度，不影响语义。

### 4. 测试

`vlist_harness` 新增 G 段（整像素滚动的像素等价性）：

1. 6 步整像素滚动，每步先读 `aui_debug_frame_blit()`（在 `frame_at`
   之前读），断言至少 3 帧走直搬、最后一帧仍是直搬（返回 30/31）；
2. 快照整屏 3,686,400 字节到四个 `u8[921600]` 全局数组（单个数组
   上限同上），`aui_debug_full_repaint()` 全量重绘同一偏移；
3. 逐字节对比整屏，不一致返回 32/33/34。

结果为 0：直搬后的帧缓冲与同偏移的全量重绘完全一致。开发中曾出现
3 个坏像素，最终定位到诊断函数把 136 字节写进测试栈上的局部数组
（与搬移逻辑无关）；正式路径用全局调试数组后不再复现，生产代码也不
保留探针。

qemu 74 项全过；五张波纹截图与 v1.48.1–v1.48.5 逐像素一致。版本
14806 / `V000039D6`。
