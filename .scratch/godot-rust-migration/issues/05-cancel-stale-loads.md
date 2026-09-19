# 05: 取消加载并隔离过期结果

**What to build:** 玩家返回、取消或切换 Chart 后, 旧加载不再干扰界面或启动错误的 gameplay.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** in-progress

- [ ] converter 调用不阻塞 Godot 主线程, 每个任务具有可追踪的进程所有权与 Load Generation.
- [ ] 取消传递到所属 helper, 有界等待后处理未退出进程; 不按模糊进程名终止无关进程.
- [ ] 切换和返回使旧 generation 失效, 迟到进度、结果和退出事件不能污染当前状态.
- [ ] 通过取消前后竞态、快速连续选择及晚到成功结果验证不启动旧 Chart, 并回收任务资源.


## 实施进度: Native worker 与 generation 协调

新增 native_load_job 与 native_load_coordinator. worker 独占 helper PID 和非阻塞管道, 主线程按帧检查完成状态并读取有限进度字节. 取消同时发送内存信号和 marker, 1 s 宽限后由所属 worker kill/reap; marker 写入失败不影响强制回收. 每次选择/取消增加 generation, 旧进度与完成事件被丢弃, 旧 worker 保留至实际退出再回收.

验收入口 `rewrite/tools/verify_native_load_coordinator.sh` 使用真实 native CLI 到 runtime, 并加入已启动的 late-success、拒绝退出/持续写 stdout/stderr、marker 不可写 helper 反例. 断言主线程持续处理帧、旧 generation 不发 ready/progress、helper 被回收、当前 generation 可运行 gameplay, 且 SOURCE_CHANGED 保留结构化错误码.

尚未接入 main_ui 的选择/返回按钮与加载页, 未关闭 ticket. 稳定 callback 在 UI 接入时仍需覆盖重入切换, Godot bundle 验证期间的块级取消、退出场景和资源回收需要继续补齐. 工作线程使用同步 loader, 因此主线程可响应, 但 app 退出时 join 仍可能等待当前音频解码完成; 不声称最终资源/响应预算已经满足.

阶段实现 `f4c28c5`, 进度 EOF 审查修复 `13a0d5a`. Spec 发现完成时可能未排空进度文件的 P2, 已用有效前缀超过单帧预算后追加非法序号、末行截断两个真实 helper 反例 RED/GREEN 修复. 当前任务完成后继续分帧读至 EOF, 拒绝残行, 不因 helper 退出而跳过验证. 最终两轴静态复审 Standards 0、Spec 0 未解决发现.

验证日志 `/tmp/vos-ticket05-async.log` 与 `/tmp/vos-ticket05-bundle-regression.log` 包含成功标记且无 SCRIPT ERROR; 原 bundle CLI/gameplay 与 21 类拒绝矩阵继续有效. 本轮无 Rust 修改, 延续 ticket 04 的 83 项累计 native 回归证据. ticket 05 继续 in-progress, 下一步为实际 UI 选择/返回及加载页接入和验证期间取消.

## 实施进度: 真实 UI 与验证取消

main_ui 已接 nativeRequest 选择记录, Loading 的 Back/Escape 接 generation 取消, 成功后实际启动既有 GameplayView/GameplayRuntime, 使用内置固定皮肤. UI 反例在旧 helper 已产出成功结果但尚未退出时返回, 随后用真实 CLI 重选并判定音符, 旧结果不切换页面. 独立 coordinator gate 补充 20 次快速选择与 progress callback 重入选择.

Godot 完整性校验、JSON 扫描、事件验证/转换及 WAV 之间增加取消 callback, native worker 直接传递受锁保护的取消状态. 特别保留 sampleless Note、STOP 与 Mirror options, 不沿用 legacy normalization 的限制丢失 native 语义. 16 个静态 PNG 与冻结布局移入 Godot assets, hash/解码 gate 覆盖实际资源; Java oracle 保留.

仍需本阶段完整迁移门禁和两轴复审后才能关闭 ticket. 单次引擎 JSON.parse/WAV 解码不可强行打断, 其资源上限归 ticket 20/24, 不声称任意输入上的硬实时退出保证.

UI cancellation 补充: native audio pool 禁止主线程 eager decode; 正在预热的旧 pool 在返回后保留到线程结束再释放. 完整 gate 暴露原 Godot render fixture 的失效开发机绝对路径, 仅将其重定位到内置皮肤, Java frozen goldens 未改. 首次 gate 的失败与重跑证据均保留, 不把纹理读取错误静默过滤.
