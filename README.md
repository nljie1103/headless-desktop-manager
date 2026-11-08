<div align="center">

# 🖥️ Headless Desktop Manager

**Linux 无显示器远程桌面部署与图形会话管理**

按系统的 X11/Wayland 能力选择实际可用的桌面，集中管理 XFCE、GNOME、MATE、虚拟显示和 RustDesk。
根据实际主机状态安装所需组件，并为系统配置保留恢复路径。

[![Version](https://img.shields.io/badge/Version-v4.5.3-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
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

## 🧩 先弄清楚：哪些软件是一类，究竟需要安装哪些？

**普通用户只需选定一套桌面方案，不需要把菜单中出现的软件全部安装。** HDM 的安装 / 卸载 / 更新针对软件包；启动 / 停止 / 重启 / 开机自启针对真正的 systemd 服务。软件包“已安装”和服务“已启动”是两回事。

| 层次 / 类别 | 常见选择 | 需要几个？ | 起什么作用、怎么管理 |
|:---|:---|:---|:---|
| **内核显示接口及输出** | **DRM/KMS**、云主机提供的 `Virtual-1`、实体显示输出 | 系统已经提供且可用就保留 | DRM/KMS 是内核接口；`connected` 仅表示连接器状态，不代表桌面能正常显示 |
| **内核虚拟显示驱动（按需）** | **VKMS** | 仅缺乏适用 DRM/KMS 输出并验证可兼容时才考虑 | VKMS 属于内核 DRM 层，**不是 Xorg 的替代品** |
| **X11 图形显示服务器** | **Xorg**；**Xvfb**（特殊场景） | 常规 XFCE 方案优先 Xorg；不是两个都装 | Xvfb 是无实体屏幕的 X11 服务器，不等于 DRM/KMS |
| **Xorg 虚拟显示驱动（按需）** | **Xorg Dummy** | Xorg 缺可用输出且配置确有需要时再使用 | Dummy 由 Xorg 使用，不是与 Xorg 二选一 |
| **图形协议与会话** | **X11** 或 **Wayland** | 由桌面环境与登录会话决定 | Xorg 通常提供 X11 服务，Wayland 通常由桌面合成器提供；二者不是物理或虚拟显示设备 |
| **登录管理器** | **LightDM / GDM3 / SDDM** | **选一个作为默认且实际运行的登录管理器** | 提供登录界面并启动桌面；可安装多个，但不应同时启动争夺图形 seat |
| **登录界面（Greeter）** | LightDM GTK Greeter、GDM 自带 Greeter | 与登录管理器配套 | LightDM 需要选定可用 Greeter；GDM 不必装 LightDM Greeter |
| **桌面环境** | **XFCE / GNOME / MATE** | **选一个作为主要桌面** | 提供窗口、面板和桌面；可以共存，但没有必要全部安装 |
| **图形会话** | XFCE X11、GNOME Wayland、MATE X11 | 必须有一个可登录的实际会话 | 是登录后形成的运行状态，**不是单独安装的软件** |
| **远程控制** | RustDesk | 需要远控才安装 | 安装客户端后还需验证服务、会话及实际远端画面 |
| **辅助依赖** | D-Bus、xserver-xorg、dbus-x11 等 | 根据方案自动补齐 | 普通用户不应被迫手工选择 |

> **重点纠正：DRM/KMS 和 Xorg 不在同一层，不是二选一。** 典型 X11 链路是“DRM/KMS 提供显示输出 → Xorg 使用该输出 → LightDM 启动登录界面和 XFCE 会话 → RustDesk 尝试捕获画面”（简化的功能关系，非严格启动顺序）。VKMS 是内核虚拟 DRM 驱动，Xorg Dummy 是 Xorg 虚拟显示驱动，Xvfb 是单独的虚拟 X11 服务器，三者也不应当被当作同类可互换软件。**已报告 `card0-Virtual-1: connected` 的云主机，先验证它能否被 Xorg 和登录界面实际使用；不能凭 connected 就保证远控成功，也不要盲目叠加 Dummy、Xvfb、VKMS。**

### 按用途选一整套，而不是逐个猜软件

| 使用目标 | 推荐主要桌面 | 登录管理器 | 图形会话 | 显示输出 | RustDesk |
|:---|:---|:---|:---|:---|:---|
| **Ubuntu 26.04 ARM64、想试 X11 登录界面无人值守** | XFCE | LightDM + GTK Greeter | Xorg / X11 | 优先使用已有 DRM 虚拟输出 | 安装并**实际远端验证** |
| Ubuntu 26.04、偏好完整 GNOME 桌面 | GNOME | GDM3 | Wayland | 依赖主机实际显示能力 | 登录后可测试；**不要承诺登录前可控** |
| 轻量传统桌面 | MATE | LightDM + GTK Greeter | Xorg / X11 | 已有输出优先 | 按需 |

**最短正确链路：显示输出可用 → Xorg（X11 方案）→ LightDM + GTK Greeter → XFCE → 图形登录会话 → RustDesk。** 其中“安装成功 → 能启动 → 能登录 → RustDesk 能远控”必须逐级验证，不能只因为 Docker/DRM/LightDM 显示绿色就认定部署成功。

### 新加坡 ARM 实际案例：LightDM 安装了却没有运行

2026-11-08 通过 SSH 只读检查确认 Ubuntu 26.04 ARM64 机器具有以下状态：

- `card0-Virtual-1` 显示输出为 connected；`/usr/bin/Xorg` 已安装，但 **Xorg 进程不存在**。
- `lightdm`、`lightdm-gtk-greeter` 已安装；`display-manager.service` 指向 LightDM，`graphical.target` 活动；**LightDM 处于 enabled / inactive (dead)**。
- **XFCE、`xfce4-session` 未安装**，`/usr/share/xsessions/` 没有 XFCE 会话；LightDM 配置 `user-session=ubuntu` 也没有对应的可用主要桌面。
- LightDM 的 `Result=success`、当前启动日志为空，并不能直接证明 LightDM 损坏或启动失败；需要实际启动后读取退出状态和错误日志。

适合当前机器的**最小补齐方案**（会安装软件，请保留 SSH/云控制台）：

```bash
sudo apt update
sudo apt install xfce4 xfce4-session xorg lightdm lightdm-gtk-greeter dbus-x11
ls /usr/share/xsessions/
```

已有 LightDM 且 `/etc/X11/default-display-manager` 是 `/usr/sbin/lightdm` 时，**无需再次安装 GDM3，也无需反复重装 LightDM**。先确认 XFCE 会话文件存在，再检查/配置默认会话：

```bash
sudo install -d /etc/lightdm/lightdm.conf.d
printf '[Seat:*]\nuser-session=xfce\ngreeter-session=lightdm-gtk-greeter\n' | sudo tee /etc/lightdm/lightdm.conf.d/99-hdm-xfce.conf
lightdm --show-config
```

**启动与开机自启是两件事：**

```bash
sudo systemctl start lightdm         # 现在启动登录界面（会影响本机图形会话）
sudo systemctl enable lightdm        # 下次开机自动尝试启动，不会立即启动
systemctl status lightdm --no-pager -l
pgrep -a Xorg                         # 检查是否真正生成 Xorg 进程
```

若不成功，不要盲目重装、重启或删除配置；先读取错误：

```bash
sudo journalctl -b -u lightdm --no-pager -n 80
sudo ls -la /var/log/lightdm/
sudo tail -n 80 /var/log/lightdm/lightdm.log 2>/dev/null
```

如果默认登录管理器是另一个程序，先使用 `sudo dpkg-reconfigure lightdm`（交互选择）或 HDM 的「切换默认登录管理器」，**不要并发启动 GDM3 和 LightDM**。停止/重启登录管理器会终止图形登录并可能切断 RustDesk；只能在独立 SSH/云控制台保护下执行。**完整验收还包括从另一台设备测试登录界面、锁屏、注销和重启后的 RustDesk 画面与键鼠。**

### HDM 菜单该怎样理解？

普通用户只应看到“**安装、卸载、更新、启动、停止、重启、开机自启**”这类能执行的动作；“X11 / Wayland 说明”“重复的状态查询”“高级协议诊断”不应作为独立日常任务。状态和兼容性检查应由安装/启动时**自动运行**并在失败时给出原因。

**v4.5.3 维持六类按任务操作的菜单**：`1` 快速部署、`2` 桌面环境、`3` 登录管理器、`4` RustDesk、`5` 显示设置、`6` HDM 管理。LightDM/GDM3 启动、停止、重启在 `3 → 3/4/5`，开机自启在 `3 → 6/7`；安装 XFCE 在 `2 → 1`，图形会话管理在 `2 → 9`，可创建登录入口、查看会话和按 ID 安全注销。仍使用 v4.5.1 的服务器需要升级 HDM 管理器后才能使用新菜单。

> **版本提醒：** 此处描述的是 v4.5.3 的最新菜单；旧版 v4.5.1 的八模块菜单不会自动改变。升级 HDM 管理器不等于自动安装桌面或启动 LightDM。HDM 尚不能保证任意云机型的登录前无人值守远控成功。

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

Ubuntu 26 的 GNOME 只能使用 Wayland，**但 XFCE、MATE 仍有 X11 会话可选**。当标准 RustDesk 需要传统 X11 登录界面时，HDM 的智能安装优先提供 **XFCE + Xorg + LightDM + RustDesk**，而非强制把 GNOME 切回 X11。GNOME 仍可通过主菜单 2 手动安装，已有桌面不会自动卸载。

如果宿主机没有已连接的显示输出，XFCE 路径会在计划中提示 Xorg Dummy，并在执行前确认。安装 LightDM **不代表**已经成为默认登录管理器；开发分支可从 `3 → 11` 选择默认管理器，再在 `3 → 3/6` 分别启动服务与设置自启。HDM 不会未经确认就重启桌面或切换登录管理器。

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

**历史说明：** v4.5.1 正式发布包的菜单 `8 → 1` 更新最新正式 Release；新版 v4.5.2 改为 `6 → 1`。更新器在 Release 直链 504 时仍会使用 GitHub API 下载同一资产并校验 SHA256。

### v4.4.0 升级后 `sudo hdm` 提示找不到命令？

v4.4.0 的正式归档更新器在严格的 root umask 下可能丢失 `hdm.sh` 的执行位。**v4.4.1 已修复**。如已遇到该问题，可通过独立 SSH / 云控制台运行：

```bash
sudo chmod -R a+rX "$(sudo readlink -f /opt/hdm/current)" && sudo chmod 755 /opt/hdm/current/hdm.sh && sudo hdm
```

**注意：v4.4.0 和 v4.4.1 的 `8 → 1` 存在编号比较问题，会误进入空子菜单。** 请使用旧版本的 `8 → 10 → 1 → 2 → 2` 选择正式 Release 更新；升级到 **v4.4.2** 后，`8 → 1` 一键正式更新才恢复正常。权限修复仅针对 HDM 管理器，不涉及 GNOME、LightDM、RustDesk 或用户配置。

## 🔗 桌面链路数轴

使用 `hdm --chain` 可查看 **显示输出 → 登录管理器 → 图形协议 → 桌面环境 → 图形用户会话 → RustDesk → 设备 ID** 七个诊断节点；日常菜单首页改为短状态摘要，不再强制显示冗长数轴。它们是完整桌面**排障依赖图**，并非严格的系统启动时序。

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

## 🧭 终端菜单：6 个分类，常用操作直达

**v4.5.3** 使用按用户操作分类，去掉首页上独立的“图形协议”“图形会话”“设备 ID”技术菜单，移除大量重复“查看 / 说明 / 高级诊断”嵌套。**v4.5.1 以前的安装保留旧菜单，需要升级版本。**

```text
  HDM v4.5.3 · ubuntu 26.04 / aarch64
  桌面：未安装 | 登录界面：lightdm / inactive | RustDesk：active
  先安装桌面，再启动登录界面；远程画面必须实际验证。

  1. 快速部署                  4. RustDesk 远程控制
  2. 桌面环境                  5. 显示设置（有画面则无需安装虚拟显示）
  3. 登录管理器                6. HDM 管理

  0/q 退出
  请选择 >
```

*示意中的检测状态以实际机器为准；状态栏只显示摘要，详细七节点依赖诊断仍可通过 `hdm --chain` 查看。*

| 分类 | 常用操作 | 直接菜单入口 |
|:---|:---|:---|
| 快速部署 | 安装/补齐桌面与 RustDesk、预览计划、启动登录界面、查看就绪情况 | `1 → 1/2/3/4` |
| 桌面环境 | 独立安装 XFCE / GNOME / MATE、更新、卸载、状态；新建登录入口与会话管理 | `2 → 1/2/3` 安装；`2 → 4` 更新；`2 → 5/6/7` 卸载；`2 → 9` 会话与协议 |
| 登录管理器 | 安装 LightDM / GDM3、启动、停止、重启、开机自启、更新、卸载、切换 | `3 → 1/2` 安装；`3 → 3/4/5` 启停重启；`3 → 6/7` 自启开关；`3 → 8` 更新；`3 → 9/10` 卸载；`3 → 11` 切换 |
| RustDesk | 安装、启动、停止、重启、自启开关、更新、卸载、设备 ID、服务器和密码 | `4 → 1–12` |
| 显示设置 | 查看输出、调整分辨率；只有缺输出才研究 Dummy / Xvfb / VKMS | `5 → 1/2/3` |
| HDM 管理 | 更新 HDM、卸载 HDM、诊断、日志、系统信息 | `6 → 1–6` |

**无需把所有组件装一遍。** LightDM / GDM3 是同类登录管理器，选一个默认运行；XFCE / GNOME / MATE 是同类桌面环境，选一个主桌面。Xorg 是 X11 显示服务器，DRM/KMS 是内核显示接口，两者不是同类竞争软件；已连接可用的虚拟显示输出无需额外安装 Dummy、Xvfb、VKMS。

**单独安装桌面不捆绑登录管理器。** 例如 `2 → 1` 只安装 XFCE 及会话组件，已安装的 LightDM 和 Xorg 不会重复安装；`1 → 1` 则会按缺失项补齐整体桌面与 RustDesk。

图形会话管理：`2 → 9 → 1` 查看登录界面和图形用户会话，`2 → 9 → 2` **新建登录入口（启动 LightDM/GDM3，仍需输入密码）**，`2 → 9 → 3` 查看已登录用户会话详情，`2 → 9 → 4` 安全结束指定用户图形会话（不删除账号或文件），`2 → 9 → 5` 选择 LightDM 默认 XFCE/MATE X11 桌面，`2 → 9 → 6` 查看 Xorg/X11/Wayland，`2 → 9 → 7` 查看登录管理器失败日志。这里的“新建”不会凭空创建经过认证的用户桌面，必须经过登录界面实际登录。

**显示状态**：`5 → 1` 会显示 `/sys/class/drm` 下的 `Virtual-1` 等 DRM/KMS 连接器状态，以及 Xorg、LightDM/GDM3、RustDesk 和已登录用户会话。DRM connected 不能证明 Xorg 正在运行，服务 active 不能证明 RustDesk 可远控。

普通用户不需要知道每一个 `loginctl`、X11、Wayland 诊断项。**原有 381 个底层动作的实现文件保留，已不全部暴露在菜单中**；需要深度排障可使用 `hdm --doctor`、`hdm --chain` 或导出诊断日志。新版菜单为 **72 个条目（含 6 个分类与 62 个可执行操作）**，最大三级，不再是五百多个子菜单。

**重要：** “开机自启”只影响下次启动，不等于现在启动；停止或重启 LightDM/GDM3、RustDesk 可能切断远程图形会话，需在 SSH / 云控制台操作。安装成功、服务运行、图形会话可用、RustDesk 外部实测是四个不同的验收阶段。

**返回规则：** 子菜单按 `0` 或小写 `q` 返回上一级；主菜单按 `0/q` 退出；大写 `Q` 直接退出。卸载先模拟 APT 删除计划，再选择保留配置或清除包配置，不会自动 `autoremove`、清理用户数据或重启。HDM 自身卸载只处理脚本入口，保留已安装桌面、RustDesk、旧版本和日志。

全部当前菜单：`hdm --menu-tree`；详见 [菜单使用指南](docs/menu-guide.md)。

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
