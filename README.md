<div align="center">

# 🖥️ Headless Desktop Manager

**Linux 无显示器远程桌面部署与图形会话管理。**

统一管理 GNOME、XFCE、MATE、虚拟显示、RustDesk 和图形会话，
根据设备实际环境补齐组件，并提供状态检查与故障诊断。

[![Linux](https://img.shields.io/badge/Platform-Linux-2f81f7?style=for-the-badge&logo=linux)](docs/installation.md)
[![Shell](https://img.shields.io/badge/CLI-Bash-4eaa25?style=for-the-badge&logo=gnubash)](hdm.sh)
[![License](https://img.shields.io/badge/License-MIT-6aa84f?style=for-the-badge)](LICENSE)

**简体中文** · [English](README.en.md) · [版本记录](CHANGELOG.md) · [发布页面](https://github.com/nljie1103/headless-desktop-manager/releases)

</div>

---

## ✨ 功能特性

| 功能 | 说明 |
|:---|:---|
| 🖥️ **桌面环境** | 安装及管理 GNOME、XFCE、MATE，优先保留已存在的桌面 |
| 🪟 **虚拟显示** | 检测和管理 Xorg Dummy、Xvfb、VKMS，按当前显示协议选择 |
| 🔗 **RustDesk** | 安装客户端，设置 ID / 中继服务器、查看完整公钥、管理访问权限 |
| 🩺 **部署检查** | 展示需要安装的软件、已安装组件、待配置事项和运行状态 |
| 🔄 **更新与回滚** | 更新 HDM 管理器并保留可恢复的旧版本 |
| 📦 **完整诊断** | 收集 HDM 操作日志、系统服务和软件包记录，导出故障诊断包 |

---

## 📥 快速开始

通过 SSH 登录目标 Linux 主机，使用具有 `sudo` 权限的账户执行：

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

安装完成后将自动打开交互菜单。后续进入：

```bash
sudo hdm
```

安装器从 GitHub `main` 获取当前项目内容；需要固定版本时，使用 [Releases](https://github.com/nljie1103/headless-desktop-manager/releases) 中的对应归档及校验文件。**通过 SSH 调整显示服务之前，请确保云平台控制台或其他恢复通道可用。**

---

## 🧭 菜单与部署检查

```text
HDM · Linux 图形桌面管理

1  安装虚拟显示器     6   更新 RustDesk
2  管理虚拟显示器     7   RustDesk 配置
3  安装桌面环境       8   更新 HDM
4  管理桌面与会话     9   智能部署
5  安装 RustDesk     10  诊断与日志

0 返回   q 退出
```

*菜单为布局示例，实际状态由本机动态检测。*

开始部署前，先运行完整状态清单：

```bash
sudo hdm --readiness
```

检查结果会分开显示：桌面软件、图形登录服务、虚拟显示条件、Wayland 捕获组件、RustDesk 客户端、服务器配置和用户图形会话。针对需要安装的软件显示“待安装”，针对需要配置或启动的环节显示对应动作；已就绪项目直接跳过。**软件安装、服务启动、用户图形会话与远程画面分别验证**。

常用诊断命令：

```bash
sudo hdm --preflight           # 系统环境与显示输出
sudo hdm --session-status      # 图形会话与 GDM3 状态
sudo hdm --doctor              # 故障定位与操作建议
sudo hdm --export-diagnostics # 一键归档全部可用日志
```

在菜单 `10 → 系统体检` 中也可查看完整部署检查。诊断本身不会重启服务或修改系统。

---

## 🪟 桌面与虚拟显示方案

| 桌面 | 建议物理内存 | 主要特点 |
|:---|:---|:---|
| **GNOME** | 4 GiB 起 | 现代完整桌面，优先适用于资源充足的系统 |
| **MATE** | 2–4 GiB | 传统桌面布局、资源需求适中 |
| **XFCE** | 1–3 GiB | 轻量，适用于内存较小的主机 |

| 显示方案 | 显示协议 | 适用情形 |
|:---|:---|:---|
| **Xorg Dummy** | X11 | 为 Xorg 创建虚拟屏幕，适合受支持的 X11 桌面 |
| **Xvfb** | X11 | 独立虚拟 X server，适合应用和无屏图形任务 |
| **VKMS** | DRM/KMS | 内核虚拟图形设备；需要图形合成器和内核适配 |

内存建议是选型参考，不是实际基准测试。**Ubuntu 26 的 GNOME 使用 Wayland；Xorg Dummy 不会为 GNOME Wayland 自动创建屏幕。** HDM 根据已安装桌面、DRM 输出、图形会话和资源状况生成推荐方案；必要时可逐项操作。

---

## 🔐 RustDesk 配置与访问权限

在菜单 `7` 中管理自建 ID 服务器、中继服务器和服务器公钥，并读取保存的配置进行核对；支持**自定义、完全访问、仅共享屏幕**三种访问模式及远程配置修改权限。

服务器地址、Relay 地址及公钥可完整预览，便于复制校验；无人值守密码不记录进 HDM 日志。系统通过 RustDesk 服务账户和配置文件状态检查本地应用情况。

---

## 🩺 故障诊断与日志

正常安装过程保持简洁，完整 APT 输出和步骤执行记录单独保存。需要分析故障时：

```bash
sudo hdm --export-diagnostics
```

诊断包包含当前仍然保留的安装操作记录、APT/dpkg 日志、GDM3 与 RustDesk 系统日志及会话状态。输出文件默认存储在 `/var/lib/hdm/exports/`。归档会执行尽力脱敏；向他人或 AI 分享前仍应检查服务器地址与敏感信息。

当 GNOME 软件已安装但 GDM3 未运行、或 RustDesk 报告无法打开 `DISPLAY` 时，可运行：

```bash
sudo hdm --session-status
sudo hdm --session-start
```

这些命令会分别检查及启动图形登录服务。是否能远程捕获画面仍取决于实际图形用户会话、显示输出和 RustDesk 的会话授权。

---

## 🏗️ 项目结构

```text
headless-desktop-manager/
├── core/            # 安装、配置、备份与下载
├── modules/         # 显示、桌面、RustDesk 与诊断
├── ui/              # 菜单定义和操作路由
├── scripts/         # 配置验证与辅助命令
├── tests/           # 自动化测试
├── docs/            # 操作说明与技术资料
└── install.sh       # 安装入口
```

本地验证：

```bash
bash tests/run.sh
```

[安装说明](docs/installation.md) · [菜单导航](docs/menu-guide.md) · [虚拟显示说明](docs/display-guide.md) · [RustDesk 配置](docs/rustdesk-guide.md) · [安全策略](SECURITY.md)

---

## 📄 开源许可

本项目采用 [MIT License](LICENSE)。

<div align="center">

由 [nljie1103](https://github.com/nljie1103) 维护 · 欢迎通过 Issues 提交改进建议

</div>
