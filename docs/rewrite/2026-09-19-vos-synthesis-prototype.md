# Ticket 02 VOS 离线合成原型

结论: RustySynth 1.3.6 可以作为下一步集成候选, 已验证固定 SoundFont、离线 PCM、基础 MIDI 行为和重复/逆序确定性. 当前证据只支持继续集成, 不证明完整 cold Gameplay Ready P95 <= 5 s. 1,024 个独立 samples 的串行合成曾超过整体预算, 复测又明显降低, 必须保留性能波动风险, 不能从后续压力验收中悄悄移除.

## 实现边界

独立 vos-synth-probe CLI 读取受控 PPQ MIDI 事件 JSON, 使用固定 GeneralUser GS 2.0.3 输出 WAV 和测量 JSON. 不包含生产 VOS container parser、SMF decoder、bundle 发布、Godot 加载或全局 cache. JSON 事件是原型输入协议, 不是新的生产 wire contract.

原型使用 RustySynth 1.3.6, MIT license, 该库除标准库外无新增传递依赖. Cargo.lock 固定新增版本; 已有 serde/serde_json/sha2 被复用. API 通过 Context7 和下载到本地的 crate 源码核对. 参考 [RustySynth 官方仓库](https://github.com/sinshu/rustysynth).

固定配置: 44.1 kHz, stereo, signed 16-bit little-endian PCM, block size 64, polyphony 64, effects enabled, master volume 0.5. 每个 sample 使用 fresh synth, SoundFont 在同一进程共享, 避免跨 sample 状态泄漏. 最小 gate 为 60 ms, tail 为 500 ms; volume 量化前统计非有限值与削波, 不以 clamp 掩盖削波计数.

输入有原型专用资源边界: 10 MB request, 最多 1,024 samples, 单 sample 最多 65,536 events/600 s, 总 PCM 最多 2 GB. 这些边界用于限制探针的资源消耗, 不是最终产品安全上限, 后者仍由 ticket 24 冻结. 不支持的消息类型明确拒绝, 不宣称原型支持完整 MIDI 标准或生产 parser.

## 行为验证

真实 CLI integration tests 覆盖:

- WAV 格式、非静音、60 ms minimum gate、500 ms tail 与无削波.
- tempo 变化后的确切时长, 延迟 note-on 前的静音.
- 相同 tempo 的冗余事件不改变音乐时长, 累计换算保留分数余量而非逐段丢弃.
- 相同样本跨进程重复和倒序后的 PCM/WAV 一致性.
- velocity、左右 pan、program 变化和同 tick program/note 顺序.
- bank 选择、channel 控制隔离、零 velocity note-on 等价 note-off.
- 三分钟背景音轨可被有界渲染.
- 超大结束 tick 明确拒绝而非整数溢出 panic.

首个 CLI 测试先因不存在探针入口失败, 实现后通过. 超大空序列先复现 panic, 三分钟背景先复现原型边界不足, 均补最小修复后通过. 其他 MIDI 行为测试通过真实 synth 验证, 未引入模拟 synth.

Spec 审查发现逐事件整数除法导致时间漂移. 新回归先复现 44,064 frames 而非 44,100, 修复为保留累计分数后通过; 修复后重跑全部合成测量. 这不是性能优化, 不将下方耗时变化归因于时序修复. 生产音频 parity 仍需处理旧 Java 逐段截断与正确 MIDI 累计时间可能存在的细微差异, 本原型未修改生产输出或 oracle.

CLI crate 全 targets 输出: 8 个 probe tests 与 1 个既有 version test 均通过. 对 CLI crate 的 clippy -D warnings 与 workspace fmt check 通过. Workspace 全 targets 的旧 protocol_contract 缺模块错误仍属于 ticket 04, 不由该原型绕过.

## Release 测量

环境: Apple M5, 32 GiB RAM, macOS 27.0, 项目 Rust 1.96.1, SDK 26.5 本地覆盖, release 构建. 每组执行 first/repeat/reversed 三个独立进程, 每次新建输出目录, 无派生音频 cache. OS 文件缓存未清空. 数值是本次三个样本的范围, 不是 P95.

| 输入 | Samples / 不同 PCM | 累计音频时长 | PCM bytes | 进程总时间范围 | 最大 RSS |
|---|---|---|---|---|---|
| 合成代表性工作集 | 64 / 64 | 48.0 s | 8,467,200 | 0.18–0.55 s | 72,318,976 bytes |
| 合成压力工作集 | 1,024 / 1,024 | 768.0 s | 135,475,200 | 2.04–2.06 s | 73,646,080 bytes |
| 真实 Age of empire VOS | 192 / 190 | 324.32 s | 57,210,048 | 1.33–1.34 s | 71,843,840 bytes |

进程总时间来自 macOS time, 包含启动、SoundFont 验证/加载、请求解析、合成、写盘与报告输出. 修复后探针内部 wall time 分别为 0.182–0.220 s、2.043–2.064 s、1.335–1.344 s. 两者分开记录, 不把内部计时冒充完整用户等待.

首次测量的进程时间分别为 0.23–0.57 s、5.63–7.38 s、1.83–2.17 s. 两次测量均为同一机器上的开发环境, 未控制其他进程负载与 OS 文件缓存, 不因复测更快而删除首次超预算结果. 尚无证据解释全部波动, 因而这些测量不能证明 P95 或稳定 cold 性能.

三组所有输出均按实际 WAV bytes 复核 PCM SHA-256, repeated 与 reversed 对应结果完全相同; 三组削波计数均为 0. 完整数值与每个 sample 的 hash 保留在本机 tracker 的 ignored target/synth-probe-final 目录, 首次结果保留在 target/synth-probe.

真实 VOS 只作为补充测量, 不进入 hermetic 自动 gate. 其源 SHA-256 为 `0b1f83bb8985bcc77a40bf871d285b47db37349065d7821887d735d1d8580dab`. 迁移期间使用已有 Java ChartParser/MidiSystem 只读提取其 samples 与 PPQ 事件, Rust 执行音频合成; 并未测量 Rust VOS parser 或 Java-free 端到端加载. 192 个 samples 包含一条约 172.92 s、4,374 个事件的背景音轨. 提取后的 JSON SHA-256 为 `9230e3168892a2262cc157c462f5b6e155a8b6760a368fc3c6d53e12360f803e`.

## Go/no-go

- Go: 继续使用该固定版本和配置进行生产合成 adapter 的集成验证. 真实 VOS 音频准备在本机观察到 1.33–2.17 s, 没有发现固定音源读取、重复执行确定性或基础 MIDI 控制阻碍.
- No-go: 不能宣称所有压力输入满足 cold 5 s, 不能直接跳到 Java 删除或省略后续性能门禁. 1,024 独立 samples 已观察到串行实现超预算, 需要在 ticket 24/25 根据完整工作集和受控测量决定并验证并行合成、去重或其他优化.
- 本轮没有将 1,024 samples 擅自划到“不承诺预算”的范围. 最终代表性/压力工作集尚未冻结, 不能事后只选择已通过的规模.
- 64-voice 限制、64-frame 内部渲染块及所覆盖 MIDI 消息并非完整音乐行为证明. 更复杂 polyphony、控制器和源格式行为必须随 production VOS importer 扩充 oracle/behavior gates.

## 重现合成工作集

以下命令要求项目 Python 3 命令可用, Python 仅用于原型数据生成和证据核验, 不进入最终运行包. 输出使用新目录, 探针拒绝复用已有输出目录以避免混合两次结果.

```bash
mise run native-release
probe_root=$(mktemp -d /tmp/vos-synth-measure.XXXXXX)
for profile in representative stress; do
  python3 rewrite/tools/create_vos_synth_probe_workload.py "$profile" "$probe_root/$profile-input.json"
  python3 rewrite/tools/create_vos_synth_probe_workload.py "$profile" "$probe_root/$profile-input-reversed.json" --reverse
  for run in first repeat reversed; do
    request="$probe_root/$profile-input.json"
    if [ "$run" = reversed ]; then request="$probe_root/$profile-input-reversed.json"; fi
    /usr/bin/time -l native/target/release/vos-synth-probe \
      rewrite/assets/soundfont/payload/assets/GeneralUser-GS.sf2 \
      "$request" "$probe_root/$profile-$run" \
      > "$probe_root/$profile-$run.json" 2> "$probe_root/$profile-$run.time"
  done
done
python3 rewrite/tools/verify_vos_synth_probe_results.py "$probe_root" representative stress
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --all-targets --locked
```

当前探针输出目录不参与生产 cache/publish. 失败时其中可能保留部分 WAV, 只能作为诊断材料, 不能被标为完整 bundle.
