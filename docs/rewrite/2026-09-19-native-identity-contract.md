# Native identity 合同修订

本修订落实已批准的 Library Root / Relocation 和 Song ID 语义. 它替代旧 Phase 1 Task 2 中未实现的 VOS `packagePath + identityTitle` 草稿, 不修改冻结 Java golden corpus.

## 原始歌曲

`LibraryRootId` 是独立持久化的来源 token, 以 `library:sha256:<64 lowercase hex>` 序列化, 不由当前目录或内容派生. core 接收该 token, 不负责创建或持久化. ticket 16 的曲库配置负责新建时生成并保存, 显式重新定位时复用. 不同新增来源必须使用不同 token.

原始 Song identity 由 root token、格式 tag 和精确 root-relative path 构成. VOS/OJN 使用文件路径, osu 使用 beatmap set 目录路径, OSZ 使用包路径. 不包含显示标题、搜索字段、当前绝对路径或内容 hash. 改标题不改变身份, 搬移整个 root 并保留 token/相对路径不改变身份, 新增副本因 root token 不同而独立. 在 root 内改名不属于自动身份恢复承诺.

osu beatmap set 可以恰好位于 Library Root 本身. 使用显式 `osu_beatmap_set_at_root(root_id)` 构造, wire 中 `packagePath: null` 表示该位置; 字段缺失仍非法. 哈希使用同一 OSU_BEATMAP_SET tag 和长度为 0 的 path payload, 不与任何合法非空相对路径冲突. 通用 SourceRelativePath 继续拒绝空字符串和 `.`, 不使用当前目录 basename 作为替代.

Chart identity 在 Song ID 下区分 VOS index 0、OJN index 0/1/2 或 osu beatmap 相对路径. 不允许用未经验证的 serde 数据绕过 index 与 path 约束.

## Bundle 与 catalog 边界

`bundle_declared` 保留产物内声明的 Song/Chart ID, 不重新 hash 或改写可搬移 bundle. 这是产物 wire identity, 不构成跨 Library Root 合并曲库条目的授权. ticket 16 必须为外部 bundle 的 catalog 选择/来源建立 root namespace, 将 catalog 来源身份与 bundle 内声明身份明确关联; 不能直接以 declared ID 作为跨 root 唯一索引. 此处不宣称外部 bundle 的 catalog 组合与 UI 持久化已经实现.

## 精确 framing

固定 domain bytes 直接写入 SHA-256, 包含末尾 NUL. 数值使用 big-endian. 字符串按 UTF-8 bytes 编码, 所有 bytes/string 前加 u64 byte length. digest payload 为原始 32 bytes, 不含可读前缀.

- Source ID: domain `open2jam.source-id.v1\0`, u16 source kind tag, framed source fingerprint. Tags: VOS 1, OJN 2, OSU 3, OSZ 4, BUNDLE_V2 5.
- Sample ID: domain `open2jam.sample-id.v1\0`, framed PCM/content digest.
- Raw Song ID: domain `open2jam.song-id.v2\0`, u16 algorithm version 2, framed root digest, u16 kind tag, framed relative path. Tags: VOS 1, OJN_FILE 2, OSU_BEATMAP_SET 3, OSZ_PACKAGE 4.
- Raw Chart ID: domain `open2jam.chart-id.v2\0`, u16 algorithm version 2, framed Song ID digest, u16 kind tag, payload. Tags: VOS 1, OJN 2, OSU 3. VOS/OJN payload 为 u16 index, OSU 为 framed relative path.

`ID_ALGORITHM_VERSION` 改为 2, 避免把加入 root namespace、去除标题的算法误标为旧合同. request/result/progress schema 1 及 bundle/gameplay/catalog schema 2 不变. 旧原生 ID 草稿从未产生已发布的 catalog 或缓存, 不执行旧派生数据迁移.

旧 `identity_contract.rs` 的四个摘要仅有期望字面量, 尚无实现. 新向量同时存储 preimage hex 和独立 hashlib 结果, 明确上述 framing 后固定, 不使用 Rust 被测实现更新 expected. 旧向量和断言可从提交 `0280548` 追溯; 旧标题变化应改变 ID 的断言被新产品合同取代, 其余严格输入、不同歌曲/难度区分和 bundle declared ID 保留要求继续测试.

## 验证

```bash
python3 rewrite/tools/identity_reference_vectors.py
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test identity_contract --locked
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

参考向量位于 `native/crates/open2jam-core/tests/fixtures/identity/v2-vectors.json`. Python 工具只打印参考结果, 不自动覆盖测试期望. UI 搬移、重启、重叠目录和离线恢复仍在 ticket 16/17 验收, 不能由 core identity 单测替代.

## Catalog root token 传输

CATALOG request schema 1 新增可选 `rootIds`, 按请求中的绝对 root path 映射到 LibraryRootId. 非空映射必须覆盖 roots 的全部且仅有条目, token 不得在多个 root 间复用. CLI 不生成 token, 不根据目录或内容修复遗漏. 迁移期间未提供该字段的既有 bundle-only 调用保持原行为; raw source 接入必须要求来源 token, 不允许沿用路径身份 fallback.

提供映射时 catalog v2 entry 携带 `rootId`, Godot 使用原请求映射核对, 拒绝遗漏或替换 token. 外部 bundle 的 declared SongId/ChartId 保持原值. Godot 的 source selection key 使用 `bundle-source-` 加 SHA-256 hex, 输入为 UTF-8 JSON 数组 `[rootId, relativePath]`; 与旧无 token 调用的临时 `[rootPath, relativePath]` 区分. root 内重命名不保证身份延续, 显式重新定位复用 token 和相对路径即可保持 source selection key, 新增副本须提供新 token.

当前增量仅验证 token 的协议传递、catalog 消费和 selection key 的稳定性. token 生成/持久化、完整重新定位 UI 和跨重启选择恢复仍由 ticket 16 实现, 不由 CLI echo 或 key 比较替代验收.
