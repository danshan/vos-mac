# 受控 native bundle producer

`controlled-bundle-probe NEW_OUTPUT_DIRECTORY` 是开发验证入口, 从随工具编译的 recipe 生成严格 GameplayChartV2、AudioManifestV2、真实 WAV 与 bundle.json, 然后通过 load_bundle_documents 复验. 它不模拟生产 importer, 不改变 open2jam-converter 的 capability 声明, 也不替代 request/progress/result 或 staging 生命周期.

输入 recipe 位于 `native/crates/open2jam-cli/fixtures/controlled-gameplay.json`, 包含普通 Note、长音、同刻释放后新音头、亚毫秒时间、OJN 离散音量/声像、measure、独立 judgment/visual timing、scroll 和 autoplay. producer 为固定开发 Library Root 派生身份, 将准备后音频 digest 派生的 SampleId 注入真实 typed Chart, 并调用共享 core 编码和验证. 源指纹按现有 framing 编入 recipe 和 WAV 两个组件, 不包含输出绝对路径.

音频使用确定性的整数三角波, 长度 0.25 s、44.1 kHz、stereo PCM16, 振幅 ±2048. 此工具不做 VOS 合成; bundle 中 GeneralUser GS 2.0.3 元数据表示固定 converter 配置, 波形不依赖 SoundFont. 原型只允许新建目录, 重复路径会失败且不覆盖旧文件. 发生中途写入错误可能留下仅属于本次调用的目录, 生产原子发布仍待正式 stager 实现.

## 验证入口

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test controlled_bundle_probe --locked
mise exec -- bash rewrite/tools/verify_controlled_bundle_probe.sh
```

Native 测试验证真实进程输出、共享 core 文档校验、重复目录拒绝和搬移后身份不变. Shell gate 重新生成临时 bundle、搬移到含空格目录, 用 Python wave 独立解码检查 PCM 参数和振幅, 再由 Godot AudioStreamWAV 加载并检查长度及 PCM 字节数. gate 仅清理自身创建的临时目录.

Godot API 依据 [Godot 4.6 AudioStreamWAV 文档](https://docs.godotengine.org/en/4.6/classes/class_audiostreamwav.html), 通过 Context7 获取. 本地 Godot 4.6.3 输出确认 0.25 s、44100 PCM bytes. 沙箱环境另有系统 CA 证书读取诊断, 该输出来自引擎平台初始化, 此测试没有发起网络请求.

此阶段不声称已经到达 Gameplay Ready. 完整 v2 adapter、Godot manifest/hash 校验、正式 native bundle CLI 服务和实际 gameplay 判定仍属于 ticket 04 的剩余工作. BGA、所有生产源格式及最终 Java-free 门禁继续保留在整体迁移范围中.

## Godot v2 consumer 与实际判定

新增 native_bundle_loader.gd, 通过独立 native_bundle_integrity.gd 在 Godot 中重算 bundle key、Chart ID 和 SampleId, 校验完整目录的 schema、路径集合、size/hash 以及文档间引用. native_json.gd 在 Godot JSON parser 之前拒绝重复键、非整数数字语法、尾随逗号、非法转义和 NUL; 防止 Godot 的宽松解析与 Rust 的严格合同产生差异. JSON 文档按既定 1 MiB/64 MiB 上限读取, 音频文件以 64 KiB 块计算 hash.

adapter 将稳定 SampleId 按排序后的资产顺序映射为 runtime 整数 ID, 无 sample 映射为 0; 以微秒除以 1000 保留亚毫秒时间, 将精确 ratio 转换为 runtime volume/pan. VOS、O2JAM、OSU_MANIA 映射至既有 runtime 的 VOS、OJN、OSU. 头尾 measure/order、judgment/visual timing、scroll 轨道均保留, 所有音频资源先经 AudioStreamWAV 解码检查后才返回结果.

```bash
mise exec -- bash rewrite/tools/verify_native_bundle_gameplay.sh
```

gate 从 Rust producer 重新生成 bundle, 搬移到含空格目录, 调用生产 adapter, 再启动既有 GameplayRuntime. 它验证实际运行状态、autoplay 音频、tap 判定、hold 启动、同刻释放后的下一音头及非零分数. 测试按正常游戏行为推进帧, 不通过直接跳跃输入时间代替 runtime 帧推进. 正例打印明确成功标记; shell 同时检查退出码和 SCRIPT ERROR, 防止 Godot 某些脚本 parse failure 以退出码 0 掩盖失败.

21 类反例覆盖错误 key/schema/complete、缺失或额外文件、symlink/root symlink/FIFO、hash 不符、未知或重复字段、转义后的重复 key、尾随逗号、非整数语法、NUL、非法 ratio/sample/长音顺序/format, 以及文件 hash 和 SampleId 完全匹配但实际不可解码的 WAV. 文档语义反例重新计算外层 hash, 避免只触发旧文件完整性检查.

Godot 独立校验和受控实际玩法已有证据, 但正式 open2jam-converter bundle request 服务、transactional staging 和产品加载协调仍未接通. 该 loader 当前同步读取并验证资源, 后续任务必须接入 generation/cancellation、进度、资源上限和预热协调. BGA 支持与所有原始格式仍属于整个迁移的剩余工作.

实现参考 [Godot 4.6 HashingContext](https://docs.godotengine.org/en/4.6/classes/class_hashingcontext.html)、[DirAccess](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html) 及 [Unix FileAccess 实现](https://github.com/godotengine/godot/blob/4.6/drivers/unix/file_access_unix.cpp). Context7 目录 API 请求短暂失败后, 通过官方文档页面补充核实; 未依靠未验证的 API 猜测.
