# 12: 安全导入并游玩 OSZ 歌曲包

**What to build:** 玩家直接导入 OSZ 中受支持的 7K 谱面, 无需手工解压并修复资源路径.

**Blocked by:** 11: 游玩本地 osu!mania 7K 谱面.

**Status:** in-progress

- [ ] 从 OSZ discovery 到 Song/Chart 选择、资源解析和 gameplay 完整可用.
- [ ] 同包多个谱面和相对音频引用保持正确, 不依赖解压临时目录的绝对位置.
- [ ] 拒绝路径穿越和越界资源访问, 解包具有明确资源约束; 最终阈值与验收工作集冻结结果一致.
- [ ] 畸形 archive、缺失音频和取消不留下可误用的完整产物.


## 当前工作: 归档读取与资源引用

- 新增尚未接入产品的 core OszArchive, 直接读取内存 ZIP, 不向文件系统解包. 复用 SourceRelativePath 拒绝 traversal/absolute/backslash, 只允许普通文件/目录与 Stored/Deflate. 音频查找保留 Java 的 root-exact、chart-relative、basename case-insensitive 顺序, fallback 多匹配明确失败.
- 引入 zip 8.6.0 的最小 deflate-flate2-zlib-rs feature, 默认压缩/加密特性关闭. Context7 与版本源码核对完成; native lock 新增 8 个包, 原依赖版本不变.
- 初始行为测试包含冻结 multi-chart/case-insensitive OSZ、CRC 损坏、危险路径、symlink、重复条目、截断与读取中取消. red /tmp/vos-osz-archive-red.log, 当前 core 记录 /tmp/vos-osz-archive-safety.log.
- 当前暂定边界: 输入 512 MiB、8192 entries、中央目录 16 MiB、单项 64 MiB、累计展开/读取 1 GiB、压缩比 1000. 尚未作为最终验收阈值, 需要后续工作集与资源 ticket 对齐.
- 已重现并修复目录回退: zip 8.6.0 会在中央目录解析失败后向前搜索其他 EOCD. metadata reader 只允许 seek 到预检查过的 EOCD/ZIP64 end record, 对其他候选立即失败且保留失败状态, 并使用 Known(0) 禁止 offset 自动猜测. 构造完成后撤除 metadata 限制以读取原始数据. 该保护依赖锁定版本的候选记录 seek 边界, 升级 zip 时必须保留真实双目录回归. red /tmp/vos-osz-directory-red.log, green /tmp/vos-osz-directory-green.log.
- 之后仍需 catalog、OSZ 包身份/selector、bundle adapter、真实 Godot gameplay、取消与产物验收. 本 ticket 所有验收复选框继续保持未完成.

- ZIP64 采用同样的目录数量/大小限制, extensible sector 也受 16 MiB 上限. /tmp/vos-osz-archive-boundaries.log 覆盖合法 ZIP64、伪造 count、尺寸/压缩比/加密拒绝, 共 8 项 core 测试. 读取时到 EOF 才接受 CRC 和长度, 不调用 extract, 取消后不继续展开剩余内容.
- 本次 metadata 限额是 core 的内存/输入边界. 完整 job 时限需要 adapter 的 checkpoint/deadline 与 helper 管理落实, 尚未宣称已交付 OSZ 的端到端资源安全门禁.
- 文档来源: Context7 /zip-rs/zip2, https://docs.rs/zip/8.6.0/zip/read/struct.ZipFile.html, https://github.com/zip-rs/zip2/blob/v8.6.0/Cargo.toml, 以及已下载 8.6.0 的 read/zip_archive.rs、read/magic_finder.rs 和 spec.rs. 加密和其他压缩算法不属于首版 OSZ reader 支持范围.
- core 增量 93a6d97 固定基点双轴复审: Standards 0 项 / Spec 0 项. workspace /tmp/vos-osz-core-workspace.log、Clippy /tmp/vos-osz-core-clippy.log、fmt 与 diff check 退出 0. 审查核对了锁定 zip 8.6 的 MagicFinder 会在返回候选前 seek 到其记录起点, 与 wrapper 的拦截边界一致. 产品接线与完整 OSZ gate 仍未完成, ticket 保持 in-progress.
