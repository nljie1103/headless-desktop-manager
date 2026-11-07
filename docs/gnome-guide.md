# GNOME + 无显示器技术说明

GNOME 是默认，完整 Ubuntu 发行版使用 `ubuntu-desktop`，GDM3 默认负责会话。RustDesk 官方 Linux 文档指出，在登录界面访问仍然需要 X11：`/etc/gdm3/custom.conf` 的 `[daemon]` 下 `WaylandEnable=false`。

HDM 先安装 Dummy 包，再在用户明确确认后生成 `/etc/X11/xorg.conf.d/20-hdm-dummy.conf`，保留已有 SSH/云控制台和旧配置快照。不能将 GDM3 service active 当作 GNOME Shell 画面正常，也不能用 `gnome-session & rustdesk` 的拼接来冒充桌面初始化。

此路径还**没有在云 VM 实机验收**。GNOME Shell 软件渲染、无显卡虚拟 Xorg 的加载、GDM 登录界面和 RustDesk 远程控制必须逐项测试。

参考：https://rustdesk.com/docs/en/client/linux/ 和 https://github.com/rustdesk/rustdesk/wiki/Headless-Linux
