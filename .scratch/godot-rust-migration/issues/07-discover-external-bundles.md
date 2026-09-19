# 07: 发现并游玩外部 bundle v2

**What to build:** 玩家在曲库发现自包含 bundle v2, 选择其中 Chart 并游玩, 搬移整个 bundle 后仍可使用.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** done

- [x] 扫描发现有效 bundle 并显示对应 Song/Chart, 选择后通过真实 v2 consumer 进入 gameplay.
- [x] 相对资源在 bundle 内解析, 搬移后仍有效, 不依赖原构建目录或外部 MIDI CAS.
- [x] 拒绝越界路径、无效 manifest 和损坏资源, 错误指出来源且不使其他有效歌曲不可用.
- [x] 区分 bundle 声明身份与发现来源, 不因同名或内容相同隐式合并不同曲库; 与后续 Library Root namespace 合同兼容.


## 第一阶段: 真实 CLI catalog

catalog handler 已扫描请求 roots, 递归发现 bundle.json, 使用现有 Rust bundle 文档/资源完整性验证, 输出 schema v2 snapshot. entry 同时保留 rootPath、relativePath、sourcePath 与 bundle 声明 Song/Chart ID, 不以声明 ID 去重不同来源. 单个坏 bundle 记入 rejected, 不阻止其他有效条目返回. 根目录与 staging 不得重叠, 不跟随扫描中的符号链接.

每个任务独占 staging 下的 JobId 目录, catalog 临时文件写完并 sync 后 rename, 不覆盖已有任务输出. catalogFormats 握手现声明 BUNDLE. 真实 CLI 回归覆盖两份相同声明身份的不同来源、缺资源隔离、完整搬移后的声明身份保留、已有输出不可覆盖、取消不产出目录、空 roots 产生空 snapshot.

日志: `/tmp/vos-ticket07-catalog-red.log`, `/tmp/vos-ticket07-catalog-green.log`, `/tmp/vos-ticket07-catalog-boundaries.log`, `/tmp/vos-ticket07-workspace.log`. 尚未接 Godot catalog consumer/UI, 尚未完成从扫描结果选择到 gameplay 的联动验收. root 不可用的 last-known-good 协调归 ticket 17, 持久化 RootId 绑定归 ticket 16; 当前 snapshot 来源不是持久化选择 ID. ticket 07 保持 in-progress.

阶段实现 `c6d5d1e` 的两轴复审未解决项: Standards 0, Spec 0. Native workspace 精确计数 84 passed, 0 failed/ignored, fmt/Clippy 检查通过. 阶段合同见 `docs/rewrite/2026-09-19-native-bundle-catalog.md`. 下一步仍为 Godot catalog consumer/UI 联动, 不关闭 ticket.

## Godot 接入

`3dadd32` 增加 native_catalog_loader, 严格校验 snapshot 字段、请求 roots、root-relative/sourcePath 一致性、重复来源与请求元数据. NativeLoadJob 复用原 owned process、取消、最终 progress EOF 和 generation 校验, 同时支持 catalog/bundle. Main UI 配置 native converter 或 OPEN2JAM_NATIVE_CONVERTER 后, Start 从实际 settings 目录发起异步扫描, 显示 rejected 来源并保留有效条目, 选择条目进入既有 native cache/Gameplay Ready 链路.

目录物理 canonical 路径只用于扫描和重叠检查, snapshot 保留调用方 root 别名, 避免 macOS /tmp 与 /private/tmp 的有效目录映射被 consumer 误拒绝. entry 新增 sourceKind、真实 soundfont identity 和 staticAssetsVersion, 不依赖猜测或外部 SoundFont 文件. bundle 的声明 ID 不变, UI 来源 key 仅用于当前列表, 不冒充持久化 RootId.

真实门禁 `rewrite/tools/verify_native_catalog_gameplay.sh` 将库完整搬移并移除原路径后, 从 settings/Start 扫描, 在坏 bundle 旁显示有效歌曲, 点击真实选歌按钮进入 GameplayRuntime 并判定音符. 反例覆盖越界 sourcePath、relative traversal、foreign root、重复来源和坏 digest. 日志 `/tmp/vos-ticket07-ui-red.log`, `/tmp/vos-ticket07-relocated-ui.log`. 原 native 加载回归 `/tmp/vos-ticket07-load-regression.log` 保持成功; Rust workspace `/tmp/vos-ticket07-ui-workspace.log` 为 84 passed, 0 failed/ignored, Clippy 通过. 两轴复审未解决 Standards 0, Spec 0. 完整迁移门禁结束前仍不关闭 ticket.

## 完成验收

完整迁移门禁 `/tmp/vos-ticket07-full.log` 退出码 0, 最终 Godot result_flow_test 已结束. 搬移后的真实 catalog/UI gate、84 项 native workspace 及原 native load gate 均通过. 两轴审查未解决项 Standards 0、Spec 0. 四项 ticket 验收关闭, 上文阶段状态保留为过程记录.

最终 Java-free runtime/build/test/package 删除仍归 ticket 27. 本 ticket 不把 bundle discovery 的完成当作原始格式 importer、持久化 root 管理或离线刷新已完成. 后续顺序进入 ticket 08 的基础 OJN/OJM 链路.
