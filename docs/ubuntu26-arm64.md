# Ubuntu 26.04 / 26.10 ARM64 · GNOME Wayland 适配说明

> 目标：在无实体显示器的 Ubuntu ARM64 主机上，按实际图形协议部署可用的桌面与 RustDesk；GNOME、XFCE、MATE 均可选。本页区分安装成功、图形会话、锁屏、登录前控制和冷启动无人值守；其中任何一项都不能由另一项推断成功。

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

**当需要标准 RustDesk 的 X11 登录界面时，HDM 推荐 XFCE + LightDM + Xorg；不是把 XFCE 伪装成 GNOME，也不承诺其已经通过 ARM64 登录前无人值守实测。GNOME 保留供用户选择。**

## 3. 推荐的可选方案：XFCE + X11 + LightDM

Ubuntu 26 移除的是 **GNOME Xorg 会话**，并没有取消系统层面的 Xorg。XFCE 和 MATE 仍提供 X11 选项，LightDM 可以作为独立登录管理器。HDM 在未安装桌面，或仅有 GNOME Wayland 的主机上，优先生成 XFCE 安装计划；支持 Xorg、LightDM、GTK Greeter 和 RustDesk 依赖的安装。

对于检测到的未连接 DRM 输出，计划可能包括 Xorg Dummy；该配置有断开当前远程显示的风险，须先准备独立的 SSH/云控制台，并由用户确认。安装 XFCE 和 LightDM 不代表 GDM3 已自动替换；HDM 不擅自卸载 GNOME、启用自动登录或重启显示服务。可在菜单 `4 → 4.4` 查看默认登录管理器与手动切换说明。

此方案属于**可操作的 X11 部署路径**，但其登录界面 RustDesk 捕获、锁屏、无人值守和冷启动恢复依然需要逐项实机验证。

## 4. 2026-11-07 ARM64 实测记录

- 测试环境：Ubuntu 26.04 / aarch64；GNOME 50.1、GDM3、RustDesk 1.5.1 曾确认已安装。
- RustDesk 服务曾显示 active，GDM3 也曾显示 active；但真实已登录 GNOME 图形用户会话为 none / unknown，不能证明登录界面或桌面可捕获。
- 诊断中出现过 `cannot open display: :0`。这提示 RustDesk 无法打开目标显示，不等于 RustDesk ID / 中继配置必然有错。
- 曾安装 Xorg Dummy、配置 1920×1080 并使用 HDM 的快照与定时回滚。这不能让 GNOME 50 恢复已移除的 Xorg 登录会话。
- **未获得证据证明**锁屏、注销或冷启动后可经 RustDesk 操作 GNOME 登录界面。请勿从安装日志推断这些能力已完成。

## 5. 安全测试顺序

1. 在云服务商处准备可恢复快照，保持 SSH 与独立控制台通道，先不要变更全局显示管理器配置。
2. 运行 `hdm --preflight`、`hdm --readiness` 和 `hdm --doctor`，分开确认系统包、GDM3、DRM、GNOME 用户会话及 RustDesk 服务。
3. 如需启用 VKMS，检查实际内核模块及 DRM 输出，再验证 GDM3 是否创建了相应桌面会话；不要假定模块加载后自动可远控。
4. 在另一台电脑使用 RustDesk 连接，先测试已登录 GNOME 的图像、鼠标和键盘，再分别测试屏幕锁定、恢复连接与解锁。
5. 最后才进行注销、重启后登录前及无人值守测试。没有独立救援通道时，不应尝试可能断开唯一远程连接的操作。
6. 若连接失败，导出 `sudo hdm --export-diagnostics`，检查图形用户会话、RustDesk 日志与 Portal/PipeWire 状态；分享前审查敏感信息。

## 6. 参考资料

- [Ubuntu 26.04 官方发行说明：Wayland session](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/)
- [GNOME 49 开发者发行说明：X11 Session disabled](https://release.gnome.org/49/developers/)
- [RustDesk Linux：Wayland 与登录界面限制](https://rustdesk.com/docs/en/client/linux/)
- [RustDesk：Wayland Unattended Preview (x86_64)](https://rustdesk.com/blog/unattended-remote-access-wayland/)
- [HDM 兼容测试矩阵](testing-and-limitations.md) · [返回项目首页](../README.md)

## v4.3.1 迁移菜单

系统已经实现实际卸载路径：在菜单 4 安装 XFCE，菜单 `2 → 切换默认登录管理器` 运行交互式 `dpkg-reconfigure lightdm`，再通过独立 SSH/云控制台安排重启、验证 XFCE/X11/LightDM 以及 RustDesk。只有新登录管理器已成为默认并且真正运行，才能从菜单 `2 → 卸载` 删除 GDM3，最后从菜单 `4 → 卸载与预览` 删除 GNOME。APT 会先模拟整个依赖删除集合，意外涉及 Xorg、RustDesk 或替代桌面则拒绝执行。
