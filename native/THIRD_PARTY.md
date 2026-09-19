# Native 新增依赖

当前直接依赖以 Cargo.toml 和 Cargo.lock 为准. 本文件记录迁移期间新增依赖的用途与交付注意项, 不替代最终包内的完整第三方声明.

| 依赖 | 版本 | 用途 | 许可证 |
|---|---|---|---|
| Symphonia | 0.6.1 | OJM 的 Ogg/Vorbis 解码, 仅启用 ogg / vorbis features | MPL-2.0 |
| chardetng | 1.0.0 | OJN 显示文本的 legacy 字符集检测 | Apache-2.0 OR MIT |
| encoding_rs | 0.8.41 | 严格解码检测后的字符集, 显式启用默认 alloc feature | (Apache-2.0 OR MIT) AND BSD-3-Clause |
| libc | 0.2.186 | Unix source capture 的 O_NOFOLLOW / O_NONBLOCK 常量, 不直接调用 unsafe FFI | MIT OR Apache-2.0 |

使用官方发布 crate, 未修改依赖源码. API 根据 Context7 官方仓库文档及已下载的 0.6.1 源码核对. [官方仓库](https://github.com/pdeljanov/Symphonia), [版本文档](https://docs.rs/symphonia/0.6.1).

字符集 API 根据 Context7 的 [chardetng 仓库文档](https://github.com/hsivonen/chardetng) 和已下载发布源码核对. [encoding_rs 官方仓库](https://github.com/hsivonen/encoding_rs). 不自行维护 legacy 字符映射表; 依赖的字符集猜测不能保证短字段无歧义, 不单独用于确定 companion 路径或歌曲身份.

CLI 复用 chardetng / encoding_rs 产生有界 companion 名称候选, 必须与实际非链接文件唯一匹配, 不仅凭显示文本猜测选择文件. libc 已在 lockfile 的传递依赖中, 本增量将 Unix 常量用途声明为直接依赖, 没有升级其版本. Context7 未返回对应 flags 文档, API 另按 [Rust 官方 OpenOptionsExt 文档](https://doc.rust-lang.org/std/os/unix/fs/trait.OpenOptionsExt.html) 和锁定 crate 源码核对.

ticket 26 的正式打包必须随包提供所用版本的许可证、版权声明与 MPL 源码获取信息, 并覆盖 Cargo.lock 中的传递依赖. 当前尚不宣称已完成最终分发包依赖审核.
