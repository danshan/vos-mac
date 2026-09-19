# Native gameplay artifact cache

## 所有权与身份

Godot Main UI 在用户工作目录下使用独立 `artifacts-v2` namespace, 每个完整条目目录名为 bundle key 的 64 位十六进制 digest. 不读取、迁移或删除旧 v1 cache. 应用创建并独占工作目录及其父目录; cache root 必须为绝对路径且不能是符号链接. 这不是抵抗任意外部进程并发改写应用目录的文件系统沙箱.

bundle key 已包含 Chart/Song 身份、selector、source fingerprint、schema、converter、SoundFont digest 和 static assets version. Prepared bundle 保留其声明身份及 producer 版本, 不用当前导入 CLI 的版本重写原始身份. 各 raw importer 接入时须提供真实源内容指纹, 不以 mtime 替代. 同一个 bundle 出现在不同 Library Root 中的发现身份由 catalog/Library Root 合同管理, 不能用缓存 key 代替发现来源.

## 加载与发布

worker 重新验证 prepared source, 然后核对缓存完整 manifest, 通过 Godot loader 验证 size/hash、schema、引用及 WAV 解码. 有效命中免去 converter 调用, 不免去验证. 同 key 的完整有效条目若与源 manifest 不同, 报 CACHE_CORRUPT 并保留原条目, 不任意选择其中一份内容.

miss 或损坏时调用真实 Rust CLI 生成专属 staging. Rust 验证完成后, Godot worker 再次验证, 并将已确认损坏的具体 replaceKey 随结果交回. coordinator 排空最终 progress 至 EOF, 再核对 active generation, 最后在不 yield、不触发回调的同步区间内发布. 所有 hash 与资源解码均在 worker, 发布区间只执行目录操作和已加载路径重定位.

目标不存在时 rename 完整 staging, 成功后音频绝对路径切换为 cache 路径. 目标存在时只有与 replaceKey 一致才可替换, 避免 K1 的损坏授权覆盖新版本 K2. 已确认损坏的目标先改名为包含 JobId 的 quarantine, 再 rename staging; 第二步失败时恢复旧位置. 恢复也失败时明确返回失败并保留 quarantine, 不宣称有可用缓存. 无论失败发生在哪一步, 都不会把不完整目录交给 gameplay.

## 验收证据与后续责任

`rewrite/tools/verify_native_load_coordinator.sh` 经真实 CLI/consumer 验证初次发布、命中免转换、缺文件、大小变化、同长度 hash 损坏、源变化、producer 版本变化、迟到成功取消、跨 key 替换竞态、根目录链接和文件阻挡、实际 rename 权限失败及回滚. 原有效条目与发布后音频路径也作为可观察结果检查.

`rewrite/tools/verify_native_cache_storage.sh` 创建独立 16 MiB HFS+ 临时镜像, 仅填满该镜像直到实际 ENOSPC, 再将其作为 staging 卷调用真实 CLI. Godot 必须收到 OUT_OF_SPACE, 不发布部分缓存且保留另一个有效条目. 脚本退出时先卸载再清理镜像. 该门禁需要 macOS 的磁盘镜像挂载权限, 不消耗主磁盘剩余空间来制造故障.

参考日志: `/tmp/vos-ticket06-publish-failure.log`, `/tmp/vos-ticket06-storage.log`. 完整迁移门禁另记在 ticket 06. Godot 权限失败用例依据 [Godot 4.6 FileAccess API](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html), 以真实目录权限限制触发 rename 错误.

quarantine、取消后的 staging 和异常退出残留由 ticket 22 恢复策略处理; 本实现不据缺少 UI 引用就删除未知任务目录. 缓存容量/LRU 与活跃资源 pin 归 ticket 20/21, 冷热性能预算归 ticket 24. 单个引擎 JSON/WAV 原子操作不可中断的限制继续存在, 不能把缓存命中等同于已满足最终性能门禁.
