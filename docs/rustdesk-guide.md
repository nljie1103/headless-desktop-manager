# RustDesk 客户端管理

优先使用可信系统软件仓库中可用版本，否则按 GitHub Release API 筛选官方稳定版及相符 `.deb`，拒绝缺失 SHA256 的资产。安装后检查原生 systemd 服务并查询 ID。不要无故停用 RustDesk 原生服务。

自建服务器配置通过受控的 TOML 编辑写入 root 与当前登录用户作用域，并进行读回校验；文件写入不等于 RustDesk 服务已加载配置。永久密码通过 RustDesk CLI 设置，不写入明文 TOML。

`--password` 会在上游 CLI 的命令参数中短暂出现密码。HDM 不记录密码且明确警告；不能接受该风险时应使用 RustDesk 图形界面。

官方文档：https://rustdesk.com/docs/en/client/ 和 https://rustdesk.com/docs/en/client/linux/

### v0.3.6：自建服务器配置作用域

HDM 在菜单 7.1.7 中先备份 RustDesk 服务账户的 root 配置，以及当前 `sudo` 登录用户（如果可识别）的配置文件。暂停正在运行的 RustDesk 服务，更新两处 `RustDesk2.toml`，保留未知/不相关设置，然后恢复服务运行并读回校验。若仍被服务重写或启动失败，会尝试从快照恢复。并不自动向服务器端证明注册成功。

如果 `journalctl -u rustdesk` 出现 `cannot open display: :0`，表示图形显示环境不可访问，与自建服务器端点保存是**独立故障**。普通 RustDesk ARM64 版本没有得到 HDM 对 GNOME Wayland 登录前无显示器无人值守的实机验证；不要将 `WaylandEnable=false` 当作通用解决办法。

### v0.3.8：访问权限与密码认证

菜单 `7 → 13` 新增自定义、完全访问、仅共享屏幕，以及允许/禁止远程修改配置。官方字段为 `access-mode=custom/full/view` 和 `allow-remote-config-modification=Y/N`，保存到受控的 TOML `[options]`，重启后读回并在失败时尝试恢复快照。自定义配置开启常用的键鼠、剪贴板、文件传输等权限，但不自动开启远程修改配置。更高优先级的 RustDesk 策略可能覆盖本地文件。

永久密码的 12 位限制是旧 HDM 自定要求，现已取消；密码在终端中可见且只输入一次。RustDesk 官方 CLI 仍可能通过命令行参数短暂暴露密码；请仅在可信终端操作、避免录屏或共享会话。成功调用 CLI 后，HDM 会尝试写入 `approve-mode=password` 和 `verification-method=use-permanent-password`，以降低无图形弹窗确认导致的拒绝连接；但如果 GDM3 未启动、没有活动图形会话或服务器端权限策略限制，仍可能无法远程查看屏幕。
