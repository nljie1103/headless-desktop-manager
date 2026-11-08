# 简体中文说明

**HDM 的完整中文首页请阅读 [README.md](README.md)。**

安装、紧凑式终端菜单、GNOME/虚拟显示、RustDesk 配置、系统兼容矩阵、技术栈、数据路径、诊断与恢复均在首页统一维护。

**特别注意：** Ubuntu 26.04 的 GNOME 50 使用 Wayland，不能依靠 `WaylandEnable=false` 回到 GNOME Xorg。标准 RustDesk 在已登录会话的画面捕获，与桌面锁屏、注销后的 GDM 登录界面、重启后无人值守是不同验收项目；已有 ARM64 环境仍未完成登录前无人值守验收。详情见 [专项适配说明](docs/ubuntu26-arm64.md)。

[English](README.en.md) · [版本记录](CHANGELOG.md) · [下载](https://github.com/nljie1103/headless-desktop-manager/releases)
