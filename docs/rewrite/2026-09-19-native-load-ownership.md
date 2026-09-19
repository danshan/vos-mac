# Native 加载任务所有权

native_load_coordinator 是场景中的长期协调器, 使用递增 generation 区分玩家意图. 每次开始或取消都会使前一 generation 失效. 完成与进度 signal 只允许当前 generation 发送; signal 重入导致选择改变后, 再次核对 generation 才交付完成结果. 已取消任务继续保留, 直到 worker 真正退出且 Thread 已 join, 不丢弃活跃线程引用.

native_load_job 每次分配随机 JobId 和 create-new transport 目录, 将用户选择的请求复制后写入专属 request. worker 调用 OS.execute_with_pipe 的非阻塞模式, 独占返回的 PID, 持续排空 stdout/stderr. 主线程不执行或等待 helper, 不按进程名搜索或终止进程. 取消采用受 Mutex 保护的内存标志与磁盘 marker, 1 s 宽限后由唯一 PID owner 终止并 reap. marker 无法写入也不会丢失本进程内的取消请求. 对完成目录的消费还要求成功 result 的 job、命令、schema、路径和 key 与请求一致, 再由 Godot 独立 loader 验证.

主线程每帧读取最多 16 KiB progress, 保留最多 64 KiB 未完成行, 验证 job/sequence/phase/单位. worker 在非 UI 线程完成 bundle 校验与 WAV 解码后才发送结果. 取消发生在验证期间时会丢弃结果, 但目前不会在每个文件块或单次 WAV 解码内部打断. 场景退出会取消全部任务并 join; 大文件解码时仍可能等待. UI 选择/返回接入、块级取消和资源预算仍是后续实施, 不能据此关闭 ticket 05.

工作目录与 stagingRoot 应由应用创建并传入规范化绝对路径. helper 无需 shell wrapper, 生产 converter 当前不启动子进程. 不支持任意多进程 shell pipeline 的所有权推断. 应用异常退出后的孤儿 helper 与 staging 恢复仍属于 ticket 22; 活跃任务取消不替代该责任.

API 依据通过 Context7 核实的 [Godot 4.6 OS 文档](https://docs.godotengine.org/en/4.6/classes/class_os.html). [Godot Unix 实现](https://github.com/godotengine/godot/blob/4.6/drivers/unix/os_unix.cpp) 显示 kill 包含子进程回收, 因此将其放在专属 worker, 并避免 kill 后再次读取已被回收的退出状态. 测试 helper 的 PID 在 Godot 退出后还由 gate 检查不存在, 不只依赖模拟的完成状态.
