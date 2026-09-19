# 08: 游玩基础 OJN/OJM 歌曲

**What to build:** 玩家扫描基础 OJN/OJM 歌曲, 在同一 Song 下选择不同难度并完整游玩.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** in-progress

- [ ] 原始 OJN 经 Rust catalog、bundle 与 Godot 显示和加载, 不调用 Java exporter.
- [ ] 同一 OJN 的多个 chartIndex 归于同一 Song, 各 Chart 的音符和音频关联正确.
- [ ] 基础 OJM 样本可解码并播放, timing、长音、事件顺序和源 volume/pan 精度与冻结 oracle 对照.
- [ ] 截断数据、无效长度和缺失音频有可诊断结果, 不崩溃、挂起或无界分配.
- [ ] 仅声明本 ticket 覆盖的基础 OJM 路径, 不把 OMC/M30 变体算作已完成.

## 当前增量: 有界二进制解析

- `open2jam_core::ojn::OjnSource` 读取三个难度的 metadata 和实际事件. 保留分数拍位置、稳定同拍顺序、hold/release、源 sample index 及精确 volume/pan. 文本保留原始编码字节, 尚未接入字符集解码.
- `open2jam_core::ojm::parse_plain_ojm` 提取借用的 PCM/Ogg payload, 保留空槽及两组样本编号. 不复制整个音频 payload, 不将提取等同于音频解码. OMC/M30 明确返回 UnsupportedFormat.
- 当前实现安全上限为 OJN 64 MiB / 1,000,000 个非空事件, OJM 512 MiB / WAV 索引 0..999 / Ogg 索引 1000..65535. 这些是当前解析器的拒绝边界, 不是最终性能验收规模; ticket 24 仍需用真实工作集复核. 文件 adapter 还须在读取前实施相同输入上限.
- 冻结 representative OJN 只有 header 声明的 note count, 没有实际事件. 新增 public parser seam 测试用显式事件覆盖分数位置、长音、同拍事件及 volume/pan, 原 goldens 未改动. 这些测试不等同于 timing 编译后的 Java parity.
- 验证命令: `mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked`, `mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings`.
- 待续: 字符集策略、timing 编译、音频准备、持久化 LibraryRootId 传递以及 raw OJN 的 CLI/catalog/bundle/Godot 闭环. 本 ticket 的最终验收项暂不勾选.
- 解析增量提交 `d2669aa`. 固定基点 `d4cedf802e22a4eefd08426ddba17f3cd17c2856` 的两轴增量审查: Standards 0, Spec 0. workspace 证据保存于 `/tmp/vos-ticket08-parser-workspace.log`; red 证据为 `/tmp/vos-ticket08-ojn-red.log`, `/tmp/vos-ticket08-precision-red.log`, `/tmp/vos-ticket08-ojm-red.log`, `/tmp/vos-ticket08-ojm-bounds-red.log`. 既有 Unix socket verifier 需要沙箱外执行, 沙箱内 PermissionDenied 不代表 parser 回归.

## 当前增量: OJN 时间轴

- `OjnSource::timeline` 保留 Java 的 1500 ms 起始延迟与 OJN 特有的小节位置规则: 拍号影响小节剩余时长, 不缩放事件位置. 使用 binary64 毫秒累加, 输出时四舍五入到微秒, 不逐事件量化累加值. BPM 的 binary32 源值精确转为 v2 Ratio, 超出 Ratio 可表示范围时明确拒绝.
- 小节展开最多 1,000,000 个, 循环提供取消检查; 会导致时间倒退的小节长度与无法表示的时间返回 CorruptChart. 空谱面仍有初始小节和 timing. OJN 无独立 scroll / STOP, 两条 timing track 可共享编译结果.
- public parser/timing seam 覆盖 BPM 变化、短小节、分数拍、4096 事件微秒精度、过大 measure、异常 BPM 和展开期间取消. `/tmp/vos-ticket08-java-timeline.log` 记录 Java `RenderTimingCompiler` 对同一 120 -> 240 BPM / 半小节案例的输出, 小节为 1500000/2500000/3500000 us, 音符为 2000000/3000000/3500000 us. 工作集证据为 `/tmp/vos-ticket08-timeline-workspace.log`, 首个 red 为 `/tmp/vos-ticket08-timeline-red.log`.
- 此结果仍是带时间的原始事件, 未实施 `EventList.OPEN2JAM` 长音修复及最终 playable eventOrder 分配. 不据此勾选完整 timing / 长音 parity 验收.
- 时间轴增量提交 `e86359f`, 固定基点不变. Standards 0 项, Spec 0 项; 审查认可当前增量边界, 不代表完整 ticket 验收.

## 当前增量: 长音事件修复

- `OjnTimeline::repair_long_notes` 对照 `EventList.OPEN2JAM` 处理重复 HOLD、tap 插入、前后搜索、孤立 RELEASE 及 autoplay 长音. 只改变事件类别或移除 Java 会删除的事件, 保留时间、sample、volume/pan 和其余事件相对顺序.
- 保留 backward repair 将已遍历 RELEASE 移入 autoplay 的行为, 不额外规范化 Java 未再次遍历的事件. 没有尾部的最终 HOLD 暂留在修复结果中, 最终 gameplay 转换仍需处理.
- 64 组固定种子 Java oracle 冻结于 `native/crates/open2jam-core/tests/fixtures/ojn/hold-repair.json`, 生成源与 hash 见同目录 README. 正常 Rust 测试不调用 Java. 不改写原迁移 goldens.
- 搜索累计最多 32,000,000 次候选检查, 超限 CorruptChart, 搜索期间检查取消. 该安全工作量限制仍需 ticket 24 的真实工作集复核.
- 验证证据: `/tmp/vos-ticket08-hold-red.log`, `/tmp/vos-ticket08-hold-search-red.log`, `/tmp/vos-ticket08-java-holds.log`, `/tmp/vos-ticket08-holds-tests.log`, `/tmp/vos-ticket08-holds-workspace.log`. 测试还覆盖搜索超限和取消.
- 待续: 最终 Note/HoldTail 与 playable eventOrder 构造、样本映射、音频准备和 CLI/Godot 闭环. 仍不勾选 ticket 08 完整验收.
- 长音增量提交 `ba13319`, 固定基点不变, Standards 0 项 / Spec 0 项. 后续构造需注意: 既有 `gameplay_loader.gd::_normalize_hold_note` 拒绝缺少尾部的 holdStart, 因而不能把未闭合 HOLD 静默变成可游玩的 tap 来宣称 parity.

## 当前增量: bundle v2 gameplay 构造

- `OjnSource::gameplay` 将 parser、timing 与长音修复串联, 构造经验证的 `GameplayChartV2`. 使用调用方提供的稳定 SongId, 从 OJN chartIndex 派生 ChartId; 同文件三个难度共享 SongId, 不用绝对路径产生临时身份.
- 修复后分配 playable eventOrder, 构造独立的 HoldTail 时间、小节和顺序. autoplay 独立保留顺序, 不占用 playable 顺序. sounding note / autoplay 必须映射到 SampleId, 缺失时给出 MissingAsset + sampleIndex; RELEASE 不单独播放声音, 不额外要求 tail sample 存在.
- 未闭合 HOLD 返回 CorruptChart. SampleId 内容相同的多个源 index 可复用同一资源; 列表排序去重. duration 至少覆盖实际事件及小节, 避免 header 时长不足造成无效 v2. 原始 header duration 足够时保持它.
- 同时间、同 BPM 的连续 timing 点按 Java exporter 规则去重, 比较发生在微秒取整前. judgment / visual tracks 使用相同 OJN timing.
- 验证覆盖同时间 release / 新 tap、tail measure/order、样本关联和源 volume/pan、多 Chart 身份、缺样本、未闭合 HOLD、资源去重、短 duration、取消及重复 BPM. red 证据 `/tmp/vos-ticket08-gameplay-red.log`, `/tmp/vos-ticket08-duplicate-bpm-red.log`; 验证记录 `/tmp/vos-ticket08-gameplay-tests.log`, `/tmp/vos-ticket08-gameplay-workspace.log`.
- 待续: 字符集解码、基础 OJM 音频准备、持久化 LibraryRootId 请求传递和 raw OJN catalog/bundle/Godot 闭环. 当前仍不等于 ticket 08 完整验收.
- gameplay 构造增量提交 `4721d5e`, 固定基点不变, Standards 0 项 / Spec 0 项. 完整音频播放和 CLI/Godot 验收仍待后续.

## 当前增量: PCM16 / Ogg 音频准备

- `OjmSampleData::prepare_wav` 将 PCM16 和 Ogg/Vorbis 准备为 RIFF PCM16 WAV, 保留源采样率和声道数, 不将 VOS 专属的 44.1 kHz stereo 要求施加到 OJM. 验证 PCM header、frame alignment 和非空 payload.
- 新增 Symphonia 0.6.1, 仅 ogg/vorbis features, 更新 Cargo.lock; MPL-2.0 与交付要求见 `native/THIRD_PARTY.md`. Ogg 逐 packet 解码, 不跳过本层返回的解码错误, 检查中途声道/采样率变化.
- 当前资源上限: encoded Ogg 64 MiB, decoded PCM 256 MiB, mono/stereo, sample rate 1..384000 Hz. 复制与 packet 之间检查取消; 单次 probe / codec 初始化 / packet 解码仍是第三方库的原子调用. 这些上限不等于最终进程 RSS 上限, ticket 24/25 仍须审计恶意 header 展开与真实资源使用.
- PCM16 输出与原冻结 Java WAV 逐字节比较. 新增自制短 Ogg 的 Java PCM oracle, 长度相同且逐样本 <= 1 LSB; 多页 Ogg 验证中间页损坏拒绝. 另覆盖截断、缺少结束页、坏 PCM header 和取消. 生成来源/hash 见 fixtures/ojn/README.md.
- red: `/tmp/vos-ticket08-pcm-red.log`, `/tmp/vos-ticket08-ogg-red.log`; 证据: `/tmp/vos-ticket08-ogg-java.log`, `/tmp/vos-ticket08-audio-tests.log`, `/tmp/vos-ticket08-audio-workspace.log`.
- 待续: 其他 WAV 编码的支持/兼容性核对、字符集、LibraryRootId 请求传递、raw OJN CLI/catalog/bundle/Godot 闭环. 当前明确拒绝非 PCM16 WAV, 不据此勾选基础 OJM 完整播放验收.
- 音频准备增量提交 `cd570b4`, 固定基点不变, Standards 0 项 / Spec 0 项. 下一增量已有 Java PCM8/24/32 探针: `/tmp/ojn-pcm8.wav` 的输入 0/1/127/128/129/254/255 对应 -32768/-32512/-256/0/258/32508/32767; 不能直接以左移 8 位宣称 Java 量化 parity. 临时 PCM 原始对照文件为 `/tmp/ojn-pcm8.raw`, `/tmp/ojn-pcm24.raw`, `/tmp/ojn-pcm32.raw`.

## 当前增量: 整数 PCM 位深兼容

- 在 format tag 1 下补齐 PCM8 unsigned、PCM24/32 signed little-endian -> PCM16, 保留 PCM16 原样路径. 使用 JavaSound 的 binary32 归一化/量化规则, 不以截取高位或移位近似.
- WAV 输出重新计算 PCM16 byte rate、block alignment、RIFF/data size; 保留输入采样率、声道数和交错顺序. 验证源 frame alignment, 在分配前按转换后的输出大小检查 256 MiB 上限. 每 32768 个样本检查取消.
- 冻结 Java oracle 含 768 个整数输入/输出样本, 另验证 stereo 交错、截断 frame 和转换期间取消. 来源/hash 见 fixtures/ojn/README.md. red `/tmp/vos-ticket08-integer-pcm-red.log`, 验证记录 `/tmp/vos-ticket08-integer-pcm-tests.log`, `/tmp/vos-ticket08-integer-pcm-workspace.log`.
- 该增量更新上一节的 PCM16-only 限制; 当前支持整数 PCM8/16/24/32 与 Ogg/Vorbis. float / companded WAV 尚需兼容性核对, 字符集、Root ID 和 CLI/Godot 闭环仍待续, ticket 保持 in-progress.

## 同轮补齐: float / companded WAV

- Java 探针确认旧路径接受 float32/64、A-law 和 μ-law, 因此同步补齐 tag 3/6/7, 不将基础 OJM 缩减为整数 PCM. float64 按 Java 路径先降为 binary32, 再按 PCM16 量化; 有限超幅值保留 Java int -> short 窄化行为. 归一化后的非有限 float 返回 AudioDecodeFailed.
- A-law / μ-law 各穷举 256 个编码值, float32/64 各 11 个固定值, 共 534 个 Java oracle 样本, 要求逐样本完全一致. fixture 来源及 SHA-256 记录在同目录 README.
- 更新当前音频支持范围: integer PCM8/16/24/32、float32/64、A-law、μ-law、Ogg/Vorbis, 均输出 PCM16 mono/stereo WAV. 不支持的 tag/bit depth 组合明确拒绝, 不猜测格式.
- 验证证据: `/tmp/vos-ticket08-extended-pcm-red.log`, `/tmp/vos-ticket08-extended-pcm-tests.log`, `/tmp/vos-ticket08-wave-formats-workspace.log`. 此增量未新增运行时依赖.
- 后续集中推进字符集、LibraryRootId 请求传递和 raw OJN CLI/catalog/bundle/Godot 闭环, 尚不勾选 ticket 08 完整验收.
- 本轮 WAV 兼容性增量提交 `341f8b7`, 固定基点不变, Standards 0 项 / Spec 0 项. 审查范围包含整数/float/companded 转换, 不代表完整 ticket 验收.

## 当前增量: OJN 显示文本解码

- `OjnSource::title/artist` 对首个 NUL 前的有界字段解码, 有效 UTF-8 原样保留, legacy 字节使用 chardetng + encoding_rs, 不静默插入 replacement characters. 各字段独立检测, 原有 raw bytes 接口保留.
- 新增 chardetng 1.0.0 与 encoding_rs 0.8.41, 已有依赖锁定版本不变. 默认 alloc feature 用于严格解码, 许可证及用途见 native/THIRD_PARTY.md.
- 独立固定字节样本覆盖 UTF-8、EUC-KR、GBK、Big5、Shift_JIS 和混合字段编码. Java 探针发现旧 detector 对这些 legacy 短文本存在乱码, 因此以原文 Unicode 作为期望值, 不复刻误判; 来源说明见 fixtures/ojn/README.md.
- 编码检测仍有歧义, 当前接口只用于显示文本. companion 文件名保留原始字节, 文件 adapter 尚须结合真实目录安全匹配. 不将猜测文本用作身份或路径依据.
- red 证据 `/tmp/vos-ticket08-text-red.log`, `/tmp/vos-ticket08-text-legacy-red.log`; 验证命令为 workspace locked tests、clippy 和 fmt, workspace 日志 `/tmp/vos-ticket08-text-workspace.log`.
- 后续: 持久化 LibraryRootId 请求传递、companion 解析、raw OJN catalog/bundle/Godot 闭环. 本 ticket 仍为 in-progress.
- 显示文本增量提交 `b993f71`, 固定审查基点不变. 两轴独立审查 Standards 0 项 / Spec 0 项; 不将编码检测样本视作任意短文本正确性保证, 不关闭本 ticket.

## 前置增量: Catalog root identity 传递

- 为后续 raw OJN 接入补齐 CATALOG request 的可选 rootIds 映射, 严格拒绝部分覆盖、外部 root key、重复 token 或畸形 ID. CLI 将 token 附到对应 catalog entry, 不自行生成来源身份.
- Godot 将请求中的 token 作为 catalog 结果的校验依据, 外部 bundle 的 source selection key 使用 rootId + relativePath, declared Song/Chart ID 不变. 暂未传 token 的既有 bundle-only 请求保留临时路径 key; raw OJN 不得采用此 fallback.
- 验证命令: locked workspace tests、clippy、fmt 和 `rewrite/tools/verify_native_catalog_gameplay.sh`. 证据 `/tmp/vos-root-ids-workspace.log`, `/tmp/vos-root-ids-godot.log`; red `/tmp/vos-root-ids-protocol-red.log`, `/tmp/vos-root-ids-invalid-red.log`, `/tmp/vos-root-ids-transport-red.log`, `/tmp/vos-root-ids-godot-red.log`.
- 修正 catalog mutation 测试重新序列化时 schemaVersion 变为 float 的问题, 确保拒绝用例不会因无关数字格式提前失败. 合法搬移与新增来源使用同一 wire 重写路径作正向对照.
- 尚未实现 token 的设置持久化和 UI 重新定位. 新 SettingsStore 持久化测试边界确认已提出, 当前继续使用已批准的 protocol / CLI / Godot 行为链推进独立部分.
- 首轮 Spec 审查发现 rootIds 的 BTreeMap 默认反序列化会覆盖重复 JSON path key. 已增加 raw JSON bytes 回归及拒绝重复 key 的反序列化 visitor, red 证据 `/tmp/vos-root-ids-duplicate-red.log`, 避免测试 Value 提前合并键.
- 传输增量 `24321f7`, 重复键修复 `1717e15`. 固定基点两轴复审: Standards 0 项, Spec 0 项. workspace 验证记录已包含重复键回归; SettingsStore 持久化测试边界问题仍待答复, 不影响独立的 raw source adapter 准备工作.

## 当前增量: Raw OJN catalog

- CLI 递归发现大小写不敏感的 `.ojn` 文件, 以已有 rootIds token 和精确 root-relative path 派生一个 SongId, 返回 chartIndex 0/1/2 三个 ChartId. 同名/同内容的不同文件仍是不同 Song, 显式搬移保留 token 时身份不变.
- OJN catalog entry 带 sourceKind=OJN、chartIndex、level、durationSeconds, 不虚构 SoundFont. Bundle entry 的现有 wire 字段不变. result 的 sourceCount/songCount 按来源计数, chartCount 按实际 Chart 条目计数, 不再假定三者相等.
- 读取前校验 regular file 与 64 MiB 输入上限, 64 KiB 分块读取并检查取消, 读取中增长超过上限也拒绝. 复用 core 的 OJN 上限, metadata 解码复用已验证 parser 接口. 缺 root token 返回该源的 INVALID_REQUEST, 截断/超限返回 CORRUPT_CHART, 不妨碍其他有效源.
- 该阶段只验证 OJN header/offset 和显示 metadata, 不提前展开全部事件、定位 companion 或解码音频. 真正加载时仍须完成事件/资源验证; catalog 可读不等于 Gameplay Ready. 文件系统并发替换与整体资源门禁仍需后续安全验收.
- version 的 catalogFormats 增加 O2JAM, bundleFormats 仍只有 BUNDLE, 不宣称 raw OJN bundle 转换已经接通. 当前 Godot catalog 消费仍为 bundle-only, OJN metadata 结构将在转换链路接入时配套更新.
- CLI 测试覆盖三个难度、同源 Song 分组、实际 root 搬移、新 token、同名不同文件、缺 token、截断、sparse 超限和 OJN/bundle 混合计数. `.ojn` 后缀的有效 bundle 目录仍按 bundle 处理. 原有 Godot bundle catalog gate 保留验证.
- red 证据 `/tmp/vos-ojn-catalog-red.log`, `/tmp/vos-ojn-catalog-version-red.log`; 验证记录 `/tmp/vos-ojn-catalog-tests.log`, `/tmp/vos-ojn-catalog-workspace.log`, `/tmp/vos-ojn-catalog-godot.log`. 首次测试调用误将 CLI 参数乱序, 已修正为现有固定顺序并对修改前 catalog 验证实际 sourceCount=0 的 red, 未将用法错误当作缺少 OJN 支持的证据.
- 下一步: raw bundle request 的稳定来源上下文、OJN companion 安全解析和音频/manifest 组装, 随后更新 Godot 的多 Chart 消费. ticket 保持 in-progress.
- Raw catalog 增量提交 `2ffd103`, 固定基点两轴审查 Standards 0 项 / Spec 0 项. 当前证据证明 CLI metadata discovery, 不证明 raw OJN 已经在 Godot 可游玩.

## 当前增量: Raw OJN/OJM bundle 到 Gameplay Ready

- OJN BUNDLE request 增加必需的 libraryRoot 上下文, 验证源路径属于 root, 重新派生并核对 ChartId. 原外部 bundle 请求/manifest 身份路径不变.
- CLI 使用 core OJN parser、timing/长音修复与 OJM 音频准备, 生成 content-addressed PCM16 WAV、audio manifest 和 gameplay JSON, 经既有 BundleStager 验证/原子完成. 不启动 Java, 不打开 request 的 SoundFont path. sample 相同内容去重, 保留 index -> SampleId 关联.
- core 新增 CompiledOjnChart, 将 timing 编译和 sample 绑定分开, 原 gameplay 接口保留为组合入口. 先编译 timing、后准备音频, 无重复 timing 编译, 进度反映真实阶段和数量. 回归中发现非法 chartIndex 的错误码顺序变化, 已恢复原 INVALID_REQUEST 行为.
- 源文件读取前限制 regular file 与输入大小, Unix 使用 O_NOFOLLOW / O_NONBLOCK, 64 KiB 读取/哈希取消检查. 解析消费已捕获的不可变 bytes; 同一文件句柄和路径在读取后及最终返回前核对 dev/ino、size、mtime. 这是当前源变化检测, 不宣称已完成 ticket 25 的全部并发文件系统攻击验收.
- 当前上限沿用 OJN 64 MiB、OJM 512 MiB、单 sample decoded PCM 256 MiB, 另将一次转换的累计 prepared WAV 限为 4 GiB. 音频逐 sample 写 staging, 不同时保留全部 decoded WAV. 这些是当前安全拒绝边界, 不是最终性能验收规模或 RSS 证明, ticket 24 仍须测量复核.
- Companion 使用 UTF-8 优先; legacy bytes 使用 detector 候选与 EUC-KR/GBK/Big5/Shift_JIS 候选严格解码, 只接受实际存在的唯一 regular file. 拒绝路径越界、链接、无匹配或多候选歧义, 不根据显示乱码或同名猜测文件. 安全的子目录相对路径可用.
- version 同时声明 catalogFormats / bundleFormats 的 O2JAM 与 BUNDLE; OMC/M30 仍明确 UNSUPPORTED_FORMAT, 分别留给 tickets 09/10.
- 新 CLI 回归覆盖 prepared bundle 独立搬移、真实 note 与 volume/pan/sample 关联、阶段顺序、重试确定性、companion 内容变更导致 key 变化、缺 root、越界、ChartId 不匹配、缺 companion/sample、取消、链接和 legacy 名称歧义.
- `rewrite/tools/verify_native_ojn_gameplay.sh` 从真实 CLI catalog 获取 entry, 通过 MainUi 的既有公开入口注入该 entry, 再由 Godot 异步 native converter 转换并到 Gameplay Ready, 完成 note judgment 和 prepared audio 事件. 它证明转换/加载链路, 不证明普通曲库列表已接入 OJN 消费或独立 Difficulty Selection.
- red 证据 `/tmp/vos-ojn-bundle-red.log`, `/tmp/vos-ojn-bundle-phase-red.log`, `/tmp/vos-ojn-companion-red.log`, `/tmp/vos-ojn-bundle-version-red.log`. 验证记录 `/tmp/vos-ojn-bundle.log`, `/tmp/vos-ojn-bundle-parser.log`, `/tmp/vos-ojn-bundle-workspace.log`, `/tmp/vos-ojn-gameplay.log`, `/tmp/vos-ojn-bundle-catalog-regression.log`.
- 待续: 普通 Godot catalog 的 OJN 消费、多 Chart 选择和稳定 root 设置持久化, 完整 ticket 08 仍不关闭. SettingsStore 新测试 seam 的确认仍待答复, 现有 UI/CLI 验收边界继续用于独立推进.
- 补充源文件选中后被删除的 CLI 回归, 从 INTERNAL_ERROR 修正为 SOURCE_CHANGED, red `/tmp/vos-ojn-source-removed-red.log`. 不将源消失误报为 converter 内部崩溃.
