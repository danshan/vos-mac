# 05: 取消加载并隔离过期结果

**What to build:** 玩家返回、取消或切换 Chart 后, 旧加载不再干扰界面或启动错误的 gameplay.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** ready-for-agent

- [ ] converter 调用不阻塞 Godot 主线程, 每个任务具有可追踪的进程所有权与 Load Generation.
- [ ] 取消传递到所属 helper, 有界等待后处理未退出进程; 不按模糊进程名终止无关进程.
- [ ] 切换和返回使旧 generation 失效, 迟到进度、结果和退出事件不能污染当前状态.
- [ ] 通过取消前后竞态、快速连续选择及晚到成功结果验证不启动旧 Chart, 并回收任务资源.

