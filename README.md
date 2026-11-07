<div align="center">

# 🖥️ Headless Desktop Manager

### HDM · Linux 无显示器远程桌面一键部署与管理

**GNOME 优先 · 虚拟显示 · RustDesk · 安全恢复 · 终端菜单**

[![版本](https://img.shields.io/badge/version-v0.3.4-blue)](CHANGELOG.md)
[![CI](https://github.com/nljie1103/headless-desktop-manager/actions/workflows/tests.yml/badge.svg)](https://github.com/nljie1103/headless-desktop-manager/actions/workflows/tests.yml)
[![平台](https://img.shields.io/badge/实验平台-Ubuntu%2026%20ARM64-9cf)](docs/implementation-status.md)
[![阶段](https://img.shields.io/badge/阶段-Preview-orange)](docs/testing-and-limitations.md)

**🇨🇳 简体中文（当前页面）** · [🇬🇧 English](README.en.md) · [完整开发规格书](docs/AI_DEVELOPMENT_SPEC.md)

[快速安装](#-快速安装) · [功能导航](#-功能导航) · [部署架构](#-默认部署架构) · [安全须知](#-使用前请先阅读) · [开发进度](#-开发进度)

</div>

> [!WARNING]
> **当前为 v0.3.4 Preview，不是生产环境已验证版本。** 菜单与部分安装逻辑已实现，但 GNOME 登录界面是否被 RustDesk 正确捕获、无 GPU 软件渲染、重启后无人值守访问等，尚未在真实云服务器完成验收。强烈建议先建立云快照，保留 SSH 和云平台控制台。

> [!IMPORTANT]
> **Ubuntu 26 ARM64 实验说明**：GNOME 49+ 不支持 GNOME on Xorg；在 Ubuntu 26 上，HDM 不会自动写入 `WaylandEnable=false`。RustDesk 的标准 ARM64 版在 Wayland 下不保证登录界面无人值守控制。`WaylandEnable=false` 并非息屏开关，Ubuntu 26 GNOME 不可强制使用。**允许安装 ≠ 已打通无显示器远控**。请保留 SSH 和云控制台，并阅读 [Ubuntu 26 ARM64 测试指引](docs/ubuntu26-arm64.md)。

## 🌿 简洁交互 · 详细日志按需查看

**v0.3.4 起默认静默安装**：执行 APT/DNF/YUM 时不再把几千行包管理日志刷到屏幕，只提示当前任务与最终结果；失败时归类网络、磁盘、超时、镜像、依赖或权限原因，详细日志保存在 `/var/log/hdm/`（仅管理员可读）。需要完整输出时可运行 `sudo env HDM_DEBUG_INSTALL=1 hdm`。

**v0.3.4 打开 HDM 就先检测桌面与显示输出**，不会把所有机器都当成没有显示器、没有桌面；已有 GNOME/XFCE/MATE 将优先保留，未知状态不强制覆盖 GDM/Xorg。`sudo hdm --preflight` 可以独立查看结果。

**RustDesk 服务器配置采用草稿 → 预览 → 导入 → 磁盘读回校验**。`7 → 1 → 8` 只负责设备 ID 查询；`7 → 3` 读取实际配置。**配置写入一致 ≠ 服务器注册成功 ≠ GNOME 远控可用**。

## ✨ 项目可以做什么？

HDM 把无显示器 Linux 图形桌面所需的驱动、桌面环境、远控客户端、更新和恢复功能集中到一个终端菜单。不强制替换已有桌面，不会默默安装实验性组件。

| 功能 | 当前进度 | 说明 |
| :--- | :---: | :--- |
| **GNOME + GDM3（新系统 Wayland）** | 🟡 代码可用，待实机 | 完整 GNOME 优先；Ubuntu 26 改为 Wayland-only；XFCE/MATE 可选 |
| **Xorg Dummy 虚拟显示** | 🟡 代码可用，待实机 | 分辨率预设、文件备份和回滚 |
| Xvfb / VKMS | 🧪 实验 | Xvfb 可配置编号、分辨率、色深；VKMS 检查内核 |
| RustDesk 客户端 | 🟡 代码可用，待实机 | 安装 / 版本选择 / 本地安装 / 自建服务器 |
| **菜单系统 / 环境检测** | ✅ 本地验证 | 10 个主菜单、475 个条目（保留旧 473 项），首次打开检测桌面及显示输出，未实现项明确提示 |
| **一键安装断点续装** | ✅ 逻辑测试通过，待实机 | 每步进度、状态复查、失败重试和并发锁 |
| **GNOME 中文故障诊断** | ✅ 规则测试通过，待实机 | `hdm --doctor` / `hdm --doctor-json`，不读取密码 |
| 下载源与校验 | 🟡 部分实现 | 系统 APT 优先，网络故障时使用官方备用源 |
| 配置备份与回滚 | 🟡 部分实现 | Xorg/GDM 变更采用配置快照及恢复计时器 |

状态说明：✅ 本地自动化检查通过；🟡 具备实现但未通过云服务器功能验收；🧪 仅供实验，不保证兼容。

## 🚀 快速安装

### 1. 准备服务器

测试阶段**不再限制 Linux 发行版版本或 CPU 架构**；Ubuntu 26.04/26.10 ARM64 可以进入菜单并尝试安装。建议准备云控制台、可用 SSH、系统快照、足够磁盘空间和内存（完整 GNOME 对资源要求较高）。

### 2. 下载安装器

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

> 该命令使用可变的 `main` 开发分支。建议阅读下载的 `install.sh`；正式稳定版本应使用固定 Release 和经过独立核验的 SHA-256/签名。首次安装 HDM **不会直接安装 GNOME 或 RustDesk**。

### 3. 打开 HDM（首先自动检测已有桌面和显示输出）

```bash
sudo hdm
```

推荐进入 **`9 → 9.1`** 查看自动安装向导：Ubuntu 24.04 走 GNOME X11 / Xorg Dummy；Ubuntu 26.04/26.10 则采用 GNOME Wayland + PipeWire/Portal + RustDesk，不再强行禁用 Wayland。菜单仍会对危险的 Linux 系统更改单独确认，避免远程失联。

```text
╭──────────────────────────────────────────────────────────╮
│       Headless Desktop Manager (HDM) · v0.3.4           │
│  虚拟显示器  /  GNOME 桌面  /  RustDesk 远程管理         │
├──────────────────────────────────────────────────────────┤
│  1  安装虚拟显示器         6  更新 RustDesk             │
│  2  管理虚拟显示器         7  配置 ID / 中继服务器       │
│  3  安装桌面环境           8  更新 HDM 管理器           │
│  4  管理桌面环境           9  ⭐ 一键安装推荐组合       │
│  5  安装 RustDesk         10  系统检测 / 故障修复       │
│                                                          │
│  0  返回/退出              q  退出程序                   │
╰──────────────────────────────────────────────────────────╯
```

*上图为 README 的排版示意，终端实际界面由 `ui/menu.sh` 生成。*

### 推荐：先检测，再安装，出错可续装

```bash
sudo hdm --preflight      # 只读：先检测已有桌面/显示输出/图形会话
sudo hdm --doctor         # 只读：中文问题定位和具体菜单建议
sudo hdm --rustdesk-permissions  # 只读：安全/网络设置灰色的权限诊断
sudo hdm --quick-status   # 只读：一键安装各阶段记录与当前实际状态
sudo hdm --quick-resume   # 安全确认后只安装缺失/失败步骤
```

安装进度保存于 `/var/lib/hdm/quick-install-state.tsv`，**不能把进度账本等同于实机验证**。GNOME 画面、RustDesk 认证和重启恢复仍需要使用另一台电脑测试。详细说明：[断点续装与状态设计](docs/resumable-install.md)。

### 四种安装环境

| 桌面已安装 | 显示输出已连接 | 默认策略 |
|---|---|---|
| 是 | 是 | 保留桌面与显示配置，检查 RustDesk |
| 是 | 否 | 保留桌面，先判断是否有兼容的虚拟输出 |
| 否 | 是 | 安装 GNOME，复用输出 |
| 否 | 否 | 安装 GNOME，再验证虚拟显示和远程捕获 |

**显示输出未知时不自动更改 Xorg/GDM。** `connected` 可能来自软件虚拟输出或 Dummy 插头，不等于真的有物理显示器。详见 [环境检测与息屏说明](docs/environment-detection.md)。

## 🔄 在线更新：正式 Release 与 main 预览版

HDM 可以分别检查正式 Release 与 `main` 开发预览版。你可以在服务器上运行：

```bash
sudo hdm --check-update       # 只读，查询正式 Release 和 main 的版本
sudo hdm --update-preview    # 实验环境：从固定 main Git 提交更新管理器
```

菜单入口：**`8 → 1 → 1` 检查更新，`8 → 2 → 5` 更新 main 预览版**。只更新 HDM 管理器自身，不重装 GNOME 或 RustDesk。旧版本保留以供菜单 `8 → 5` 回滚。下载和切换过程中会检查路径安全、版本号、自检结果，拒绝同版本覆盖。

稳定版 Release 安装使用 GitHub API SHA-256 校验；如果本机显式配置了独立可信哈希文件，则必须匹配。**main 预览代码和 GitHub API 摘要均不是独立的发布者签名**，仅适合目前的测试阶段。

## 🧭 功能导航

| 模块 | 安装 | 更新 / 管理 | 关键子功能 |
| --- | --- | --- | --- |
| 显示器 | `1` | `2` | Xorg Dummy / Xvfb / VKMS、分辨率、配置恢复 |
| 桌面 | `3` | `4` | GNOME（默认）、XFCE、MATE、GDM3、X11 |
| RustDesk | `5` | `6` | 官方版本、本地安装包、检查更新、卸载 |
| 服务器 | `7` | — | ID、Relay、公钥、设备 ID、无人值守密码、权限诊断 `7 → 12` |
| 管理器 | — | `8` | Release / main 更新、下载校验、回滚 |
| 一键向导 | `9` | — | GNOME + Dummy + RustDesk 推荐组合 |
| 故障恢复 | — | `10` | 诊断、日志、系统服务、软件源、配置快照 |

所有二三级菜单保留于 [`docs/menu-guide.md`](docs/menu-guide.md)；开发者必须以 [`docs/AI_DEVELOPMENT_SPEC.md`](docs/AI_DEVELOPMENT_SPEC.md) 为完整菜单依据。**菜单存在不等于功能已通过实机测试**。

## 🧩 默认部署架构

```mermaid
flowchart TD
  A[远程电脑 RustDesk] <-->|ID / Relay / P2P| B[RustDesk ID/Relay 服务器]
  B <-->|认证及连接| D
  subgraph VM[Ubuntu 24.04 云服务器]
    D[RustDesk 受控端服务]
    E[GNOME Shell + GDM3 · X11]
    F[Xorg Dummy 虚拟显示设备]
    D --- E
    E --- F
  end
  H[HDM 终端管理器] -->|安装 / 检测 / 恢复| C
```

> 实际连接可能使用 P2P 或中继；HDM 不保证所有云服务器上的图形捕获成功。Xvfb/VKMS 不会自动代替上述默认组合。

## 📦 软件获取原则

```text
发行版自带 APT / DNF / YUM（首选，当前写入仅实现 Ubuntu APT）
    └── 下载源网络故障 → 可信发行版镜像（不绕过签名）
          └── 适用时 → RustDesk 官方 Releases
                └── 适用且已有实际文件时 → HDM GitHub Releases 备用包
```

- **GNOME** 有大量系统依赖，不适合靠 GitHub 散装 `.deb` 来代替完整 APT 仓库。
- RustDesk 备用包必须真实上传，并有可信 SHA-256/许可证信息；项目当前**未提供**可用的 GitHub `.deb` 镜像。
- GPG 签名错误、架构不匹配、依赖冲突等必须停止，不能通过“更换下载源”绕过。

## 🛡️ 使用前请先阅读

1. **保留 SSH 和云服务器救援控制台**；在修改 Xorg/GDM3 前创建云端系统快照。
2. HDM 不自动关闭防火墙、不允许无提示自动登录、不关闭默认屏幕锁定，也不会在安装结束时强制重启。
3. 显示相关高风险变更会备份配置并启动自动恢复计时器。远端图形确认无误后，执行 `sudo hdm --confirm-display`，否则约 7 分钟后可能恢复旧配置。
4. RustDesk `--password` 命令行传参可能短暂暴露在同机进程列表中；菜单会明示风险。HDM 不保存明文访问密码。
5. **真正安装成功**必须经过从另一台设备的图形连接、鼠标键盘、重启后的无人值守回归测试；本地静态测试不代表通过这些验收。

## 🛠️ 常用命令

```bash
sudo hdm                   # 打开终端菜单
hdm --version              # 查看版本
hdm --menu-tree            # 查看全部子菜单
sudo hdm --diagnose        # 只读诊断
hdm --status-json          # 机器可读 JSON 诊断
sudo hdm --doctor          # 中文诊断结果与菜单建议
hdm --doctor-json          # 结构化检查项与故障建议
sudo hdm --quick-status    # 查询安装进度与当前状态
sudo hdm --quick-resume    # 确认后续装缺失步骤
sudo hdm --confirm-display # 确认显示配置生效，取消回滚
sudo hdm --rollback-pending # 手动恢复待回滚配置
```

## 🧑‍💻 开发与贡献

- **源码规范与 AI 交接**：[`docs/AI_DEVELOPMENT_SPEC.md`](docs/AI_DEVELOPMENT_SPEC.md)
- **当前实现与限制**：[`docs/implementation-status.md`](docs/implementation-status.md)
- **开发手册**：[`docs/development.md`](docs/development.md)
- **安装和故障排查**：[`docs/installation.md`](docs/installation.md) · [`docs/troubleshooting.md`](docs/troubleshooting.md)
- **GitHub 地址与更新策略**：[`docs/repository-endpoints.md`](docs/repository-endpoints.md)
- **提交规范**：[`docs/COMMIT_POLICY.md`](docs/COMMIT_POLICY.md) — `v版本号 + 真实变更描述`

本地测试（不会改动运行机的显示器或桌面配置）：

```bash
bash tests/run.sh
```

## 🗺️ 开发进度

- [x] v0.3.5 — 发布页提供实际更新内容，版本标题和正文分离

- [x] v0.1.x — 模块化工程、完整菜单树、基础安装与诊断、初版发布脚本
- [x] v0.2.0 — 中文首页、英文次级文档、Xvfb 配置完善及增强测试
- [x] v0.3.4 — 增加在线更新检查、预览版升级与管理器回滚，保留原有桌面与远控软件
- [x] v0.3.0 — 一键安装断点续装、GNOME 只读诊断、RustDesk 端点校验与更安全的配置操作
- [ ] 云服务器实机：GNOME/GDM3/Xorg Dummy/RustDesk 画面捕获和无人值守验证
- [ ] 完整官方/自建 ID/Relay 服务器端到端测试与版本兼容性矩阵
- [ ] 更多发行版、CPU 架构、备用安装包的可重复签名构建

---

<div align="center">

由社区维护的开放项目 · [Issues](https://github.com/nljie1103/headless-desktop-manager/issues) · [Releases](https://github.com/nljie1103/headless-desktop-manager/releases) · [LICENSE](LICENSE)

*RustDesk 属于其上游独立项目，HDM 与 RustDesk 官方无隶属关系。*

</div>
