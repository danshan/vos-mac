# Native 音频依赖

当前直接依赖以 Cargo.toml 和 Cargo.lock 为准. 本文件记录迁移期间新增音频依赖的用途与交付注意项, 不替代最终包内的完整第三方声明.

| 依赖 | 版本 | 用途 | 许可证 |
|---|---|---|---|
| Symphonia | 0.6.1 | OJM 的 Ogg/Vorbis 解码, 仅启用 ogg / vorbis features | MPL-2.0 |

使用官方发布 crate, 未修改依赖源码. API 根据 Context7 官方仓库文档及已下载的 0.6.1 源码核对. [官方仓库](https://github.com/pdeljanov/Symphonia), [版本文档](https://docs.rs/symphonia/0.6.1).

ticket 26 的正式打包必须随包提供所用版本的许可证、版权声明与 MPL 源码获取信息, 并覆盖 Cargo.lock 中的传递依赖. 当前尚不宣称已完成最终分发包依赖审核.
