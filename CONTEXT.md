# Game Loading

该上下文定义从主菜单进入选歌页, 以及从难度选择进入 gameplay 的用户可见加载边界与性能预算.

## Language

**Song**:
玩家在选歌列表中看到的逻辑歌曲, 仅以名称显示. Song 由稳定的 `songId` 标识; 名称相同但来源歌曲包或规范化源目录不同的 Song 不得合并.
_Avoid_: Catalog entry, chart row

**Chart**:
属于某个 Song 的可游玩谱面, 在玩家选择 Song 后作为难度选项显示. O2Jam 同一 `.ojn` 文件中的多个 `chartIndex` 是同一 Song 的不同 Chart.
_Avoid_: Song, difficulty row

**Song ID**:
由 Java catalog exporter 根据来源歌曲包或规范化源目录生成的稳定歌曲身份. Godot 不得使用歌曲名称推断分组.
_Avoid_: Title key, display name

**Song Selection Ready**:
选歌页已经显示可选择的歌曲列表, 并且搜索与类型筛选可以立即响应. 热启动 P95 不超过 300 ms.
_Avoid_: Song page opened, catalog loaded

**Gameplay Ready**:
所选谱面已经完成 gameplay 必需资源的准备, 玩家可以开始游玩. 热缓存 P95 不超过 2 s, 冷加载 P95 不超过 5 s.
_Avoid_: Gameplay page opened, loading finished

**Loading Progress**:
从操作开始到对应 Ready 状态为止, 持续向玩家展示的完整加载进度. 加载界面应在 100 ms 内出现.
_Avoid_: Spinner, fake progress

**Catalog Refresh**:
选歌页可操作后继续执行的歌曲目录扫描. 有缓存时不得阻塞选歌, 应显示基于真实已完成数量的进度并增量更新列表; 无缓存时才使用阻塞式加载.
_Avoid_: Startup scan, catalog reload
