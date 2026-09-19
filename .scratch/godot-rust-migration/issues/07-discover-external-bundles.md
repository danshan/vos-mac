# 07: 发现并游玩外部 bundle v2

**What to build:** 玩家在曲库发现自包含 bundle v2, 选择其中 Chart 并游玩, 搬移整个 bundle 后仍可使用.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** in-progress

- [ ] 扫描发现有效 bundle 并显示对应 Song/Chart, 选择后通过真实 v2 consumer 进入 gameplay.
- [ ] 相对资源在 bundle 内解析, 搬移后仍有效, 不依赖原构建目录或外部 MIDI CAS.
- [ ] 拒绝越界路径、无效 manifest 和损坏资源, 错误指出来源且不使其他有效歌曲不可用.
- [ ] 区分 bundle 声明身份与发现来源, 不因同名或内容相同隐式合并不同曲库; 与后续 Library Root namespace 合同兼容.


## 第一阶段: 真实 CLI catalog

catalog handler 已扫描请求 roots, 递归发现 bundle.json, 使用现有 Rust bundle 文档/资源完整性验证, 输出 schema v2 snapshot. entry 同时保留 rootPath、relativePath、sourcePath 与 bundle 声明 Song/Chart ID, 不以声明 ID 去重不同来源. 单个坏 bundle 记入 rejected, 不阻止其他有效条目返回. 根目录与 staging 不得重叠, 不跟随扫描中的符号链接.

每个任务独占 staging 下的 JobId 目录, catalog 临时文件写完并 sync 后 rename, 不覆盖已有任务输出. catalogFormats 握手现声明 BUNDLE. 真实 CLI 回归覆盖两份相同声明身份的不同来源、缺资源隔离、完整搬移后的声明身份保留、已有输出不可覆盖、取消不产出目录、空 roots 产生空 snapshot.

日志: `/tmp/vos-ticket07-catalog-red.log`, `/tmp/vos-ticket07-catalog-green.log`, `/tmp/vos-ticket07-catalog-boundaries.log`, `/tmp/vos-ticket07-workspace.log`. 尚未接 Godot catalog consumer/UI, 尚未完成从扫描结果选择到 gameplay 的联动验收. root 不可用的 last-known-good 协调归 ticket 17, 持久化 RootId 绑定归 ticket 16; 当前 snapshot 来源不是持久化选择 ID. ticket 07 保持 in-progress.
