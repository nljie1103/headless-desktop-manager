# 备份软件包策略
本仓库不含任何虚构的二进制备用包。`packages/manifests/*.tsv` 为空时，菜单须明确显示“未配置”，绝不能声称可以从 GitHub 备用安装。

可再分发且校验过的 RustDesk/驱动包可以上传 `mirror-YYYY-MM` Release；每个 manifest 条目必须记录真实的 URL、SHA256、系统架构以及许可证，发布前人工验证。完整 GNOME 依赖应由官方发行版仓库解决，不适合零散复制为独立 `.deb`。
