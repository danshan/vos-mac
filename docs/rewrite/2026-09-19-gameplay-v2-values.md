# Gameplay v2 数值与 Note 合同

该文档冻结 ticket 04 首批 gameplay 数值, 完整 Chart、timing、audio manifest 与 Godot adapter 仍待实现. 不以这些 Rust 类型的序列化测试宣称 Gameplay Ready.

## 精度

时间使用非负整数微秒 `TimeMicros`, wire 上为 JSON integer. 上限为 2^53-1, 使后续 Godot JSON 经 binary64 读取仍可精确还原整数. 该上限是交换格式的精度边界, 不替代最终曲目安全资源上限. adapter 负责将微秒除以 1000 转为 runtime 毫秒, 不截断亚毫秒部分.

比例使用 `Ratio { numerator, denominator }`, signed numerator 范围为 ±(2^53-1), denominator 为非零 u32. 构造和反序列化均约分, 0 规范化为 0/1. 范围比较用 i128 交叉乘法, 不先转为浮点数. Note volume 范围为 0..1, pan 为 -1..1.

这些规则替代旧 Phase 1 横向草稿中 volume u8 百分比与 pan i16 百分比的建议, 落实已批准迁移 spec 的精度要求. Java OJNParser 的对应源行为为 volume nibble/16, 零 nibble 特例为 1; pan nibble 的零特例为 8, 然后 (nibble-8)/8. 因此 15/16 和 -7/8 可精确保留, 不应四舍五入到整数百分比. 原始 nibble 特例仍归 OJN importer, 通用 Note 不猜测来源编码.

## Note 与长音

Note 保留 lane、startUs、measure、eventOrder、可空的稳定 SampleId、volume/pan 和可空 tail. tail 为 null 表示 tap; 有 tail 表示 hold, tail 独立保留 atUs、measure 和 eventOrder. 只支持本次合同的 7 lanes, index 为 0..6.

tail 时间与 measure 不得早于头部; 同一时刻的 tail order 必须晚于头部. 允许先头后尾的零时长 hold, 不默默转为 tap. 不同时间的 source event order 不以时间重写. Note 的字段私有, 构造与 serde 输入共享相同校验. HoldTail 的相对先后不变量由 Note 检查; 单独的 tail 只包含已验证的时间与无额外约束的 u32 值.

SampleId 为 null 的跨格式许可和非空 ID 必须命中 audio asset 的检查属于完整 Chart 验证, 本阶段 Note 不声称完成这些引用约束. 同样, judgment/visual timing、scroll 和 measure 序列仍必须在下一层保留, 不由 Note 起止时间代替.

## 验证

`native/crates/open2jam-core/tests/gameplay_values.rs` 覆盖 1,000,125 us、OJN 离散比例、长音尾部独立字段, 以及 lane、时间、音量、声像、分母和 tail 顺序的 serde 绕过检查. 极值测试验证约分与范围比较不溢出. 这些是共享 core 精度边界测试, 仍需真实 Godot 消费与资源加载测试.

## Chart 核心事件模型

GameplayChartV2 现在组合 songId/chartId、源格式、固定 7 keys、title/artist、durationUs、sample ID 集合、notes、measures、judgmentTiming、visualTiming、scroll 和 autoPlayEvents. GameplayChartInput 是未验证的构造参数, validated Chart 字段私有; constructor 与 serde 走同一校验.

judgmentTiming 与 visualTiming 分开保留编译后的 BPM ratio, 允许零速度表达停止. scroll 保留原始非负 multiplier ratio 的时间和 eventOrder, 不被 visualTiming 替代. 同时刻的变化依 eventOrder 严格有序. importer/timing compiler 负责计算这些轨道的一致性; 本层不从一条轨道猜测另一条. measures 按索引保存非递减的微秒位置, 允许既有 exporter 产生重复时间位置.

所有事件数组保留输入顺序, 不在验证期间排序. notes、timing、scroll 和 autoplay 分别按 time/order 严格递增; playable heads/tails 还共享 time/order 唯一性检查, 防止长音释放与下一音头的顺序歧义. durationUs 必须覆盖所有事件和 measure 位置, 属于规范化结果的上界, 不直接照搬旧格式名义长度.

sample ID 集合必须排序且唯一; 非空 Note 引用及所有 autoplay 引用必须命中集合. sampleless Note 在各源格式均可表达, 仍保留 volume/pan; 不因 sampleless 自动丢弃 Note. Note 头尾的 measure 索引必须命中 measures. bundle 是传输来源而非 gameplay 源格式, 因而 Chart format 保留 VOS、O2JAM 或 OSU_MANIA, 不接受 BUNDLE.

该模型尚未完成 audio asset 与 bundle manifest 的跨文件身份/引用校验, BGA 资源表示及实际 Godot adapter. 这些工作继续归迁移范围, 本节不能作为完整 bundle consumer 或 ticket 04 完成的依据. Chart round-trip 只验证字段保留; 最终必须由真实 Rust producer 与 Godot runtime 验证消费语义.
