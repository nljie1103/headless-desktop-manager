# Ubuntu 26.04 / 26.10 ARM64 · GNOME Wayland 适配说明

> 目标：在无实体显示器的 Ubuntu ARM64 主机上，使用 **GNOME + RustDesk**。本页区分安装成功、图形会话、锁屏、登录前控制和冷启动无人值守；其中任何一项都不能由另一项推断成功。

## 1. GNOME 50 与 Xorg 的边界

从 Ubuntu 25.10 开始，Ubuntu GNOME 桌面使用 **Wayland-only**，Ubuntu 26.04 LTS 提供 GNOME 50。

- GNOME 的 Xorg 登录会话已不再可用；XWayland 是为了兼容 X11 应用程序，不是 GNOME Xorg 桌面。
- **不要设置 `WaylandEnable=false` 强迫 GDM3/ GNOME 切换到 Xorg。** 这个旧方案不适用于该 GNOME，可能使登录更加困难。
- Xorg Dummy 虽可安装，但只为 X11 提供显示，不会自动供 GNOME Wayland 使用；Xvfb 同理。
- VKMS 可以提供内核 DRM/KMS 虚拟显示能力，但仅发现模块、加载成功或出现 DRM 节点，不足以证明 GDM3、GNOME Shell 和 RustDesk 已可以使用该输出。

## 2. RustDesk：已登录、锁屏、登录前必须分开验证

| 状态 | 标准 RustDesk / GNOME Wayland | HDM 的结论 |
|:---|:---|:---|
| 用户已登录、桌面未锁定 | 依赖 PipeWire、Desktop Portal 和会话授权，可尝试捕获 | 本项目尚无 Ubuntu 26 ARM64 端到端成功证据 |
| 用户桌面已锁屏 | 与注销不同；行为依桌面、授权和客户端而定 | 必须单独测试锁屏、重连和解锁后的输入恢复 |
| 用户注销、停在 GDM 登录界面 | 标准 RustDesk 的 Wayland 登录前捕获不受已登录支持保证 | 不将服务运行认定为能远程登录 |
| 重启后尚未登录 | 与登录前同属高风险未验证场景 | 尚未完成无人值守验收 |

RustDesk 官方的 **Wayland 无人值守预览版** 已介绍登录界面访问，但目前主要针对 **Debian / Ubuntu x86_64**。不能据此认为 Ubuntu 26 ARM64 标准版 RustDesk 1.5.1 已提供同等能力；本项目也没有自动切换该预览版。

**用户目标仍是 GNOME + RustDesk；不能为了绕过限制把 XFCE、RDP 或 Xorg 当作 GNOME 兼容替代品。**

## 3. 2026-11-07 ARM64 实测记录

- 测试环境：Ubuntu 26.04 / aarch64；GNOME 50.1、GDM3、RustDesk 1.5.1 曾确认已安装。
- RustDesk 服务曾显示 active，GDM3 也曾显示 active；但真实已登录 GNOME 图形用户会话为 none / unknown，不能证明登录界面或桌面可捕获。
- 诊断中出现过 `cannot open display: :0`。这提示 RustDesk 无法打开目标显示，不等于 RustDesk ID / 中继配置必然有错。
- 曾安装 Xorg Dummy、配置 1920×1080 并使用 HDM 的快照与定时回滚。这不能让 GNOME 50 恢复已移除的 Xorg 登录会话。
- **未获得证据证明**锁屏、注销或冷启动后可经 RustDesk 操作 GNOME 登录界面。请勿从安装日志推断这些能力已完成。

## 4. 安全测试顺序

1. 在云服务商处准备可恢复快照，保持 SSH 与独立控制台通道，先不要变更全局显示管理器配置。
2. 运行 `hdm --preflight`、`hdm --readiness` 和 `hdm --doctor`，分开确认系统包、GDM3、DRM、GNOME 用户会话及 RustDesk 服务。
3. 如需启用 VKMS，检查实际内核模块及 DRM 输出，再验证 GDM3 是否创建了相应桌面会话；不要假定模块加载后自动可远控。
4. 在另一台电脑使用 RustDesk 连接，先测试已登录 GNOME 的图像、鼠标和键盘，再分别测试屏幕锁定、恢复连接与解锁。
5. 最后才进行注销、重启后登录前及无人值守测试。没有独立救援通道时，不应尝试可能断开唯一远程连接的操作。
6. 若连接失败，导出 `sudo hdm --export-diagnostics`，检查图形用户会话、RustDesk 日志与 Portal/PipeWire 状态；分享前审查敏感信息。

## 5. 参考资料

- [Ubuntu 26.04 官方发行说明：Wayland session](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/)
- [GNOME 49 开发者发行说明：X11 Session disabled](https://release.gnome.org/49/developers/)
- [RustDesk Linux：Wayland 与登录界面限制](https://rustdesk.com/docs/en/client/linux/)
- [RustDesk：Wayland Unattended Preview (x86_64)](https://rustdesk.com/blog/unattended-remote-access-wayland/)
- [HDM 兼容测试矩阵](testing-and-limitations.md) · [返回项目首页](../README.md)
