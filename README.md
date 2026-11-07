<div align="center">

# 🖥️ Headless Desktop Manager

**Linux 无显示器远程桌面 · 虚拟显示 · RustDesk 统一管理**

[![版本](https://img.shields.io/badge/version-v0.3.7-2f81f7)](CHANGELOG.md)
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
  HDM 0.3.7 · ubuntu 26.04 aarch64
  桌面 GNOME · 显示 已连接 · 会话 unknown · RustDesk 1.5.1

  1  安装虚拟显示             6  更新 RustDesk
  2  管理虚拟显示             7  服务器配置
  3  安装桌面                 8  更新 HDM
  4  管理桌面                 9  一键安装
  5  安装 RustDesk          10  故障诊断

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

RustDesk 的 ID 服务器、中继服务器和**公钥完整显示**，以便输入前后核对；系统密码仍采取隐藏输入。配置保存在受权限保护的文件中，完成写入后会进行读回校验。**文件保存成功、设备注册成功、远程桌面可用，是三个不同的判断。**

## 兼容与安全

- Ubuntu 26 的 GNOME 使用 Wayland；`WaylandEnable=false` 不是息屏开关，不能在不支持 GNOME Xorg 的系统上强行开启 X11。
- Xorg Dummy、Xvfb 与 VKMS 的选择取决于发行版、桌面会话和内核能力，不保证所有组合都能直接实现无显示器远控。
- 远程修改显示配置前请保留 SSH 和云控制台，必要时建立快照；HDM 的配置快照与自动恢复功能不替代云服务商的系统恢复能力。
- RustDesk 的后台服务启动和设备 ID 可用不代表已经存在图形画面。Ubuntu 26 ARM64 的 GNOME Wayland 登录前无人值守连接仍需要实机验证。

## 开发与维护

源码结构：`core/` 提供包管理、备份和下载，`modules/` 包含显示、桌面、RustDesk 和更新实现，`ui/` 提供菜单数据及交互层，`tests/` 保存自动化检查。

```bash
bash tests/run.sh
```

[安装说明](docs/installation.md) · [菜单指南](docs/menu-guide.md) · [系统兼容性](docs/implementation-status.md) · [提交与发布规范](docs/COMMIT_POLICY.md) · [安全策略](SECURITY.md)

项目仓库：<https://github.com/nljie1103/headless-desktop-manager>
