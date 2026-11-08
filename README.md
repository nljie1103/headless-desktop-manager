<div align="center">

# 🖥️ Headless Desktop Manager

**HDM · Linux 无显示器远程桌面及 RustDesk 管理工具**

安装、维护 XFCE / GNOME / MATE，管理登录界面、图形协议、显示输出与远程控制。

[![Version](https://img.shields.io/badge/Version-v5.0.0-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
[![Platform](https://img.shields.io/badge/Platform-Linux-454c55?style=for-the-badge&logo=linux)](docs/installation.md)
[![License](https://img.shields.io/badge/License-MIT-378a64?style=for-the-badge)](LICENSE)

**简体中文** · [English](README.en.md) · [版本记录](CHANGELOG.md) · [Releases](https://github.com/nljie1103/headless-desktop-manager/releases)

</div>

---

## 🚀 快速开始

在 Ubuntu 终端中执行：

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

安装后打开菜单：

```bash
sudo hdm
```

**安装命令部署的是 HDM 管理器**，不会自动替你卸载桌面或更改 RustDesk。`main` 是持续更新分支，执行前可以先检查安装脚本；需要固定版本请使用 [GitHub Releases](https://github.com/nljie1103/headless-desktop-manager/releases)。远程服务器请始终保留 SSH 或云控制台。

## ✨ 核心功能

| 模块 | 能做什么 |
|---|---|
| **1 · 显示输出** | 查看 DRM/KMS，调整分辨率，按需配置 Xorg Dummy、Xvfb、VKMS |
| **2 · 登录管理器** | 独立安装、卸载、切换 LightDM / GDM3，管理启停和自启 |
| **3 · 图形协议** | 查看 X11 / Wayland，选择兼容的 X11 或 GNOME Wayland 登录方案 |
| **4 · 桌面环境** | 独立安装、更新、卸载 XFCE、GNOME、MATE |
| **5 · 图形会话** | 查看、准备登录入口、查看详情和注销指定会话 |
| **6 · RustDesk** | 安装更新、服务控制、密码、**访问权限管理**与授权诊断 |
| **7 · 设备 ID** | 查看 RustDesk ID，配置自建 ID / 中继服务器 |
| **8 · HDM 管理** | 快速部署、就绪检查、脚本更新、诊断、日志与卸载 |

首页保留**七节点依赖线轴**，依次为：显示输出 → 登录管理器 → 图形协议 → 桌面环境 → 图形会话 → RustDesk → 设备 ID。节点绿色表示对应的**本地条件**已满足，并不等于远程锁屏、重启后的控制已经验证。

## 🔐 RustDesk 访问权限

在 `sudo hdm` 中选择 **`6 → 11 访问权限管理`**，可以设置完全访问、仅查看、自定义权限，并分别开关键盘鼠标、剪贴板、文件传输、音频、TCP 隧道、远程重启及会话录制。**`6 → 12`** 诊断客户端设置全灰、Polkit 授权及配置问题。

权限保存采用 root 和当前登录用户配置双端读回、备份与失败回滚。RustDesk 运行期间更改权限可能短暂中断当前远程连接，因此只在必要时确认一次。**GUI 全灰不一定是权限值问题**：管理员 Unlock、XFCE 的 Polkit 图形授权代理，以及服务端更高优先级的策略，都可能影响 GUI 能否编辑。[RustDesk 官方权限说明](https://rustdesk.com/docs/zh-cn/self-host/client-configuration/advanced-settings/)。

## 🧭 推荐部署和兼容性

| 场景 | 建议方案 | 说明 |
|---|---|---|
| **Ubuntu 26.04 · ARM64** | **XFCE + X11 + LightDM + RustDesk** | 已有实际远程登录界面与 XFCE 用户会话测试；冷启动与锁屏仍需分别验证 |
| Ubuntu 26.04 · x86_64 | XFCE / X11 或 GNOME / Wayland | 按实际桌面与云机图形支持选择 |
| Ubuntu 24.04 · x86_64 / ARM64 | XFCE、MATE 或 GNOME | 依赖兼容及 CI 测试不等于所有机器的实际远控验收 |

**DRM 不是 X11/Wayland 的替代协议。** DRM/KMS 提供内核显示输出；Xorg 通常提供 X11；LightDM/GDM3 负责登录界面；XFCE、MATE 和 GNOME 提供桌面。若云主机已经有 connected 的虚拟 DRM 输出，先测试它，**不需要同时安装 Dummy、Xvfb、VKMS**。

Ubuntu 26 GNOME 只提供 Wayland 会话，不要通过 `WaylandEnable=false` 强行恢复 GNOME Xorg。对 RustDesk 的登录前远控，优先尝试 XFCE + X11 / LightDM，并分别验证密码登录、键鼠、锁屏和重启。更多内容见 [Ubuntu 26 ARM64 指南](docs/ubuntu26-arm64.md) 与 [兼容矩阵](docs/testing-and-limitations.md)。

## ⌨️ 常用命令

| 命令 | 用途 |
|---|---|
| `sudo hdm` | 打开交互菜单 |
| `hdm --chain` | 七节点线轴与完整判断依据 |
| `hdm --readiness` | 组件安装和服务就绪检查 |
| `hdm --doctor` | 诊断图形和远程控制问题 |
| `hdm --rustdesk-permissions` | RustDesk 权限/Polkit 只读诊断 |
| `sudo hdm --export-diagnostics` | 导出经过脱敏的诊断资料 |

## 🗂️ 项目结构与数据存储

```text
├── hdm.sh             # 主程序
├── install.sh         # 安装入口
├── ui/                # 七节点菜单及动作路由
├── modules/           # 桌面、显示、RustDesk、会话、诊断
├── scripts/           # 状态检查、配置校验、菜单生成
├── config/            # 版本及兼容数据
├── tests/             # 自动化测试
└── docs/              # 安装、设计和故障排查说明
```

| 路径 | 内容 |
|---|---|
| `/opt/hdm/` | HDM 历史安装版本与当前版本链接 |
| `/etc/hdm/` | HDM 自有系统配置 |
| `/var/lib/hdm/` | 状态记录、备份快照和回滚信息 |
| `/var/log/hdm/` | 管理器操作日志 |

**安全原则**：软件包安装不等于服务运行；登录界面可显示不等于用户已登录；RustDesk 服务运行也不等于远端已验证。停止登录管理器、重启 RustDesk 或改动虚拟显示前，请保留独立 SSH / 云控制台及必要的快照。

[安装文档](docs/installation.md) · [七节点链路说明](docs/desktop-chain.md) · [菜单指南](docs/menu-guide.md) · [诊断与限制](docs/testing-and-limitations.md) · [Issues](https://github.com/nljie1103/headless-desktop-manager/issues) · [许可证](LICENSE)
