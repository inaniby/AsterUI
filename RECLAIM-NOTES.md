# 框架侧真正回收（Phase 0 前置）——盘点与实现笔记

工作树：`~/workspace/projects/AsterUI-cn-s1s2`，分支 `cn-s1s2`，HEAD `15dd1cc`（v2.20.4）。
编译器：rebase 树 `~/workspace/projects/Aster-cn-s1s2/aster`（v0.23.82-dev），只读调用；qemu-aarch64 8.2.2。
用户已定（2026-11-22 22:20）：必须先做到真正回收再开 Phase 1；固定容量 + 可诊断错误只作开发期 bound，不可作交付形态。
契约：`~/workspace/asterui-cn-s1s2/CONTRACT.md` §5；设计：`~/workspace/asterui-cn-s1s2/DESIGN.md` §4.5。
**本文件只记录事实与偏差；不改 CONTRACT.md / DESIGN.md。**

---

## 1. 盘点：每条分配路径的来源与生命周期

基线事实（实测核对，行号指 `src/aui_impl.ast`，共 24,882 行；`src/aui.ast` 1,090 行；**行号按 HEAD 15dd1cc 原文件计，本次改动在 `aui_impl.ast` 净增 278 行、其后行号相应后移**）：

### 1.1 已是帧区形态（每 build 重置，.bss 静态池，不走 arena）

| 路径 | 容量 | 重置点 | 满时行为 | 判定 |
|---|---|---|---|---|
| 节点 `g_aui_nodes` | 4096 × 96 B | `aui_root()` 约 2719 行：`g_aui_node_count = 0` | `node_alloc` 返 -1 | 已是帧区；缺高水位度量与可诊断错误 |
| 绘制命令 `g_aui_cmds` | 4096 × 64 B | 同上约 2720 行 | 返 -1（约 10492 行） | 同上 |
| 数字格式化缓冲 `g_aui_num_buf` | u8[2048] + `g_aui_num_off` | 同上 | 溢出返 null | 同上 |
| 文本行缓冲 | `AUI_LINE_CAP` 64 | 每 build 临时 | 静默截断 | 有界；截断须可诊断 |
| 工具提示瞬态 `g_aui_tip_used` | — | `aui_root()` 约 2774 行重置 | — | 每 build 瞬态 |
| 页面文本 `g_aui_page_text_used` | — | 4 处重置（调试面板重建时） | — | 瞬态 |

### 1.2 已是复用池形态（空闲槽复用，可回收）—— 本次实现的范本

| 路径 | 容量 | 复用机制 | 判定 |
|---|---|---|---|
| 动画 `anim_alloc` | 64 | 先找空槽（key==0）；满则淘汰已结束且最久未见的槽；64 全跑时返 -1；`anim_reset_all`（约 18600 行）全清，`g_aui_anim_used = 0`；`g_aui_anim_seq` 每 build +1（代数已有） | 已是复用池 |
| 延时任务 `aui_delay` | 32 | 先找空槽；handle = 槽下标；`aui_delay_cancel` 释放槽（state=0、cb/user 清零），返 1/0 | **句柄复用的范本**：回调池照此做 |
| PNG 解码池 `g_png_pool` | u8[1048576]（1 MiB） | 每图 bump 分配；解码失败回滚 `g_png_pool_used = start`（约 24868 行）；`aui_png_pool_reset()` 整体复位 | 已是池；复位靠调用方手动，不跟帧走 |

### 1.3 持久 keyed 表（append-only，永不回收，满则永久 -1）—— 须补回收或诊断

` *_slot` 按 key 查找、找不到就追加；`*_used` 只增不减。容量：

scroll 64、vlist 16、vgrid 12、hlist 12、vtable 12、pager 32、ref 16、lp（长按）32、pn（捏合）8、date 8、time 8、state 256、task（延时表另见 1.2）32。

- 这些表的 key 是 UI 元素的持久身份（如滚动容器 key、列表 key），不是每帧新生的对象；**正常使用下 key 集有界**，满表意味着 key 泄漏或 key 冲突。
- `aui_state_set` 满时**静默丢弃**（约 22458–22461 行：满则不写、仍返回 0），违反契约“容量耗尽须给可诊断错误”。
- 本次实现：keyed 表不改分配形态（key 语义决定了它不是帧区）；补两件事：① 满表时记 `A-103` 可诊断错误（不再静默）；② 给 state 表补 `aui_state_release(key)` 显式释放（其余表 key 由组件生命周期拥有，释放入口随组件销毁走，Phase 1 再补）。

### 1.4 框架自身与 arena 的关系（关键结论）

- `aui_impl.ast` / `aui.ast` 里 grep `arena|alloc(` 只命中 `node_alloc` / `anim_alloc`——**框架自身不用 arena**，全部状态在 .bss 固定池里。
- src 树里唯一用 arena 的是 `render/truetype.ast:1332` `alloc(need)` 与 `:1360` `ralloc`（字形文件缓冲倍增，旧块泄漏；增长以**不同字形文件大小**为界，不随帧数增长；代码注释已写明放弃旧块）。标准库 arena 在 `src/aster_std.ast`（`arena_base/arena_used/arena_size` 在 :729–731，单块上限 64 MiB，bump 分配，无 free list、无元数据）；`alloc(n)` 在 `:748`。
- 结论：框架的 arena 足迹 = 一个字形文件缓冲（有界于最大字形文件）。**帧区高水位探针测的是节点/命令/数字缓冲的复用，不是 arena**；arena 探针只对闭包回调有意义（见 1.5）。

### 1.5 回调现状（关键结论）

- **无 VCB 登记表、无 `g_aui_evt` 持久事件表**——那是 AsterUI-zh 2.21-zh 未提交的改动，v2.20.4 基底没有。回调只有每节点 `(cb: fn(ptr) -> i32, user: ptr)` 形态，每 build 随节点池一起重置。
- **无错误 API**：`last_err` / `last_error` grep 为空。全部 `-1` 都是静默的。
- **teardown 入口存在**：`aui_shutdown()`（约 22414 行），由 `aui_cb_destroy`（NativeActivity 销毁路径，约 22027 行）调用；已停 fling、重置动画、清 pager 拖动、重置节点数、停帧泵；**不清理** task/state/scroll 等表。回调池的退休清扫接在这里。
- 闭包 → `fn` 适配器：编译器在闭包值传给 `fn` 参数的调用点生成静态 thunk，env 在 arena 上分配、永不释放（C-2，已交主聊修复轮，排 P0 之后）。**框架侧无法 free arena 内存**；唯一不依赖 C-2 的做法是：闭包值**不经过 `fn` 参数**（不触发 thunk），而以原始 `{code, env}` 16 字节胖指针形态进入框架池，池子自己拥有内存。
- 公共 API（`aui.ast`）：全部回调都是 `cb: fn(ptr) -> i32, user: ptr` 形态；`extern let` 全局先例存在（如 `AUI_TREE_BRANCH`）。
- Headless 帧流：`aui_headless_init(build, user)` + `aui_headless_render(w, h, out)`（约 22717–22735 行），build → `pump_ui()` → `draw_cmds`。`pump_ui()`（约 16663 行）：`need_build` 时调 `g_aui_build`（即 `aui_root()` 重置节点/命令/数字缓冲），`g_aui_build_count` 每 build +1。`aui_invalidate()`（约 19557 行）置 `need_build`；headless 下 `attached == 0` 时只置标志不泵，下一 `aui_headless_render` 才泵——**1000 帧探针循环 = `aui_invalidate(); aui_headless_render(...);` × 1000**。
- 测试范式见 `tests/headless_test.ast`：`include "../src/aui.ast"`、extern 函数声明、退出码作断言、qemu 下跑；`tests/ui-checks.sh` [22/27] 编译门用 glob 自动包含新增的 `tests/*.ast`（新探针无需改脚本即可进编译门；链接/运行列表是逐个列出的，新探针直接用命令验证，不跑全套 ui-checks.sh）。VM 字体 `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc` 存在。

### 1.6 错误码段（CONTRACT.md §3 预留）

`A-100`–`A-199` 归 AsterUI 运行时，其中 `A-10x` 内存与容量、`A-12x` 线程与回调、`A-13x` 窗口与生命周期、`A-14x` 布局与挂载。本次实现用：

| 码 | 含义 |
|---|---|
| `A-100` | 节点池满 |
| `A-101` | 命令池满 |
| `A-102` | 数字格式化缓冲溢出 |
| `A-103` | keyed/state 表满（原静默丢弃处） |
| `A-104` | 文本行缓冲截断 |
| `A-120` | 回调池满（注册失败） |
| `A-121` | 句柄无效/已注销（重复注销、调用已注销句柄） |
| `A-122` | Window 已退休，拒绝新回调注册 |

`aui_last_error() -> i32` 读最近一次错误（0 = 无错误）；`aui_clear_error()` 清零。度量 getter 走现有 `aui_debug_*() -> i32` 惯例。

---

## 2. 探针实测（全部用 rebase 树二进制 + qemu-aarch64 8.2.2，探针在 /tmp/reclaim-probe/）

| # | 内容 | 结果 |
|---|---|---|
| P1 | 英文形态闭包类型参数 `closure(ptr): i32` / `closure(ptr) -> i32` | **拒**：legacy 解析器无闭包类型（"expected i8, i16, … or a struct name"） |
| P2–P4 | 英文闭包字面量 `fn[x](...)` 作实参；`let c = ...` 无标注 | **拒**：legacy 解析器无闭包字面量（"expected expression" / "expected ':'"） |
| P5 | `fn`↔`ptr` 双向赋值、双参函数类型 `fn(ptr, ptr) -> i32`、int↔ptr 互转 `ptr(h)`/`i32(hp)` | **过**：编译 + 链接 + qemu 退出 0 |
| P6a | CN 闭包类型参数 `闭包(指针): 整数`、字面量 `方法 [甲] (用户: 指针): 整数 … 结束 方法`、带标注的闭包变量、闭包调用、入口 `启动方法` | **过**（`build-cn-obj` + 链接 + qemu 退出 0） |
| P6b | CN 闭包数组 `变量 表: 闭包(指针): 整数[4] = 0` | **拒**：`[A-050] global initializer must be a compatible compile-time integer value`；去掉 `= 0` 未再试——**本实现不需要 CN 数组**（见 §3.3），不再追 |
| P7 | CN 库文件（无入口）`build-cn-obj` | **拒**：`[A-099] 程序必须定义 启动方法`；加 dummy 入口能编译，但与英文 `main` 链接报 `duplicate global symbol '_start'`。**结论：当前编译器下 CN 库文件无法作为独立对象构建**（见 §4 阻断项） |
| P8 | CN `外部("aui_cb_register_closure_ptr") 方法 注册(值: 指针): 整数` + `&闭包变量` 传指针 | **过**（编译通过）。即 CN 应用可把闭包变量地址交给英文框架函数 |
| P9 | 项目模式（`aster build` + aster.proj 多源文件） | CN 库文件可编译（入口检查按程序算）；但**英文文件在双语项目里必须用冒号返回类型**（`->` 被拒，`fn main() -> i32` 报 "expected '{' to open a block"），且 `extern fn` 声明项目内已定义的函数报 "duplicate method declaration"——双语项目内跨文件调用须走 `@导入` 模块系统（未探针）。**框架现有 `extern fn` 形态与双语 `aster build` 不兼容**（见 §4） |

---

## 3. 实现（本次落地）

### 3.1 复用池

- **回调池**（新增，`aui_impl.ast`，仿 `aui_delay` 32 槽表）：固定 64 槽；每槽存 `(fn1: fn(ptr) -> i32, fn2: fn(ptr, ptr) -> i32, env: ptr, kind: i32, state: i32, gen: i32, next: i32)`；空闲链表头 `g_aui_cb_free`；`aui_cb_register(cb, user) -> handle`（fn 形态，kind=0）；`aui_cb_register_closure_ptr(v: ptr) -> handle`（闭包形态，kind=1：`load_ptr(v)` 取 code、`load_ptr(v + 8)` 取 env——`load_ptr` 赋给 fn 变量的先例见 JNI 表读取约 11376 行）；`aui_cb_invoke(handle, arg)`（kind 0 调 `fn1(arg)`，kind 1 调 `fn2(env, arg)`；句柄无效返 -1 并记 `A-121`）；`aui_cb_release(handle)`（归还空闲链表，代数 +1，重复释放记 `A-121`）；满时记 `A-120` 返 -1。
- **节点绑定走分派 thunk**：`aui_cb_node_thunk(user: ptr) -> i32`——user 承载 handle（`ptr(handle)` 作 user，P5 已证 int↔ptr 互转可用），thunk 内按槽内登记的 `arg` 调用（fn 形态下 arg = 注册时的 user；闭包形态下 arg 由 `aui_cb_register_closure_arg(v, arg)` 指定，缺省为 0）。节点回调不再直接挂应用闭包 thunk。
- **state 表**：补 `aui_state_release(key)`；满表丢弃改记 `A-103`。
- 节点/命令/数字缓冲：分配形态不动（已是帧区）；满/溢出处改记 `A-100`/`A-101`/`A-102`。
- `aui_cb_init()` 公共重置（测试用；也清 `retired` 标志，供新 Window 附着后恢复注册）。

### 3.2 可重置帧区

- 形式化已有行为，不改分配器：`aui_root()` 开头重置节点数/命令数/数字缓冲偏移（已有），**新增**：① `g_aui_frame_seq` 每 build +1；② 高水位度量 `g_aui_frame_node_hwm` / `g_aui_frame_cmd_hwm` / `g_aui_frame_num_hwm`（在**下一 build 开始时**由 `aui_root()` 采样上一 build 的终值进 high-water——命令数只有提交后才定型，build 内采样会漏 paint 段）；③ 提交后封存 `g_aui_frame_sealed = 1`（`aui_headless_render` 在 `draw_cmds` 之后置位；Android 路径 `present_now` 末尾置位；下一 build 开始时由 `aui_root()` 清零）；④ getter `aui_debug_frame_*`。
- D-2b spec：spec 值不进 arena；Phase 0 只留接口约定（spec 走帧区/复用池），实现随 D-2b 落地——**本阶段不为 spec 新建 arena 分配**。

### 3.3 回调回收

- 注册返可注销句柄；注销后槽位进空闲链表，可立即复用（代数区分旧句柄）。
- Window 退休：`aui_shutdown()` 接 `aui_cb_retire_all()`——先置 `g_aui_cb_retired = 1`（新注册记 `A-122` 拒绝），再注销全部在用槽（回调指针与 env 清零，槽位归还）。`aui_cb_retire_all` 也可单独调用。
- **不依赖 C-2 的证明**：① 池子内存是 .bss 静态数组，adapter context 从不进入池子；② 闭包形态注册收的是 `{code, env}` 的**拷贝**（两个 ptr），不是 thunk；③ 同一闭包值注册/注销 10,000 次只复用同一槽位，不产生新 adapter context（应用侧须**创建一次、反复注册**，不要每 build 新建闭包——见 §4 残留）。
- 度量：`aui_debug_cb_used()`、`aui_debug_cb_hwm()`、`aui_debug_cb_cycles()`（注册+注销总次数）。

---

## 4. 契约与实现的冲突 / 阻断项（诚实记录）

1. **CONTRACT §5 验收探针“注册/注销同一闭包回调 10,000 次后 arena 回到基线附近”与同节“依赖 C-2，C-2 未落地前该探针预期失败”的张力**：走本实现的闭包形态登记 API（原始 `{code, env}` 指针，不经过 thunk）可使该探针**不依赖 C-2 通过**；经 `fn` 参数传闭包的老路仍泄漏、仍依赖 C-2。两者都在报告里如实区分。
2. **每个闭包创建仍有一次 arena env 快照**（以创建次数为界，不随帧数/注册次数增长），属 C-2 范畴，框架侧消不掉。收敛靠用法：注册一次、不每 build 创建。探针用同一闭包循环 10,000 次，arena 应平坦。
3. **闭包类型化登记 API（CN 文件 `src/aui_cb_zh.ast`，参数类型即 `闭包(指针): 整数`）本次不做**：P7 证明 CN 库文件当前无法作为独立对象构建（无入口被拒、有 dummy 入口链接冲突）。等价形态是英文侧 `aui_cb_register_closure_ptr(v: ptr)` + CN 侧 `外部(...)` 声明 + `&闭包变量`（P8 已证）。语义相同，只是调用方多写一行声明。**闭包类型化 API 需编译器侧改动**（允许无入口 CN 库文件，或模块化构建）——建议作为后续编译器问题 C-3 交修复轮，不在本任务硬绕。
4. **双语 `aster build` 项目模式与框架现有形态不兼容**（P9）：英文文件须用冒号返回类型；`extern fn` 声明项目内函数报重复声明，须走 `@导入` 模块系统。**本任务验证走独立对象路径**（`build-obj` / `build-cn-obj` + `link-obj` + qemu，与现有 [22/27] 测试范式一致），不走 `aster build` 项目模式。框架进双语项目的问题随 C-1（`aster build` 拒双语 APK）一并由修复轮处理；Phase 1 开工前须确认。
5. **keyed 表（scroll/vlist/…）仍 append-only**：本次只补满表诊断 + state 释放；其余表的显式释放入口随组件销毁语义在 Phase 1 补。key 集有界时这不是泄漏；key 泄漏时 `A-103` 可诊断。

---

## 5. 验证探针（本次）

- `tests/reclaim_frame_test.ast`：Counter build 循环 1000 帧（`aui_invalidate(); aui_headless_render(...);`），断言帧区高水位在第 N 帧后稳定（节点/命令/数字缓冲高水位不再增长），退出码作断言；另含节点池满（单 build 5000 标签 → A-100，节点数 4096）与数字缓冲溢出（单 build 200 个 10 位数 → A-102）检查。
- `tests/reclaim_cb_test.ast`（英文）：同一 `(fn, user)` 回调注册/注销 10,000 次，断言池 used 回到 0、cycles = 20,000、句柄复用（第二次注册拿到同一槽位的不同代数句柄）；容量逐项填满（64 回调、256 state）均返可诊断错误；退休与恢复。
- `tests/cn/reclaim_cb_cn_test.ast`（中文，**注意位置**）：创建**一个**闭包，注册/注销 10,000 次（经 `外部("aui_cb_register_closure_ptr")` + `&闭包变量`），断言 `arena_used` 回到基线附近（前后差值 = 0；闭包创建时的一次 env 快照计入基线）。**必须放在 `tests/cn/` 而不是 `tests/`**：`tests/ui-checks.sh` [22/27] 门对 `tests/*.ast` 用 `build-obj --pic` 全量编译，而 `build-obj` 走 legacy 解析器、遇非 ASCII 即报错；CN 探针只能用 `build-cn-obj` 编译，故另放子目录避开 glob。
- 以上均用 `build-obj` / `build-cn-obj` + `link-obj` + qemu-aarch64 直接验证，不跑全套 ui-checks.sh；不跑全量门禁。链接用 LIB8（`aui_impl.o + font_runtime.o + truetype.o + text.o + embeds.o + std.o + fake_ndk.o`，见 ui-checks.sh:734）；**`tests/run_qemu.sh` 的最小链接（test.o + aui_impl.o + fake_ndk.o）已失效**：`aui_impl.o` 引用 `font_runtime.o` 里的 `aui_rt_advance` / `aui_rt_set_font_path`，最小链接报 undefined symbol——这是既有状态，与本次改动无关。

### 5.1 实测结果（2026-11-22 晚，rebase 树二进制 + qemu-aarch64 8.2.2）

| 探针 | 结果 | 关键数字 |
|---|---|---|
| `reclaim_frame_test` | **过（exit 0，5.7 s）** | 1001 次 build/render；500→1000 帧节点/命令/数字缓冲高水位全相等；seq 差 500；提交后 sealed=1；节点池满 A-100 且节点数 4096；数字缓冲溢出 A-102 |
| `reclaim_cb_test` | **过（exit 0）** | 10,000 循环后 used=0、cycles=20,000、hwm=1；复用同一槽位、代数 +1；重复注销/调用已注销句柄 A-121；64 满 A-120；退休注销 2 槽、退休后注册 A-122、调用旧句柄 A-121；`aui_cb_init` 恢复；state 满 A-103、释放后可重填 |
| `reclaim_cb_cn_test` | **过（exit 0）** | 同一闭包 10,000 循环；每次调用返 8（code/env 拆分正确，即闭包值确为 {code, env}）；arena_used 终值 = 创建后基线（循环中零增长）；used=0、cycles=20,000、hwm=1 |
| 回归抽查 `headless_test` / `scroll_test`（新 aui_impl.o 链接） | **过（exit 0 / 0）** | 未动既有行为 |

- 帧探针首跑曾 exit 10（数字缓冲溢出未报 A-102）：原因是我算错了消耗量——`i32_to_str` 的 16 字节只是检查预留，实际每数只写位数+1 字节（1–3 位数约 2–4 字节），200 个小数字约 600 字节未满 2048；改为 200 个 10 位数（每数约 11 字节）后通过。实现无改动。
