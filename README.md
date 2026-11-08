<div align="center">

# 🖥️ Headless Desktop Manager

**Linux 无显示器远程桌面部署与图形会话管理**

按系统的 X11/Wayland 能力选择实际可用的桌面，集中管理 XFCE、GNOME、MATE、虚拟显示和 RustDesk。
根据实际主机状态安装所需组件，并为系统配置保留恢复路径。

[![Version](https://img.shields.io/badge/Version-v4.1.0-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
[![Linux](https://img.shields.io/badge/Platform-Linux-454c55?style=for-the-badge&logo=linux)](docs/installation.md)
[![License](https://img.shields.io/badge/License-MIT-378a64?style=for-the-badge)](LICENSE)

**简体中文** · [English](README.en.md) · [版本记录](CHANGELOG.md) · [下载版本](https://github.com/nljie1103/headless-desktop-manager/releases)

</div>

---

## ✨ 核心功能

| 模块 | 功能 |
|:---|:---|
| 🖥️ 桌面管理 | 安装和检查 GNOME、XFCE、MATE；检测已有桌面并尽量保留原配置 |
| 🪟 虚拟显示 | 管理 Xorg Dummy、Xvfb、VKMS；区分软件包存在、驱动输出与真实桌面会话 |
| 🔗 RustDesk | 安装、更新客户端，管理 ID / 中继 / 公钥、权限、服务与配置读回 |
| 🧭 智能部署 | 根据系统协议、显示输出、现有桌面与内存生成安装计划，支持中断续装 |
| 🩺 诊断修复 | 检查 GDM3、X11/Wayland、用户会话与依赖，收集安装及系统日志 |
| 🔄 更新回滚 | 在线更新 HDM，保留版本目录及显示配置恢复机制 |

HDM 的状态判断遵循一条原则：**安装成功 ≠ 服务已运行 ≠ 已有图形用户会话 ≠ RustDesk 可以控制画面**。

---

## 💻 适配范围与测试进度

当前配置矩阵覆盖 **10 条 Ubuntu / 架构 / 桌面及显示方案路径**。它们是实现或测试路径，**不是 10 种已经完成远程桌面验收的机型**。具体 CPU、虚拟 GPU、内核 DRM、云商平台仍会影响结果。

| 系统 / 架构 | 路径 | 已验证的范围 | 仍需验证 |
|:---|:---|:---|:---|
| Ubuntu 24.04 · x86_64 | GNOME + X11 / Dummy | 双 Box：GNOME 核心包、GDM3、RustDesk 1.5.1 安装和服务、诊断测试通过 | Dummy 显示及 GNOME 实际登录、外部远控 |
| Ubuntu 24.04 · ARM64 | GNOME + X11 / Dummy | 软件包清单及相关代码路径 | ARM64 实机安装、显示、远控 |
| Ubuntu 24.04 · x86_64 | GNOME + Xvfb | 配置逻辑与单元测试 | Xvfb 实际连接 GNOME/RustDesk |
| Ubuntu 24.04 · x86_64 | GNOME + VKMS | 检测逻辑与单元测试 | 内核模块、GNOME 会话及画面 |
| Ubuntu 26.04 · ARM64 | GNOME 50 / Wayland | ARM64 实机曾安装 GNOME/GDM3/RustDesk，发现会话和显示问题 | 无屏输出、锁屏、登录前无人值守 |
| Ubuntu 26.04 · x86_64 | GNOME 50 / Wayland | 包管理与兼容处理逻辑 | Wayland 登录前远控及实际画面 |
| Ubuntu 26.10 · ARM64 | GNOME Wayland | 包管理与兼容处理逻辑 | 系统及整条图形链路实测 |
| Ubuntu 26.04 · ARM64 | XFCE + X11 / LightDM | 包名与安装计划已核对，自动化模拟通过 | ARM64 图形登录、RustDesk 外部连接及重启 |
| Ubuntu 26.04 · x86_64 | XFCE + X11 / LightDM | 包名与安装计划已核对，自动化模拟通过 | 实机登录管理器与远控画面 |
| Ubuntu 26.10 · ARM64 | XFCE + X11 / LightDM | 安装路径已有代码支持 | 原生系统安装及整条远控链路 |

**当前完整通过“无实体显示器 → 开机登录前 → RustDesk 可控画面”端到端验收的组合：0。**
Ubuntu 24.04 x86_64 是持续集成的主要测试环境；Debian、Fedora、RHEL 等适配目录不代表这些系统已经获得同等级支持。详见 [功能验证矩阵](docs/testing-and-limitations.md) 和 [兼容配置](config/compatibility.tsv)。

### 推荐策略：可用性优先

Ubuntu 26 的 GNOME 只能使用 Wayland，**但 XFCE、MATE 仍有 X11 会话可选**。当标准 RustDesk 需要传统 X11 登录界面时，HDM 的智能安装优先提供 **XFCE + Xorg + LightDM + RustDesk**，而非强制把 GNOME 切回 X11。GNOME 仍可以通过菜单 3 手动安装，已有桌面不会自动卸载。

如果宿主机没有已连接的显示输出，XFCE 路径会在计划中提示 Xorg Dummy，并在执行前确认。安装 LightDM **不代表**已经成为默认登录管理器，需通过菜单 4.4 查看，并在可用的 SSH/云控制台保护下手动选择；HDM 不会未经确认就重启桌面或切换登录管理器。

这只是更有希望实现登录前访问的技术路径，**不是无人值守成功承诺**。登录界面、虚拟显示、锁屏与重启后实际控制仍需现场验证。参考 [Ubuntu 官方桌面会话说明](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/) 和 [RustDesk 官方 Linux 指南](https://rustdesk.com/docs/en/client/linux/)。

### Ubuntu 26 GNOME / Wayland 的关键限制

Ubuntu 25.10 起，Ubuntu GNOME 桌面仅提供 Wayland 会话；Ubuntu 26.04 使用 GNOME 50。**XWayland 可以运行旧 X11 应用，但不是 GNOME 的 Xorg 登录会话。**

- **已经登录 GNOME**：标准 RustDesk 使用 PipeWire 与 Desktop Portal 获取 Wayland 画面，具体捕获授权和输入能力需现场测试。
- **桌面锁屏**：与“注销 / 开机前登录界面”不同；不能仅凭软件安装或 Wayland 协议判定锁屏可远控，必须独立测试锁屏前后画面与键鼠恢复。
- **注销 / 重启后的 GDM 登录界面**：标准 RustDesk 的 Wayland 登录前远控不应视为可用。RustDesk 官方提供的无人值守 Wayland 预览版主要面向 **x86_64 Debian/Ubuntu**，不能直接当作 ARM64 已适配。
- **不要设置 `WaylandEnable=false` 来尝试把 Ubuntu 26 GNOME 切回 Xorg。** Xorg Dummy、Xvfb 不会自动生成 GNOME Wayland 可捕获的屏幕；VKMS 也依赖内核和合成器实际支持。

2026-11-07 的 Ubuntu 26.04 ARM64 验证中，GNOME 50.1、GDM3、RustDesk 1.5.1 曾安装并运行部分服务，但没有证明 GNOME 用户会话可用，RustDesk 曾报告 `cannot open display: :0`。此问题不能用“RustDesk 服务 active”掩盖。

参考：[Ubuntu 官方 Wayland 变更](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/) · [GNOME 49 技术变更](https://release.gnome.org/49/developers/) · [RustDesk Linux 指南](https://rustdesk.com/docs/en/client/linux/) · [RustDesk Wayland 无人值守预览](https://rustdesk.com/blog/unattended-remote-access-wayland/) · [Ubuntu 26 ARM64 适配说明](docs/ubuntu26-arm64.md)

---

## 📥 下载与快速开始

> **安装前：** 需要 Linux、Bash、sudo 以及可访问的软件源。变更 GDM3、显示驱动或系统启动目标可能中断远程访问；请预先保留 SSH、云厂商控制台和可用快照。未经设备测试不要直接对唯一远程连接执行破坏性配置。

[GitHub Releases 下载固定版本](https://github.com/nljie1103/headless-desktop-manager/releases)；Release 附带归档与摘要文件，可先核对再安装。

Ubuntu 开发分支的最简安装（`main` 是可变代码，运行前应审阅脚本）：

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh
sudo bash hdm-install.sh
```

安装器仅部署 **HDM 管理器**；进入菜单后才由你选择 GNOME、RustDesk 或显示组件。交互终端默认自动打开菜单；再次启动：

```bash
sudo hdm
```

自动化执行可设置 `HDM_NO_AUTO_MENU=1` 取消安装后的菜单弹出。

---

## 🧭 终端菜单

主菜单沿用稳定的 10 个入口，采用类似服务器管理面板的紧凑布局：宽终端双列、窄终端单列；子菜单按短编号逐级进入。

```text
  ─────────────────────────────────────────────────────────────
  HDM v4.1.0  ·  ubuntu 24.04 / x86_64
  桌面包 GNOME  ·  会话 x11  ·  RustDesk 1.5.1
  ─────────────────────────────────────────────────────────────

  1. 安装虚拟显示器                6. 更新 RustDesk
  2. 管理显示与分辨率              7. RustDesk 连接配置
  3. 安装桌面环境                  8. 更新 HDM 管理器
  4. 管理桌面与会话                9. 智能安装与续装
  5. 安装 RustDesk                 10. 系统诊断与日志

  ─────────────────────────────────────────────────────────────
  0 / q 退出
  请选择 >
```

*以上为菜单排版示意；版本以实际安装为准，桌面、协议和 RustDesk 状态会实时检测。菜单编号和操作路由未因排版改变。*
全部菜单路径：`hdm --menu-tree`；[菜单使用指南](docs/menu-guide.md)。

---

## ⌨️ 常用命令

| 命令 | 用途 |
|:---|:---|
| `sudo hdm` | 打开中文菜单 |
| `hdm --preflight` | 只读探测系统、桌面、显示输出 |
| `hdm --readiness` | 检查软件包、服务、会话及待配置项 |
| `hdm --doctor` | 检查 GNOME、GDM3、RustDesk 和显示问题 |
| `hdm --session-status` | 区分现有 X11/Wayland 会话与真正的 GNOME 用户会话 |
| `sudo hdm --session-start` | 尝试启动 GDM3，再次核验 GNOME 用户会话 |
| `sudo hdm --quick-status` | 查看一键部署进度 |
| `hdm --check-update` | 检查正式版及开发版更新 |
| `sudo hdm --export-diagnostics` | 导出包含可用日志的诊断包 |

对于已安装 GNOME 但只能看见 GDM3 服务的机器，请先使用 `--session-status`。存在 XFCE/X11 用户会话 **不等于** GNOME 会话已经建立。

---

## 🏗️ 技术架构与项目结构

基于 **Bash + Python 3** 实现：Bash 负责菜单、包管理、systemd 操作、备份与回滚；Python 负责诊断报告、配置解析、校验及发布元数据检查。系统包管理器和 RustDesk 都是实际外部依赖。

```text
headless-desktop-manager/
├── hdm.sh             # CLI 入口
├── install.sh         # 管理器安装入口
├── ui/                # 菜单结构、输入与动作路由
├── core/              # 环境检测、下载、软件包与备份
├── modules/
│   ├── display/       # Dummy / Xvfb / VKMS
│   ├── desktop/       # GNOME 与图形会话
│   ├── rustdesk/      # 安装、配置与权限
│   ├── diagnostics/   # 状态、诊断及就绪清单
│   ├── quick-install/ # 安装计划与续装
│   └── updater/       # 在线更新与回滚
├── config/            # 系统兼容性、默认值及方案
├── scripts/           # 检查与辅助工具
├── tests/             # 自动化回归测试
├── docs/              # 安装、显示、排错与开发说明
└── release/           # 版本说明
```

流程为：**环境检测 → 生成计划 → 确认变更 → 安装 / 配置 → 重新核验 → 记录日志及恢复点**。不同显示协议不共享一套虚拟显示实现。

### 💾 数据存储与恢复

| 数据 | 默认位置 | 用途 |
|:---|:---|:---|
| 管理器版本 | `/opt/hdm/releases/`、`/opt/hdm/current` | 版本切换及回退 |
| HDM 配置 | `/etc/hdm/config.conf` | 分辨率、软件源等本机设置 |
| 状态和备份 | `/var/lib/hdm/` | 快照、安装续装、回滚标记和导出文件 |
| 已验证下载缓存 | `/var/cache/hdm/` | RustDesk 包等资产及校验记录 |
| HDM 操作日志 | `/var/log/hdm/` | 失败排查、安装步骤日志 |
| RustDesk 配置 | `/root/.config/rustdesk/RustDesk2.toml` 及用户配置目录 | 分作用域存储 ID / 中继 / 公钥和访问权限 |

状态、配置和日志目录由 HDM 设置受限权限；普通用户可能需要 `sudo` 才能查看完整状态。备份恢复只针对 HDM 管理的受支持文件，不等于系统整机快照。**不要将原始 RustDesk 配置、永久密码或未审阅的诊断包公开分享。**

---

## 🧪 测试与验收边界

```bash
bash tests/run.sh
```

- Ubuntu 24.04 x86_64：两台独立 Box 已执行代码测试；测试机完成 GNOME 核心组件、GDM3 服务及 RustDesk 1.5.1 的安装验证。
- GitHub Actions：执行 Bash 语法、ShellCheck 和仓库测试；其通过仅证明静态与自动测试，不代表 GUI 远程操控成功。
- Ubuntu 26.04 ARM64：已有真实安装与故障记录，**GNOME Wayland 登录前 / 无人值守尚未通过验收**。
- 仍需外部 RustDesk 客户端实测：屏幕画面、键鼠、锁屏、注销、重启后的 GDM 登录界面及跨主机访问。

详见 [测试矩阵](docs/testing-and-limitations.md)、[实施状态](docs/implementation-status.md)、[故障排查](docs/troubleshooting.md)。

---

## 🔒 运维与支持

- 软件安装、桌面切换和显卡 / Xorg 配置会触及系统级状态；通过云平台快照和 SSH 保留恢复路径。
- ID 服务器、中继地址与公钥在用户主动预览时完整显示，便于核对；密码和认证信息不得写入公开日志。
- 自动更新会保留旧版本；显示配置提供独立快照和超时恢复机制。真实恢复效果仍应通过目标机器验证。
- 问题反馈：[GitHub Issues](https://github.com/nljie1103/headless-desktop-manager/issues) · [安全说明](SECURITY.md) · [安装文档](docs/installation.md) · [更新记录](CHANGELOG.md)。

项目采用 [MIT License](LICENSE)。

<div align="center">

**Made by [nljie1103](https://github.com/nljie1103) · Headless Desktop Manager**

</div>
