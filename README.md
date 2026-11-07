<div align="center">

# 🖥️ Headless Desktop Manager

**Linux 无显示器远程桌面 · 虚拟显示 · RustDesk 统一管理**

[![版本](https://img.shields.io/badge/version-v0.3.9-2f81f7)](CHANGELOG.md)
[![CI](https://github.com/nljie1103/headless-desktop-manager/actions/workflows/tests.yml/badge.svg)](https://github.com/nljie1103/headless-desktop-manager/actions/workflows/tests.yml)
[![许可](https://img.shields.io/badge/license-MIT-6aa84f)](LICENSE)

**简体中文** · [English](README.en.md) · [功能文档](docs/menu-guide.md) · [版本记录](CHANGELOG.md)

</div>

---

HDM 是一套运行在 Linux 终端的桌面环境管理工具，提供 GNOME、XFCE、MATE、虚拟显示器、RustDesk 客户端及自建服务器配置、在线更新和故障诊断。**优先保留设备已有的桌面与显示配置，只补齐所需组件。**

## 快速安装

通过 SSH 或本地终端执行：

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

安装完成会在**交互式终端**自动打开 HDM。再次打开：

```bash
sudo hdm
```

从脚本或非交互环境安装时，不会自动进入菜单。若需跳过自动打开，可使用 `sudo HDM_NO_AUTO_MENU=1 bash hdm-install.sh`。下载自 GitHub `main` 的源码会随仓库变化；正式固定部署可使用带 SHA-256 固定校验的归档。安装 HDM 本体不会自动改写图形配置，具体修改仍由菜单操作触发。

## 简洁的终端菜单

```text
  HDM 0.3.9 · ubuntu 26.04 aarch64
  桌面 GNOME · DRM 已连接 · GDM inactive · 会话 未建立
  RustDesk 1.5.1（服务 active）

  1  安装虚拟显示器         6  更新 RustDesk
  2  管理显示与分辨率       7  RustDesk 连接配置
  3  安装桌面环境           8  更新 HDM 管理器
  4  管理桌面与会话         9  智能安装与续装
  5  安装 RustDesk         10  系统诊断与日志

  0 返回    q 退出
  请选择：
```

*上图为示意，状态来自本机探测；终端较窄时改为单列。*

HDM 启动时读取桌面安装状态、DRM 输出连接和 X11/Wayland 会话信息。**DRM 输出显示“已连接”不等于 GNOME 图形会话已经启动**；也不等于 RustDesk 已有可远程控制的画面。

## 常用功能

| 功能 | 使用方式 |
|---|---|
| 安装 / 管理虚拟显示器 | 菜单 `1` / `2`，支持 Xorg Dummy、Xvfb、VKMS |
| 安装 / 管理桌面 | 菜单 `3` / `4`，GNOME 优先，XFCE/MATE 可选 |
| 安装 / 更新 RustDesk | 菜单 `5` / `6` |
| 自建 ID/中继服务器 | 菜单 `7 → 1`：填写、预览、保存、读回验证、查询设备 ID |
| HDM 在线更新 | 菜单 `8`；`sudo hdm --check-update` 与 `sudo hdm --update-main` |
| 缺失组件安装 / 续装 | 菜单 `9`；`sudo hdm --quick-status` 与 `sudo hdm --quick-resume` |
| 健康诊断 | 菜单 `10`；`sudo hdm --doctor` / `sudo hdm --preflight` |
| 图形会话修复 | 菜单 `4 → 管理图形会话`；`sudo hdm --session-start` |
| 一键导出完整诊断包 | 菜单 `10 → 日志查看`；`sudo hdm --export-diagnostics` |

RustDesk 的 ID 服务器、中继服务器和**公钥完整显示**，以便输入前后核对；永久密码在终端中可见（按操作者要求），请使用可信终端输入，且不会写入 HDM 日志。配置保存在受权限保护的文件中，完成写入后会进行读回校验。**文件保存成功、设备注册成功、远程桌面可用，是三个不同的判断。**


## 图形会话故障排查与日志归档

GNOME **软件包已安装**、DRM 接口**显示已连接**、GDM3 **服务正在运行**、系统存在**已登录的图形用户会话**以及 RustDesk **成功显示画面**是五项不同的检查；只有最后一项需要另一台设备实际连接才能验证。Ubuntu 26 GNOME Wayland 不应强制配置 `WaylandEnable=false`。

```bash
sudo hdm --session-status       # 只读检查 GDM3、图形用户会话与 DRM
sudo hdm --session-start        # 尝试启动 GDM3 并检查实际状态
sudo hdm --session-repair       # 依据 DRM/VKMS 能力逐步排查缺失的图形会话
sudo hdm --export-diagnostics  # 一键导出保留的安装日志和系统诊断档案
```

其中 `--session-repair` 仅在内核确实提供 VKMS、设备确实没有连接输出时才尝试临时加载 VKMS，不会开启自动登录或强制改成 X11。云服务器没有适配的 DRM/KMS 时，脚本会给出明确阻断原因，而不是报告“修复成功”。菜单 `4 → 管理图形会话` 可执行会话检查、服务启动和默认图形启动目标管理。

**安装过程默认简洁，详细记录持续保留。** HDM 将 APT 等原始输出保存到 `/var/log/hdm/operation-*.log`；每个已执行菜单动作的结果记录到 `/var/log/hdm/steps.log`。菜单 `10 → 日志查看 → 一键导出完整诊断包` 将这些记录与仍存在的 APT/dpkg/GDM3/RustDesk 日志汇总成一个受限权限的 `.tar.gz` 文件，适合排障。导出会尝试隐去密钥和密码，但分享给其他人或 AI 前仍须检查其中的服务器地址和其他敏感数据。

RustDesk 的 Linux `.deb` 安装会在正式安装之前使用 APT 模拟解析依赖；APT 会从系统签名软件源补齐缺包，不使用不受验证的强行修复命令。若只有 `Failed to stop rustdesk.service: Unit rustdesk.service not loaded` 而随后正常完成安装，这通常只是首次安装时没有可停止的旧服务，并不代表依赖缺失。

## 兼容与安全

- Ubuntu 26 的 GNOME 使用 Wayland；`WaylandEnable=false` 不是息屏开关，不能在不支持 GNOME Xorg 的系统上强行开启 X11。
- Xorg Dummy、Xvfb 与 VKMS 的选择取决于发行版、桌面会话和内核能力，不保证所有组合都能直接实现无显示器远控。
- 远程修改显示配置前请保留 SSH 和云控制台，必要时建立快照；HDM 的配置快照与自动恢复功能不替代云服务商的系统恢复能力。
- RustDesk 的后台服务启动和设备 ID 可用不代表已经存在图形画面。Ubuntu 26 ARM64 的 GNOME Wayland 登录前无人值守连接仍需要实机验证。

## 按服务器性能选择

**HDM 优先保留现有桌面**；仅在没有桌面时根据物理内存推荐：4 GiB 及以上优先 GNOME，低于 4 GiB 优先 XFCE。MATE 可以手动选择。推荐结果不等于图形会话已启动。

| 桌面 | 典型空闲内存（参考） | 推荐物理内存 | 特点 |
|---|---:|---:|---|
| GNOME | 约 1.2–2.0 GB | ≥4 GB | 完整现代桌面、Wayland，会用到软件渲染 |
| MATE | 约 0.5–0.9 GB | 2–4 GB | 传统桌面、较轻量 |
| XFCE | 约 0.4–0.8 GB | 1–3 GB | 资源占用较低、适合小型云主机 |

| 显示技术 | 典型额外内存（参考） | 适用场景 | 关键限制 |
|---|---:|---|---|
| Xorg Dummy | 约 40–200 MB | X11 虚拟显示 | **不提供 GNOME Wayland 显示** |
| Xvfb | 约 20–120 MB | 独立的 X11 虚拟屏幕 | 不等同于图形登录界面 |
| VKMS | 取决于合成器与帧缓冲 | DRM/KMS 虚拟输出 | 需要内核、合成器与会话兼容 |

以上数值是容量规划的粗略范围，不是基准测试数据；具体占用与分辨率、系统服务、图形合成和 RustDesk 编码有关。例如 1920×1080 32-bit 单帧约 8 MiB，多帧缓存和软件渲染会增加开销。**是否使用虚拟显示器还取决于 X11/Wayland、DRM 输出和图形会话状态，不能只按内存决定。**

## RustDesk 访问权限

在菜单 `7 → 13` 可以选择**自定义、完全访问、仅共享屏幕**，单独开启或关闭“允许远程修改配置”，并查看当前 root / 登录用户的权限配置。自定义模式启用常用权限，但默认关闭远程修改配置。设置永久密码时不再额外要求 12 位，也不重复要求输入；输入会直接显示在终端，请在可信终端操作。实际认证取决于 RustDesk 服务是否加载这些设置，以及图形会话是否存在。

## 开发与维护

源码结构：`core/` 提供包管理、备份和下载，`modules/` 包含显示、桌面、RustDesk 和更新实现，`ui/` 提供菜单数据及交互层，`tests/` 保存自动化检查。

```bash
bash tests/run.sh
```

[安装说明](docs/installation.md) · [菜单指南](docs/menu-guide.md) · [系统兼容性](docs/implementation-status.md) · [提交与发布规范](docs/COMMIT_POLICY.md) · [安全策略](SECURITY.md)

项目仓库：<https://github.com/nljie1103/headless-desktop-manager>
