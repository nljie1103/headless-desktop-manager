# RustDesk 客户端管理

优先使用可信系统软件仓库中可用版本，否则按 GitHub Release API 筛选官方稳定版及相符 `.deb`，拒绝缺失 SHA256 的资产。安装后检查原生 systemd 服务并查询 ID。不要无故停用 RustDesk 原生服务。

自建服务器菜单使用 RustDesk 原生 `--import-config` 来尝试导入，而非把明文永久密码写入 TOML；但 **CLI 导入作用域必须在目标 VM 实机验证**，不能仅凭退出码判定服务器注册成功。

`--password` 会在上游 CLI 的命令参数中短暂出现密码。HDM 不记录密码且明确警告；不能接受该风险时应使用 RustDesk 图形界面。

官方文档：https://rustdesk.com/docs/en/client/ 和 https://rustdesk.com/docs/en/client/linux/

### v0.3.6：自建服务器配置作用域

HDM 在菜单 7.1.7 中先备份 RustDesk 服务账户的 root 配置，以及当前 `sudo` 登录用户（如果可识别）的配置文件。暂停正在运行的 RustDesk 服务，更新两处 `RustDesk2.toml`，保留未知/不相关设置，然后恢复服务运行并读回校验。若仍被服务重写或启动失败，会尝试从快照恢复。并不自动向服务器端证明注册成功。

如果 `journalctl -u rustdesk` 出现 `cannot open display: :0`，表示图形显示环境不可访问，与自建服务器端点保存是**独立故障**。普通 RustDesk ARM64 版本没有得到 HDM 对 GNOME Wayland 登录前无显示器无人值守的实机验证；不要将 `WaylandEnable=false` 当作通用解决办法。
