# 06: 复用有效缓存并安全重建损坏产物

**What to build:** 玩家重复加载可复用完整有效产物, 源变化或损坏时安全重建, 不会游玩部分或过期内容.

**Blocked by:** 05: 取消加载并隔离过期结果.

**Status:** in-progress

- [ ] 缓存身份包含 Chart、源内容指纹及相关生成版本, 有效命中复用, 源变化或版本变化正确失效.
- [ ] 缺文件、大小不符和 hash 损坏均被检测; 不只检查文件存在或时间戳.
- [ ] staging 产物经 Rust 与 Godot 合同验证后, 只由仍有效的任务原子发布.
- [ ] 中断、取消、磁盘不足和发布失败不覆盖已有有效产物, 不把部分输出暴露为可用缓存.
- [ ] 以真实 CLI/consumer 行为验证命中、miss、损坏和重建, 而非仅 mock 缓存函数.


## 第一阶段: 发布、命中与损坏重建

native worker 对 prepared bundle 的源与缓存重新校验, 比较完整 manifest, 并通过 Godot loader 验证资源. 有效命中不启动 converter. 缺失或损坏时真实 CLI 重建 staging, worker 完成 Godot 验证, coordinator 在最终 progress EOF 和 generation 检查之后执行 rename 发布. 音频绝对路径同步改为发布目录. Main UI 使用工作目录下独立 artifacts-v2 namespace.

同 key 的有效缓存与源 manifest 不同视为冲突, 不覆盖已有有效内容. 已确认损坏的旧条目先移动到 job 专属 quarantine, 发布失败尝试恢复旧位置; quarantine 清理由 ticket 22 的恢复策略统一处理. 当前阶段没有删除旧 v1 数据.

真实行为 gate `rewrite/tools/verify_native_load_coordinator.sh` 新增 native_artifact_cache_test, 覆盖首次发布、无需 converter 的有效命中、同长度 hash 损坏、长度变化和缺文件的重建. 第一阶段日志 `/tmp/vos-ticket06-cache-red.log`, `/tmp/vos-ticket06-cache-green.log`, `/tmp/vos-ticket06-repair-red.log`, `/tmp/vos-ticket06-repair-green.log`.

仍须补充 source/version 变化、取消与发布失败/磁盘不足的缓存边界及双轴审查. Raw importer 尚未迁移, 当前命中识别仅接 prepared bundle, 后续原始格式须提供实际内容指纹. 不关闭本 ticket.

## 源变化与取消边界补充

阶段提交 `c4306a2`, key 授权修复 `5810080`. 缓存源字节损坏时拒绝旧命中且保留已有有效缓存; converterVersion 变化使用独立 Python framing 生成新 key, 经真实 Rust CLI 和 Godot 验证后发布到不同条目. helper 已生成结果但 generation 被取消时不会创建缓存目录.

Spec 阶段审查发现 P2: 替换权限仅用 bool, K1 损坏后源更新至 K2 可能错误替换有效 K2. 已补 source-change-helper 反例, 先 RED 再 GREEN, 传递具体 replaceKey 并仅允许替换该 key. 对其他已存在 key 返回 CACHE_CORRUPT, 不修改其内容. 最终行为日志 `/tmp/vos-ticket06-key-race-green.log` 包含 coordinator、真实 UI、缓存成功标记, 无 SCRIPT ERROR.

下一步仍需发布失败/磁盘不足与回滚失败的可观察验证, 核对应用专属缓存路径及恢复责任, 完整门禁与最终 ticket 验收. 当前不关闭 ticket.

`5810080` 两轴阶段复审: Standards 0, Spec 0 未解决发现. 该结论不替代剩余失败场景验收.
