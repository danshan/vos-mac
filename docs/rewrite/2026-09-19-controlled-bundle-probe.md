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
