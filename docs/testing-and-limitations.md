# HDM 功能与平台验证矩阵

此文件按 **自动化测试 / 真实软件安装 / 活动图形会话 / 外部远控** 分级，不把模拟测试等同于用户可用的远程桌面。

## 1. 系统和显示方案

当前 `config/compatibility.tsv` 有 **7 条 Ubuntu 版本、CPU 架构和 GNOME 显示方案记录**，其中有原生安装验证证据的系统系列为 Ubuntu 24.04 x86_64 和 Ubuntu 26.04 ARM64；**完整通过无屏登录前 RustDesk 端到端测试的组合为 0**。

| 系统 / 架构 | 实施情况 | 验证证据与缺口 |
|:---|:---|:---|
| Ubuntu 24.04 x86_64 · GNOME/X11 | 部分真实验证 | Box 上 GNOME 核心、GDM3、RustDesk 1.5.1 安装及服务 active；登录 GNOME、Dummy 显示和外部连接未验收 |
| Ubuntu 24.04 ARM64 · GNOME/X11 | 清单/代码 | 无 ARM64 完整安装证据 |
| Ubuntu 24.04 x86_64 · GNOME/Xvfb | 单元测试 | 虚拟 X 服务与远控联动未验收 |
| Ubuntu 24.04 x86_64 · GNOME/VKMS | 单元测试 | 内核 DRM 及 GNOME 联动未验收 |
| Ubuntu 26.04 ARM64 · GNOME Wayland | 真实安装及故障记录 | GNOME 50.1、GDM3、RustDesk 1.5.1 曾安装；登录会话未确认，出现 `cannot open display: :0` |
| Ubuntu 26.04 x86_64 · GNOME Wayland | 代码适配 | 没有目标主机完整连接结果 |
| Ubuntu 26.10 ARM64 · GNOME Wayland | 代码适配 | 没有目标主机完整连接结果 |

仓库还有 Debian / Fedora / RHEL 适配资料，以及用于不同 Ubuntu 架构的包清单。它们不等于相同级别的实机兼容认证。

## 2. 2026-11-08 双 Box 验证

- **开发机**：Ubuntu 24.04 x86_64，Bash/Python 项目测试通过，GitHub 认证、提交及发布流程已实际使用。
- **测试机**：Ubuntu 24.04 x86_64，XFCE X11 用户会话保持运行；GNOME Shell 46、GNOME Session 46、GDM3 46 核心组件实际安装成功，GDM3 服务 active；RustDesk 1.5.1 官方经校验的安装包通过 APT 依赖检查、安装后服务 active。
- `hdm --session-status` 正确识别 XFCE X11 会话不能代替 GNOME 用户会话；`hdm --doctor` 在 root 状态目录存在时可供普通用户运行，受限状态会标为“待核实”。
- 上述测试**没有**证明 GNOME 图形窗口真正建立、GDM 登录界面可被 RustDesk 捕获，或远端键鼠、锁屏、重启后登录前无人值守可用。

## 3. 自动化测试覆盖

| 范围 | 执行方式 | 不能证明 |
|:---|:---|:---|
| Shell 脚本语法 | `bash -n` | 软件包可安装 |
| ShellCheck | GitHub Actions Ubuntu 24.04 runner | 所有云商架构兼容 |
| 菜单结构与编号 | `scripts/verify-menus.py`、菜单测试 | 所有菜单端到端执行 |
| 安装、更新与恢复逻辑 | `bash tests/run.sh` 中的模拟场景 | 实机图形恢复效果 |
| RustDesk 配置与版本解析 | Mock / 测试数据 | ID 注册和外部连接 |
| GNOME/XFCE 会话区分 | Mock + Ubuntu 24.04 Box 实际日志 | Wayland GDM 登录前画面 |

本地运行：

```bash
bash tests/run.sh
```

## 4. Ubuntu 26 的锁屏与无人值守

Ubuntu 26.04 GNOME 50 采用 Wayland；Xorg Dummy 与 `WaylandEnable=false` 不能将它转换回 GNOME X11。标准 RustDesk 的 Wayland 会话捕获、锁屏访问、注销后的 GDM 登录界面与冷启动无人值守应分别验收。官方 x86_64 Wayland unattended 预览版不能当作 ARM64 可用证明。详见 [Ubuntu 26 ARM64 专项文档](ubuntu26-arm64.md)。

## 5. 验收完成的判定

对于目标系统和架构，要依次记录：包安装与依赖、systemd 服务、DRM/显示实际输出、已登录 **GNOME** 用户会话、RustDesk 外部图像、鼠标键盘、锁屏与解锁、注销、重启后 GDM 登录界面及无人值守认证。

在这些步骤全部完成并保留可重复的现场记录之前，不应宣称“支持无显示器、重启后可直接远控”已经通过对应机器的完整认证。
