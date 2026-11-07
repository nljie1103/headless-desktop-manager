# 软件源与备用包策略

首选用户现有可信 APT；DNS/超时等可诊断的网络故障才临时使用 Ubuntu 官方镜像，**绝不永久覆盖系统源或禁用 GPG/签名**。

RustDesk 仓库无系统包时，从其官方 GitHub Releases 获取匹配架构 `.deb`、GitHub API digest SHA256 并校验。HDM GitHub 镜像仅在 `packages/manifests/*.tsv` 中有**真实、已发布、校验过、授权分发**的 Release 资产时使用。

本源码包首次发布没有镜像二进制！上传时不可声称已有 Github 备用包。**官方 RustDesk 和 HDM 备份同处 GitHub，Github 网络故障时不是真正独立的备用渠道。**
