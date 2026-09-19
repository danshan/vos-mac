# Native 加载任务所有权

native_load_coordinator 是场景中的长期协调器, 使用递增 generation 区分玩家意图. 每次开始或取消都会使前一 generation 失效. 完成与进度 signal 只允许当前 generation 发送; signal 重入导致选择改变后, 再次核对 generation 才交付完成结果. 已取消任务继续保留, 直到 worker 真正退出且 Thread 已 join, 不丢弃活跃线程引用.

native_load_job 每次分配随机 JobId 和 create-new transport 目录, 将用户选择的请求复制后写入专属 request. worker 调用 OS.execute_with_pipe 的非阻塞模式, 独占返回的 PID, 持续排空 stdout/stderr. 主线程不执行或等待 helper, 不按进程名搜索或终止进程. 取消采用受 Mutex 保护的内存标志与磁盘 marker, 1 s 宽限后由唯一 PID owner 终止并 reap. marker 无法写入也不会丢失本进程内的取消请求. 对完成目录的消费还要求成功 result 的 job、命令、schema、路径和 key 与请求一致, 再由 Godot 独立 loader 验证.

主线程每帧读取最多 16 KiB progress, 保留最多 64 KiB 未完成行, 验证 job/sequence/phase/单位. worker 在非 UI 线程完成 bundle 校验与 WAV 解码后才发送结果. 取消在文件块、扫描区间和事件之间传播, 单次引擎 WAV 解码仍不可中断. 场景退出会取消全部任务并 join; 大文件解码时仍可能等待. UI 接入和块级取消已完成, 资源预算继续由 ticket 20/24 验收.

工作目录与 stagingRoot 应由应用创建并传入规范化绝对路径. helper 无需 shell wrapper, 生产 converter 当前不启动子进程. 不支持任意多进程 shell pipeline 的所有权推断. 应用异常退出后的孤儿 helper 与 staging 恢复仍属于 ticket 22; 活跃任务取消不替代该责任.

API 依据通过 Context7 核实的 [Godot 4.6 OS 文档](https://docs.godotengine.org/en/4.6/classes/class_os.html). [Godot Unix 实现](https://github.com/godotengine/godot/blob/4.6/drivers/unix/os_unix.cpp) 显示 kill 包含子进程回收, 因此将其放在专属 worker, 并避免 kill 后再次读取已被回收的退出状态. 测试 helper 的 PID 在 Godot 退出后还由 gate 检查不存在, 不只依赖模拟的完成状态.

worker 完成后, 当前 generation 仍继续按帧读取 progress 至 EOF, 并确认不存在截断末行, 才允许交付 bundle. retired generation 仅回收 worker, 不再交付其日志或结果. 对有效前缀超过 16 KiB 后追加错误序号、最终行缺失 LF 的 helper 反例均必须拒绝成功.

## UI 接入与验证期间取消

main_ui 现接受带 nativeRequest 的歌曲选择记录, 在真实 Loading 页面调用协调器. Back 按钮和 Escape 使当前 generation 失效并立即返回选歌, 原任务仍由长期协调器回收. 取消后再次选择、快速连续选择及 progress callback 中重入选择均验证不会启动旧 gameplay. 原始格式的 catalog 尚在迁移, 本阶段由受控选择记录进入 native 路径; ticket 07/后续格式 tickets 负责 discovery, 不把未迁移的 Java catalog 当作 native discovery.

受控 native 路径使用 `res://assets/o2jam` 固定布局与 16 个现有 PNG. 资源来自冻结布局和仓库皮肤, 原始 oracle 不变. asset manifest 冻结 hash, UI gate 同时检查资源 hash 与实际 PNG 解码. native Chart 使用既有 gameplay options 归一化逻辑, 并保留核心合同允许的 sampleless Note 与零 BPM STOP. Java 兼容入口的旧字段校验不变.

Godot verifier 的文件与 JSON 读取在 64 KiB 块之间检查取消, JSON 前置扫描在长 token 内检查, Chart/audio 引用验证与转换逐事件检查, 每个 WAV 解码前后检查. 原子引擎 JSON.parse、UTF-8 转换、单个 WAV 解码本身不能从 GDScript 中断, 仍在 worker 线程执行;取消后不再继续处理其余资源, 结果不会交付. 单文件内存与解码预算继续由 ticket 20/24 验收, 退出 join 不能被称为对任意大恶意输入的硬实时保证.

Native UI 音频登记关闭既有小资产集合的 eager decode, 保留逐帧异步预热. 返回时若 pool 仍在解码, 保留在 retired 列表, 后续帧确认线程结束后释放, 不在 Back 回调中 join. 应用关闭时仍由节点退出回收剩余线程.

完整迁移门禁发现旧 Godot render fixture 的纹理路径指向不存在的开发机目录. 仅替换为本项目 `res://assets/o2jam` 路径, 数值布局不变; `rewrite/golden/java-migration` 冻结内容未改. asset manifest 的 layoutSourceRevision 记录迁移前来源, 避免把可搬移路径更新误写成原始 snapshot 内容.

JSON 取消检查按跨越扫描区间触发, 不依赖游标恰好等于区间倍数, 连续转义不会跳过检查. Loading 重入仅允许 native -> native, 在修改选择记录前拒绝 legacy 活跃加载的重复请求, 避免丢失旧导出任务所有权.
