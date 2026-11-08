<div align="center">

# 🖥️ Headless Desktop Manager

**Linux 无显示器远程桌面部署与图形会话管理**

按系统的 X11/Wayland 能力选择实际可用的桌面，集中管理 XFCE、GNOME、MATE、虚拟显示和 RustDesk。
根据实际主机状态安装所需组件，并为系统配置保留恢复路径。

[![Version](https://img.shields.io/badge/Version-v4.5.1-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
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

Ubuntu 26 的 GNOME 只能使用 Wayland，**但 XFCE、MATE 仍有 X11 会话可选**。当标准 RustDesk 需要传统 X11 登录界面时，HDM 的智能安装优先提供 **XFCE + Xorg + LightDM + RustDesk**，而非强制把 GNOME 切回 X11。GNOME 仍可以通过菜单 4 手动安装，已有桌面不会自动卸载。

如果宿主机没有已连接的显示输出，XFCE 路径会在计划中提示 Xorg Dummy，并在执行前确认。安装 LightDM **不代表**已经成为默认登录管理器，可通过菜单 2 → 5 查看及切换，并在可用的 SSH/云控制台保护下选择；HDM 不会未经确认就重启桌面或切换登录管理器。

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
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

安装器仅部署 **HDM 管理器**；进入菜单后才由你选择 GNOME、RustDesk 或显示组件。交互终端默认自动打开菜单；再次启动：

```bash
sudo hdm
```

自动化执行可设置 `HDM_NO_AUTO_MENU=1` 取消安装后的菜单弹出。

---

### 正式 Release 更新遇到 HTTP 504

从 **v4.3.2** 起，正式更新先使用 GitHub Release 资产直链，遇到连接/HTTP 504 错误时自动改用 **GitHub API 同一资产的二进制下载**。所有下载依旧校验 Release 公布的原始 SHA256，若本机设置了独立可信 SHA256，也必须一致；校验不通过时不会切换版本。不会使用未经校验的第三方镜像。

旧版本的开发分支更新保留在高级维护；新版本常用菜单 `8 → 1` 只安装最新正式 Release，并在直链 504 时自动使用 GitHub API 同资产 SHA256 下载。

### v4.4.0 升级后 `sudo hdm` 提示找不到命令？

v4.4.0 的正式归档更新器在严格的 root umask 下可能丢失 `hdm.sh` 的执行位。**v4.4.1 已修复**。如已遇到该问题，可通过独立 SSH / 云控制台运行：

```bash
sudo chmod -R a+rX "$(sudo readlink -f /opt/hdm/current)" && sudo chmod 755 /opt/hdm/current/hdm.sh && sudo hdm
```

**注意：v4.4.0 和 v4.4.1 的 `8 → 1` 存在编号比较问题，会误进入空子菜单。** 请使用旧版本的 `8 → 10 → 1 → 2 → 2` 选择正式 Release 更新；升级到 **v4.4.2** 后，`8 → 1` 一键正式更新才恢复正常。权限修复仅针对 HDM 管理器，不涉及 GNOME、LightDM、RustDesk 或用户配置。

## 🔗 桌面链路数轴

HDM 首页现在直接展示 **显示输出 → 登录管理器 → 图形协议 → 桌面环境 → 图形用户会话 → RustDesk → 设备 ID** 七个节点。它们是完整桌面**排障依赖图**，并非严格的系统启动时序。

- **绿色圆点**：本地已检测到符合要求的服务、会话或软件；**红色圆点**：明确缺失或异常；**黄色菱形**：状态未确认。绿色不代表远端画面已验证。
- 每个节点下面显示已识别的组件、版本号或实际分辨率、路径；设备 ID 从 RustDesk 本机查询。查询不到时明确标记，而非填写假 ID。
- 宽终端显示完整横向数轴；普通终端自动分为上下两段；窄终端自动使用纵向步骤。菜单编号仍在流程图下方。
- **双登录管理器 / 多会话识别（v4.5.1）**：若 GDM3 和 LightDM 都已安装，仅一个在运行时线轴显示实际运行者，并注明另一管理器已安装；若两者同时运行或默认配置与运行者冲突，则显示黄色待核实。多个用户图形会话则分别显示协议（例如 `X11+Wayland`）、桌面（`XFCE+GNOME`）以及会话编号，RustDesk 目标标黄待核实，不会随便选一个会话标绿。
- **分辨率归属**：只有 Xrandr 的 DISPLAY 与唯一活动图形用户会话的 Display 一致且匹配 X Socket，才确认该会话的实际分辨率；多个会话时必须人工核实实际远控画面。
- **LightDM/GDM3 是图形登录管理器，不是虚拟显示器。** Xorg 是 X11 的常见显示服务器，Wayland 是另一种显示协议。分辨率取决于实际显示输出，会话仅提供可运行桌面的上下文。

可查看完整路径、节点判断依据：

```bash
sudo hdm --chain
```

在共享屏幕或录制演示时可隐藏设备 ID：`sudo env HDM_HIDE_RUSTDESK_ID=1 hdm`。详见 [桌面链路结构、状态判定与显示示意](docs/desktop-chain.md)。

## 🧭 终端菜单

主菜单严格按上方七节点链路排列，**1–7 分别对应显示输出、登录管理器、图形协议、桌面环境、图形会话、RustDesk 和设备 ID；8 管理 HDM 脚本与日志**。宽终端双列、窄终端单列，安装、卸载、更新和状态直达；进阶配置集中收纳。

```text
  ─────────────────────────────────────────────────────────────
  HDM v4.5.0  ·  ubuntu 24.04 / x86_64
  ──────◆──────────●──────────●──────────●──────
       显示输出     登录管理器    图形协议     桌面环境
       ? 待核实     ✓ GDM3       ✓ X11        ✓ XFCE
  ↓ 继续：会话 → RustDesk → 设备 ID
  ──────●──────────●──────────●──────
       图形会话      RustDesk     设备 ID
       ✓ :0         ✓ v1.5.1     ✓ 已获取
  ◆ 待核实 · ● 本地通过 · ○ 异常（实际终端使用颜色）
  ─────────────────────────────────────────────────────────────

  1. 显示输出管理                  5. 图形会话管理
  2. 登录管理器管理                6. RustDesk 管理
  3. 图形协议管理                  7. 设备 ID 与设备信息
  4. 桌面环境管理                  8. HDM 脚本管理

  ─────────────────────────────────────────────────────────────
  0/q 退出
  请选择 >
```

*以上为菜单排版示意；版本以实际安装为准，桌面、协议和 RustDesk 状态会实时检测。原有底层操作通过兼容映射继续执行，用户看到的编号已统一为八阶段新路径。*
新结构重点如下：**6 → 安装 / 卸载 / 更新 / 配置 ID、Relay、Key**；**7 → 查看设备 ID、架构、系统及 RustDesk 版本**；**8 → 更新脚本、卸载脚本、更新日志、安装日志、快速导出全部日志**。

日常菜单已进一步压缩：**8 个主模块不变，常用命令直接在模块第一层。** 旧版 381 个不同的底层动作继续保留，但不再堆在常用页面；长尾功能放在各自模块的「高级工具」里。菜单清单共 **563 个路由条目、449 个叶子入口**（含重复的历史/高级入口），不等于全部都已通过实机端到端验收。

| 日常操作 | 路径 |
|:---|:---|
| 安装 / 卸载 GDM3 | `2 → 1` / `2 → 3` |
| 安装 / 卸载 LightDM | `2 → 2` / `2 → 4` |
| 安装 XFCE + Xorg + LightDM | **`4 → 1`** |
| 卸载 GNOME / XFCE / MATE | **`4 → 4/5/6`** |
| 安装 / 卸载 / 更新 RustDesk | `6 → 1/2/3` |
| 更新 HDM 最新正式版 | **`8 → 1`** |
| 卸载 HDM（保留配置与日志） | `8 → 2` |

**卸载 GDM3/GNOME 可以先于安装 XFCE/LightDM**，但必须有独立 SSH 或云控制台。卸载时仅需选择一次：`1. 保留配置（APT remove）`、`2. 清除软件配置（APT purge）`、`0/q. 取消`。程序会自动模拟实际 APT 删除计划，保护 RustDesk、OpenSSH、Xorg 和系统核心包；不会自动 `autoremove`、清除用户主目录或重启。`purge` 只针对软件包管理的系统配置，不代表会擦除所有用户个人设置。

**子菜单 `0` 和小写 `q` 都返回上一级；只有在主菜单按 `q` 才退出。** 大写 `Q` 可从任意页面直接退出。取消卸载不会删除 HDM 命令或退出整个程序。

**卸载 HDM 管理器**只清理启动命令和当前版本链接，保留历史版本、配置、日志及所有已安装桌面软件，不卸载 RustDesk。

全部菜单路径：`hdm --menu-tree`；[菜单使用指南](docs/menu-guide.md)。

---

## ⌨️ 常用命令

| 命令 | 用途 |
|:---|:---|
| `sudo hdm` | 打开中文菜单 |
| `hdm --chain` | 查看七节点完整状态与路径 |
| `hdm --preflight` | 只读探测系统、桌面、显示输出 |
| `hdm --readiness` | 检查软件包、服务、会话及待配置项 |
| `hdm --doctor` | 检查活动桌面、登录管理器、RustDesk 和显示问题 |
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

详见 [生产菜单审计与上线验收清单](docs/production-readiness.md)、[测试矩阵](docs/testing-and-limitations.md)、[实施状态](docs/implementation-status.md)、[故障排查](docs/troubleshooting.md)。

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
