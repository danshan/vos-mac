# 07: 发现并游玩外部 bundle v2

**What to build:** 玩家在曲库发现自包含 bundle v2, 选择其中 Chart 并游玩, 搬移整个 bundle 后仍可使用.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** ready-for-agent

- [ ] 扫描发现有效 bundle 并显示对应 Song/Chart, 选择后通过真实 v2 consumer 进入 gameplay.
- [ ] 相对资源在 bundle 内解析, 搬移后仍有效, 不依赖原构建目录或外部 MIDI CAS.
- [ ] 拒绝越界路径、无效 manifest 和损坏资源, 错误指出来源且不使其他有效歌曲不可用.
- [ ] 区分 bundle 声明身份与发现来源, 不因同名或内容相同隐式合并不同曲库; 与后续 Library Root namespace 合同兼容.

