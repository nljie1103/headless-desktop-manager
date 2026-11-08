# 功能实现与兼容性状态 · HDM v4.1.0

本表是**功能实现状态**，不将菜单入口、已安装包或服务 active 当作真实远程画面测试通过。

| 模块 | 已实现 / 验证 | 尚需实际验收 |
|:---|:---|:---|
| 安装器与管理器升级 | 分版本安装、自动菜单、更新与回滚；已完成 Ubuntu 24.04 x86_64 测试与 GitHub 发布流程 | 不同云商与 CPU 架构 |
| 终端菜单 | 10 个主入口、481 个总菜单项（以结构校验输出为准）；v4 改为统一紧凑双列/单列布局 | 其他终端字体及极窄终端 |
| 安装前检测 | 桌面包、DRM 状态、X11/Wayland 及单独 GNOME 用户会话检测 | DRM 实际可用图像和多用户场景 |
| Xorg Dummy | 安装、配置、快照、回滚逻辑 | 实机 GNOME X11 与 RustDesk 外部画面 |
| Xvfb / VKMS | 参数检查、服务配置与内核能力探测 | 与 GNOME/RustDesk 端到端协同 |
| GNOME/GDM3 | Ubuntu 24.04 x86_64 Box 上 GNOME 核心包安装、GDM3 服务启动验证；可区分 XFCE 与 GNOME 会话 | GNOME 实际登录与远程输入 |
| RustDesk | Ubuntu 24.04 x86_64 官方 RustDesk 1.5.1 经校验下载、依赖、安装、服务 active；双作用域配置和权限测试 | 远端认证、登录前捕获和锁屏恢复 |
| Ubuntu 26 ARM64 | Ubuntu 26.04 ARM64 曾完成 GNOME/GDM3/RustDesk 安装与异常定位；代码有 Wayland 安全分支 | GNOME Wayland 无屏幕、登录前与无人值守 |
| 诊断与日志 | `--preflight`、`--readiness`、`--doctor`、系统日志归档、常见权限异常处理 | 多平台现场故障样本 |

## 系统支持范围

开发与测试以 Ubuntu 24.04 x86_64 为主；Ubuntu 26.04 ARM64 是已遇到实际 GNOME Wayland 显示与远控限制的目标平台。仓库目前列出了 10 条 Ubuntu 组合的测试/实现路径，但 **0 条完整通过登录前无屏远控验收**。

请以 [完整兼容矩阵](testing-and-limitations.md)、[Ubuntu 26 ARM64 适配说明](ubuntu26-arm64.md) 与 [主 README](../README.md) 为准。

## v4.1.0 桌面推荐策略

Ubuntu 26 GNOME Wayland-only 主机默认建议 XFCE + X11 + LightDM；已有 GNOME 保留并可选择继续使用。推荐计划可以在无 DRM 连接时包含 Xorg Dummy，但所有影响显示服务的配置须经用户确认，且本项目尚无 Ubuntu 26 ARM64 登录前 RustDesk 成功验收记录。

## v4.2.0 桌面链路可视化

主菜单增加七节点本地状态检测图；显示/协议/桌面/会话/服务/ID 的状态分离，路径与版本可通过 `sudo hdm --chain` 查看。节点为绿色仅代表本地对应检查满足，真实 RustDesk 图像、认证和重启远控仍需外部设备验收。参见 [桌面链路指南](desktop-chain.md)。

## v4.3.0 菜单重构

采用七节点 + HDM 管理的八个主入口，578 个导航项目、426 个可选择叶子（含重复功能快捷入口），通过显式映射保留全部 381 个旧动作。新增 GDM3/LightDM 安装、模拟卸载和更新入口，以及只解除 HDM 启动命令及当前版本链接、保留系统配置及历史版本的卸载流程。该数据是代码和导航覆盖，并非 426 项功能全部已在真实服务器完成验收；详情见 [菜单指南](menu-guide.md)。
