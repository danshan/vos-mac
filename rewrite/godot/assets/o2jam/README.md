# 固定 gameplay 皮肤

此目录是 `open2jam-gameplay-assets-v1` 的 Godot 运行资源. 布局来自已冻结的 Java render metadata, 只将 texturePath 替换为本目录的 `res://` 路径; 16 个 PNG 原样复制自仓库 `src/resources`, 不重新生成或改绘. `asset-manifest.json` 记录来源布局 hash 和当前资源 hash, 用于验证迁移未改变资源内容.

原始 Java oracle fixture 保留, 运行路径不读取 test/fixtures 或 Java exporter. 这些静态资源不写入每首歌曲的 bundle v2. 后续无 Java 打包需将本目录纳入导出; 资源版本变化须同步更新 bundle 身份中的 staticAssetsVersion.
