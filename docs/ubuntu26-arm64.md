# Ubuntu 26 ARM64 实验部署手册

> 范围：Ubuntu 26.04/26.10 ARM64（实验阶段）；不同云商的虚拟 GPU、DRM/KMS、内核和安装源可能不同。没有实机成功承诺。

## 关键技术变化

- Ubuntu 25.10 起，GNOME Shell 不再支持 GNOME Xorg 会话。**不要**在 Ubuntu 26 上使用 `WaylandEnable=false` 强行将 GNOME 变成 X11。
- Xorg Dummy 包在 Ubuntu 26.04 ARM64 系统仓库仍存在，但**该驱动不等于 GNOME Wayland 虚拟屏**。Xvfb 也不能代替 GNOME Wayland 会话。
- 可以检测 VKMS/DRM 是否可用；加载 VKMS 不保证 GNOME/GDM 自动识别或 RustDesk 一定能捕获。
- RustDesk 标准版可能通过 PipeWire + xdg-desktop-portal 捕获**已登录**的 Wayland 会话，但登录界面/冷启动无人值守未被本项目验证。RustDesk 2026 年的无人值守 Wayland 预览版主要面向 x86_64。

## 测试步骤

1. 先通过云商控制台创建快照，确认 SSH 保持可用。
2. 下载仓库主分支 `install.sh` 并执行 `sudo bash hdm-install.sh`；此动作只安装 HDM 管理器本体。
3. 运行 `sudo hdm --doctor`、`sudo hdm --quick-status`，查看现有图形、RustDesk 状态。
4. 进入菜单 `9 → 9.1`，阅读计划后执行 GNOME Wayland / PipeWire / RustDesk 安装。不会自动变更 GDM 的 Wayland 设置或重启图形管理器。
5. 无虚拟显示器时可以从菜单 1 独立检测 VKMS，切勿把“驱动已加载”当作已成功显示 GNOME。
6. 从**另一台设备**实际连接，测试屏幕、键鼠、认证和冷启动无人值守。只靠 `systemctl active` 不能认定远控成功。
7. 遇到错误请执行 `sudo hdm --doctor` 并保存已脱敏的状态报告；不要上传 RustDesk 私钥、密码或完整配置。

## 下载安装命令

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
sudo hdm
```

> 下载的是可变 `main` 分支，建议审阅代码；如需固定内容，可以从已审核的 Release 或指定 SHA256 安装。

## 资料

- Ubuntu 26.04 官方 GNOME Wayland 说明：https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/
- RustDesk Wayland 无人值守预览介绍：https://rustdesk.com/blog/unattended-remote-access-wayland/
- Ubuntu 26.04 ARM64 Xorg Dummy 包：https://packages.ubuntu.com/resolute/arm64/xserver-xorg-video-dummy
