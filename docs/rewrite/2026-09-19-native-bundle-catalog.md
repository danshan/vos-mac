# 外部 bundle catalog 的阶段合同

native catalog CLI 已接入 bundle v2 discovery. ticket 07 已接通 Godot native 选歌路径, 本文不取代 ticket 16/17 的持久化曲库配置与增量刷新.

## Snapshot

请求沿用 CatalogRequestV1. 当前生成全新 snapshot, previousIndexPath 不作为扫描事实来源. 只声明 catalogFormats 中已经实现的 BUNDLE 能力; 原始 VOS/OJN/osu discovery 由后续 importer tickets 接入.

结果路径是应用 stagingRoot 下新建的 JobId 目录中的 catalog-v2.json. 每个任务创建新目录, 完整临时文件写入并 sync 后 rename, 不覆盖已有 JobId. 取消和失败不返回成功结果; 可能保留的任务临时目录交给 ticket 22 恢复流程.

文档 schemaVersion 为 2, 包含 entries 和 rejected 两个数组. 每个 entry 保存 rootPath、relativePath、sourcePath、sourceKind、songId、chartId、title、artist、soundfont、staticAssetsVersion. rootPath 保留请求方使用的绝对路径别名, sourcePath 由该 root 与相对路径组合; 物理 canonical 路径只用于扫描和重叠检查; relativePath 在扫描 root 内解析, root 本身就是 bundle 时为空字符串. Song/Chart ID 原样保留 bundle 声明, 不重新 hash.

来源按 rootPath 与 relativePath 分开记录. 两个 root 中的相同 bundle 仍是两个 entry, 不按标题、字节或声明 ID 合并. rootPath 是本次扫描的来源路径别名, 不是持久化 LibraryRootId, 不允许直接将其 hash 当作搬移后稳定的选择身份. ticket 16 将 root 来源关联到用户配置中的持久化 token, 显式搬移沿用 token.

## 扫描与拒绝

根目录不能与其他 root 或 staging 重叠, 不能是符号链接. 递归扫描不跟随链接. 发现 bundle.json 后将所在目录作为整体 bundle 验证, 不再把其内部资源当作新歌曲扫描. 验证复用 Rust load_bundle_documents, 包含完整目录、大小/hash、跨文档身份和 sample 引用合同; 实际 WAV 解码仍由 Godot consumer 完成.

坏 bundle 在 rejected 中保存 sourcePath 和结构化 error, 不阻止同批有效 bundle 返回. entry 顺序按规范 root/path 排序, rejected 按 sourcePath 排序. sourceCount 为有效 entry 与 rejected 数量之和; 本阶段每个 bundle 是一个 Song/Chart 发现记录, songCount/chartCount 等于 entry 数量, 不去重跨来源的声明 ID.

根不可用和扫描期间目录 I/O 故障仍可能让整个 command 失败, 调用方不得据失败确认删除旧记录. 按 root 保留 last-known-good、可用性展示以及完整成功扫描后确认删除由 ticket 17 协调实现. 未接入这些行为前不能宣称完整曲库刷新已迁移.

## 证据

真实 CLI 回归见 native/crates/open2jam-cli/tests/catalog_transport.rs: 生成两个声明身份相同的受控 bundle, 一个缺资源 bundle, 验证不同来源保留、错误隔离、搬移后声明身份不变、输出碰撞不覆盖、预取消不产出目录. 空 roots 合同返回空 snapshot. Godot 联动门禁 `rewrite/tools/verify_native_catalog_gameplay.sh` 在移走整个曲库、原位置消失后, 通过真实 settings、Start、选歌按钮进入 GameplayRuntime 并判定. 同时验证 consumer 拒绝越界路径、外部 root、重复来源及无效 SoundFont digest.

## Godot native 入口

Main UI 配置 native converter 后, Start 使用 settings 中的歌曲目录发起异步 catalog. 开发期间可以设置 OPEN2JAM_NATIVE_CONVERTER 选择该入口, 同时保留尚未移植原始格式的旧入口; 最终 Java 删除由 ticket 27 完成. 本阶段 native discovery 只列出 bundle v2, 不把未实现的 raw format 宣称为支持.

```bash
mise exec -- cargo build --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked
OPEN2JAM_NATIVE_CONVERTER="$PWD/native/target/debug/open2jam-converter" mise run godot
```

catalog 与 gameplay 使用不同 coordinator 实例, 复用 owned helper、取消和 generation 机制. worker 校验 result 的 job/command、专属 catalogPath、snapshot 字段、来源包含关系及计数, 主线程只接收当前 generation. 返回主菜单取消扫描, 失败保留内存中的既有条目并显示错误; 完整离线可用性和 last-known-good 持久化仍归 ticket 17.

consumer 从来源组合构造临时 UI key, 不将绝对路径 hash 当作持久化 SongId/LibraryRootId. nativeRequest 使用声明 Chart ID、prepared bundle 的真实 SoundFont identity 和 static assets version. BUNDLE_V2 不打开外部 SoundFont, request 中的 SoundFont path 使用 bundle manifest 位置作本地占位, 不构成外部运行依赖.
