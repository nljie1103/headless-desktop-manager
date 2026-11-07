# RustDesk 客户端管理

优先使用可信系统软件仓库中可用版本，否则按 GitHub Release API 筛选官方稳定版及相符 `.deb`，拒绝缺失 SHA256 的资产。安装后检查原生 systemd 服务并查询 ID。不要无故停用 RustDesk 原生服务。

自建服务器菜单使用 RustDesk 原生 `--import-config` 来尝试导入，而非把明文永久密码写入 TOML；但 **CLI 导入作用域必须在目标 VM 实机验证**，不能仅凭退出码判定服务器注册成功。

`--password` 会在上游 CLI 的命令参数中短暂出现密码。HDM 不记录密码且明确警告；不能接受该风险时应使用 RustDesk 图形界面。

官方文档：https://rustdesk.com/docs/en/client/ 和 https://rustdesk.com/docs/en/client/linux/
