# 外部 bundle catalog 的阶段合同

native catalog CLI 已接入 bundle v2 discovery. 本文记录 ticket 07 的 CLI 阶段, 不代表 Godot 曲库 UI 已完成切换, 也不取代 ticket 16/17 的持久化曲库配置与增量刷新.

## Snapshot

请求沿用 CatalogRequestV1. 当前生成全新 snapshot, previousIndexPath 不作为扫描事实来源. 只声明 catalogFormats 中已经实现的 BUNDLE 能力; 原始 VOS/OJN/osu discovery 由后续 importer tickets 接入.

结果路径是应用 stagingRoot 下新建的 JobId 目录中的 catalog-v2.json. 每个任务创建新目录, 完整临时文件写入并 sync 后 rename, 不覆盖已有 JobId. 取消和失败不返回成功结果; 可能保留的任务临时目录交给 ticket 22 恢复流程.

文档 schemaVersion 为 2, 包含 entries 和 rejected 两个数组. 每个 entry 保存 rootPath、relativePath、sourcePath、songId、chartId、title、artist. rootPath 和 sourcePath 为规范化绝对路径; relativePath 在扫描 root 内解析, root 本身就是 bundle 时为空字符串. Song/Chart ID 原样保留 bundle 声明, 不重新 hash.

来源按 rootPath 与 relativePath 分开记录. 两个 root 中的相同 bundle 仍是两个 entry, 不按标题、字节或声明 ID 合并. rootPath 是本次扫描的物理位置, 不是持久化 LibraryRootId, 不允许直接将其 hash 当作搬移后稳定的选择身份. ticket 16 将 root 来源关联到用户配置中的持久化 token, 显式搬移沿用 token.

## 扫描与拒绝

根目录不能与其他 root 或 staging 重叠, 不能是符号链接. 递归扫描不跟随链接. 发现 bundle.json 后将所在目录作为整体 bundle 验证, 不再把其内部资源当作新歌曲扫描. 验证复用 Rust load_bundle_documents, 包含完整目录、大小/hash、跨文档身份和 sample 引用合同; 实际 WAV 解码仍由 Godot consumer 完成.

坏 bundle 在 rejected 中保存 sourcePath 和结构化 error, 不阻止同批有效 bundle 返回. entry 顺序按规范 root/path 排序, rejected 按 sourcePath 排序. sourceCount 为有效 entry 与 rejected 数量之和; 本阶段每个 bundle 是一个 Song/Chart 发现记录, songCount/chartCount 等于 entry 数量, 不去重跨来源的声明 ID.

根不可用和扫描期间目录 I/O 故障仍可能让整个 command 失败, 调用方不得据失败确认删除旧记录. 按 root 保留 last-known-good、可用性展示以及完整成功扫描后确认删除由 ticket 17 协调实现. 未接入这些行为前不能宣称完整曲库刷新已迁移.

## 证据

真实 CLI 回归见 native/crates/open2jam-cli/tests/catalog_transport.rs: 生成两个声明身份相同的受控 bundle, 一个缺资源 bundle, 验证不同来源保留、错误隔离、搬移后声明身份不变、输出碰撞不覆盖、预取消不产出目录. 空 roots 合同返回空 snapshot. 该阶段仍须完成 Godot consumer 和真实选歌到 gameplay 的联动验收.
