# Bundle v2 文件完整性合同

该阶段实现 ticket 04 的 manifest 与文件完整性边界, 不代表 Gameplay Ready. `VerifiedBundle` 只证明本次审计的 manifest、目录结构、文件长度与 SHA-256 一致; 后续 consumer 仍须验证 gameplay/audio schema、引用和运行语义. 当前测试中的 `{}` 与受控字节是文件传输夹具, 不可作为可游玩谱面.

## Manifest 与目录

`bundle.json` 使用严格 schema v2, complete 必须为 true. 身份、selector、chart ID、static assets version 和重算的 bundle key 必须一致. files 按路径严格排序且唯一, 包含 gameplay.json 与 audio-manifest.json, 不包含 bundle.json 自身. 所有文件均使用真实字节长度与 SHA-256.

完整性验证拒绝缺失或额外文件、额外目录、symlink 和非普通文件. 大小写冲突检查覆盖每个路径前缀, 包括文件/目录同名和 bundle.json 被当作目录的情况. 路径只接受既定 portable ASCII 相对路径. 搬移整个目录不改变身份或校验结果.

为限制不可信 manifest 的解析与遍历成本, 文件最大 1 MiB, entries 最多 65,536, 每条路径最多 64 个组件. 64 层限制同时限制派生父目录索引的放大, 适用于 generated bundle, 不等同于源曲库递归层数或最终曲目性能验收规模. 目录使用迭代遍历, 内容 hash 使用 64 KiB 缓冲, 不整块读取音频.

校验失败返回 CACHE_CORRUPT; 不兼容 schema 保留 UNSUPPORTED_SCHEMA. hash/size 失败附相对文件路径. 此 API 不是对抗并发恶意改写的文件句柄快照, staging ownership 与发布隔离仍须由任务生命周期层提供.

## Bundle key v1

Domain 是带结尾 NUL 的 `open2jam.bundle-key.v1`. 固定宽度数字为 big-endian, 字节和 UTF-8 字符串由 u64 长度前缀 framing. 依次输入 key algorithm u16、bundle schema u16、converter version、static assets version、SoundFont digest、Song digest、Chart digest、selector 和 source fingerprint digest.

selector tag 为 u16: VOS=1, OJN=2, osu=3, Bundle=4. VOS/OJN 追加 u16 index, osu 追加 framed relative path, Bundle 追加 framed Chart digest. SoundFont 内容 digest 参与 key, 显示 version 不代替内容身份. 绝对目录和显示名称不参与.

独立参考工具 `rewrite/tools/bundle_key_reference_vectors.py` 输出 preimage hex 和 digest; 冻结向量位于 native tests/fixtures/bundle/key-v1-vectors.json. Rust 测试读取冻结结果, 不通过被测实现生成期望值.

## 验证与剩余边界

回归包含搬移、目录大小写冲突、路径深度、错误 schema/key/identity、未知/重复字段、文件顺序/重复/必需项、路径逃逸、数量/字节上限、文件损坏、symlink 与 Unix socket. Unix socket 构造需要沙箱外测试权限. 大小写目录与过深路径回归分别保留先 RED 后 GREEN 的过程.

累计 native workspace 日志: `/tmp/vos-ticket04-bundle-workspace.log`; compile-fail doctest: `/tmp/vos-ticket04-bundle-doc.log`. 后续 ticket 04 仍须完成实际 producer/CLI、gameplay/audio 语义及 Godot 消费链路, 不关闭 ticket.

## 跨文件文档校验

新增 `load_bundle_documents` 在文件完整性验证之上读取严格 GameplayChartV2 和 AudioManifestV2, 检查 songId/chartId、源格式、Chart sample 集合与 audio assets 完全一致. 原始 VOS/OJN/osu selector 必须匹配 gameplay 源格式; BUNDLE_CHART 保留 bundle 内声明的源格式, 不把 gameplay format 改为 BUNDLE.

AudioManifestV2 的 assets 按稳定 SampleId 严格排序且唯一, 每个 asset 保存 sampleId 与 bundle 内 WAV 相对路径. 路径不允许重复或大小写冲突, 且必须出现在已经验证的 bundle 文件清单中. 本次 Godot 准备格式是 WAV, 原始 OGG/MP3/MIDI 等输入仍由对应 importer/audio preparation 转换; 此约束不缩减原始输入格式范围.

用于 bundle 资源的 SampleId 从准备完成的 WAV 文件内容 SHA-256 派生, cross-document 校验会与文件清单中的 digest 对照. 源输入指纹另行参与 bundle key, 不用原始压缩文件 digest 冒充准备后音频内容身份. 相同准备字节可复用同一 SampleId, 不同内容不得共享同一身份.

每个 gameplay/audio JSON 文档最多 64 MiB. 该限制用于有界读取, 不是曲目性能验收规模; 后续安全资源门禁仍需验证并冻结全链路上限. 读取后的同一批 JSON 字节重新核对 size/hash 后才反序列化, 不只相信之前目录遍历的 hash. 不兼容 schema 保留 UNSUPPORTED_SCHEMA, 其他文档错误或跨文件冲突返回 CACHE_CORRUPT.

`BundleDocuments` 表示已验证文档和文件引用, 不表示 WAV 成功解码、BGA 完整或 Gameplay Ready. 当前测试故意可使用不可播放的受控音频字节, 以隔离文件/身份校验边界; 必须继续补上真实 Rust 音频产物和 Godot 资源加载. 仍要求 staging ownership 隔离并发写入, 不承诺防止恶意进程在校验后改写路径.
