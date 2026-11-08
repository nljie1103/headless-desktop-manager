# HDM 桌面链路数轴 · v4.2.0

HDM 主菜单顶部会实时展示七个状态节点：

```text
显示输出 → 登录管理器 → 图形协议 → 桌面环境 → 图形会话 → RustDesk → 设备 ID
```

**这是排障依赖检查顺序，不是严格的 systemd 启动顺序。** 图形会话由显示服务器、桌面管理器和用户登录系统共同建立；手动启动的 X11 会话甚至可以不使用 GDM3/LightDM。RustDesk 连接已经存在的会话或它受支持的登录界面，不负责为所有桌面创建用户会话。

## 组件与它们的职责

| 节点 | 典型可选实现 | 满足的本地检查 | 检测路径 / 可用操作 |
|---|---|---|---|
| **1. 显示输出** | DRM 物理输出、虚拟显示 Xorg Dummy、VKMS；Xvfb 是独立 X11 虚拟帧缓冲 | DRM 已连接，或当前匹配的 X11 DISPLAY 上 Xrandr 确认有已连接并启用的实际输出时标为通过；仅有 Dummy 配置文件时显示待核实 | `/sys/class/drm`、`/etc/X11/xorg.conf.d/20-hdm-dummy.conf`；菜单 1–2 |
| **2. 登录管理器** | GDM3、LightDM；亦可使用手动 X11 会话 | 已安装且 systemd 服务 active；不存在或异常则提示核实 | `/etc/X11/default-display-manager`；菜单 4.4 |
| **3. 图形协议** | X11（常由 Xorg 提供）、Wayland | logind 确认活动用户会话的协议，X11 还检查 X Socket | `/tmp/.X11-unix/X0`、`/run/user/*/wayland-*`；菜单 4.5 |
| **4. 桌面环境** | XFCE、GNOME、MATE、KDE | 实际活动桌面与已安装的软件包对应；仅安装不标成已运行 | `/usr/share/xsessions`、`/usr/share/wayland-sessions`；菜单 3–4 |
| **5. 图形用户会话** | logind 用户会话、X11 DISPLAY、Wayland compositor | logind 有活跃用户图形会话；实际分辨率仅由已授权的 `xrandr` 输出确认 | `loginctl`、`xrandr --current`；菜单 4.5 |
| **6. RustDesk** | RustDesk Linux 系统客户端/服务 | 包已安装且服务运行；GNOME Wayland 还核查 Portal/PipeWire 所需软件包 | `/usr/bin/rustdesk`、`systemctl status rustdesk`；菜单 5–7 |
| **7. 设备 ID** | `rustdesk --get-id` | 能安全获得格式正确的设备 ID；不等于 ID 服务器注册和远端连接成功 | `rustdesk --get-id`；菜单 7 |

**绿色**：该节点当前的本地检查已满足；**红色**：明确缺失或异常；**黄色**：缺少必要证据、需要配置或人工验证。颜色不能代替 RustDesk 的实际远端连接测试。在没有颜色的终端，使用实心圆、空心圆与菱形区分相同状态。

## 三种显示布局

- **宽终端（107 列及以上）**：七个节点排成一条水平数轴，依次显示组件名称、当前值、版本/分辨率和路径。
- **中等终端（67–106 列）**：上方四个节点、下方三个节点，流程连贯。
- **窄终端**：使用竖向流程；不会横向溢出导致菜单编号错位。

只有主菜单显示完整流程。子菜单继续使用简洁标题与编号。节点所需路径较长时会缩略；可以用以下命令查看完整诊断：

```bash
hdm --chain
```

可选机器可读 JSON（其中可能包含本机 RustDesk ID）：

```bash
hdm --chain-json
```

在不希望屏幕或终端日志中展示设备 ID 的场合，使用 `HDM_HIDE_RUSTDESK_ID=1 sudo hdm` **不一定能保留环境变量**；推荐 `sudo env HDM_HIDE_RUSTDESK_ID=1 hdm`。按需设置 `NO_COLOR=1` 可禁止彩色终端输出。

## X11、Wayland、锁屏和登录界面

**LightDM/GDM3 是显示/登录管理器，不是虚拟显示器。** Xorg 是 X11 服务器；Wayland 是另一套显示协议。屏幕分辨率取决于实际显示输出和会话，不是仅仅“创建会话”后就有一个固定分辨率。

**桌面锁屏**是 XFCE、GNOME 等桌面和对应屏保/锁屏组件的功能；**RustDesk 是否能远程控制锁屏**以及**注销后能否控制 GDM3/LightDM 登录界面**属于另外的验收条件。X11 通常更适合标准 RustDesk 的传统登录前捕获路径，但锁屏及重启仍需目标环境验证。Wayland 标准版支持经 Portal/PipeWire 授权的已登录桌面，特殊的 Wayland 无人值守预览版目前主要面向 x86_64 Debian/Ubuntu，不能视为 Ubuntu 26 ARM64 已适配。

参考：

- [Debian DisplayManager 说明](https://wiki.debian.org/DisplayManager)
- [Ubuntu LightDM 项目说明](https://github.com/ubuntu/lightdm/blob/main/README.md)
- [RustDesk Linux 客户端指南](https://rustdesk.com/docs/en/client/linux/)
- [RustDesk Wayland 无人值守预览](https://www.rustdesk.com/blog/unattended-remote-access-wayland/)

[返回 README](../README.md) · [菜单操作指南](menu-guide.md) · [Ubuntu 26 ARM64 指南](ubuntu26-arm64.md)
