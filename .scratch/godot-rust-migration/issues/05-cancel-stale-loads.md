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
