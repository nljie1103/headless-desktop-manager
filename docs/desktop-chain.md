# HDM 桌面链路数轴 · v4.5.5

HDM 主菜单顶部实时显示七个状态节点；详细软件包安装清单移至 `hdm --readiness`，首页不重复显示：

```text
显示输出 → 登录管理器 → 图形协议 → 桌面环境 → 图形会话 → RustDesk → 设备 ID
```

**这是排障依赖检查顺序，不是严格的 systemd 启动顺序。** 若当前使用 XFCE/LightDM，则只将 XFCE、Xorg、D-Bus X11、LightDM、GTK Greeter、RustDesk 等当前方案依赖计入缺失，不会要求额外安装 GNOME/GDM3、Dummy、Xvfb、VKMS。已安装与已运行、已登录、已实测属于不同状态。 图形会话由显示服务器、桌面管理器和用户登录系统共同建立；手动启动的 X11 会话甚至可以不使用 GDM3/LightDM。RustDesk 连接已经存在的会话或它受支持的登录界面，不负责为所有桌面创建用户会话。

## 组件与它们的职责

| 节点 | 典型可选实现 | 满足的本地检查 | 检测路径 / 可用操作 |
|---|---|---|---|
| **1. 显示输出** | DRM 物理输出、虚拟显示 Xorg Dummy、VKMS；Xvfb 是独立 X11 虚拟帧缓冲 | DRM 已连接，或当前匹配的 X11 DISPLAY 上 Xrandr 确认有已连接并启用的实际输出时标为通过；仅有 Dummy 配置文件时显示待核实 | `/sys/class/drm`、`/etc/X11/xorg.conf.d/20-hdm-dummy.conf`；菜单 5 |
| **2. 登录管理器** | GDM3、LightDM；亦可使用手动 X11 会话 | 已安装且 systemd 服务 active；不存在或异常则提示核实 | `/etc/X11/default-display-manager`；菜单 3 |
| **3. 图形协议** | X11（常由 Xorg 提供）、Wayland | logind 确认活动用户会话的协议，X11 还检查 X Socket | `/tmp/.X11-unix/X0`、`/run/user/*/wayland-*`；菜单 2 → 9 |
| **4. 桌面环境** | XFCE、GNOME、MATE、KDE | 实际活动桌面与已安装的软件包对应；仅安装则标为软件已安装并注明待登录，不代表图形会话已运行 | `/usr/share/xsessions`、`/usr/share/wayland-sessions`；菜单 2 |
| **5. 图形用户会话** | logind 用户会话、X11 DISPLAY、Wayland compositor | logind 有活跃用户图形会话；实际分辨率仅由已授权的 `xrandr` 输出确认 | `loginctl`、`xrandr --current`；菜单 2 → 9 |
| **6. RustDesk** | RustDesk Linux 系统客户端/服务 | 包已安装且服务运行；GNOME Wayland 还核查 Portal/PipeWire 所需软件包 | `/usr/bin/rustdesk`、`systemctl status rustdesk`；菜单 4 |
| **7. 设备 ID** | `rustdesk --get-id` | 能安全获得格式正确的设备 ID；不等于 ID 服务器注册和远端连接成功 | `rustdesk --get-id`；菜单 4 → 9 |

**绿色**：该节点当前的本地检查已满足；**红色**：明确缺失或异常；**黄色**：缺少必要证据、需要配置或人工验证。颜色不能代替 RustDesk 的实际远端连接测试。在没有颜色的终端，使用实心圆、空心圆与菱形区分相同状态。

## 三种显示布局

- **宽终端（107 列及以上）**：七个节点排成一条水平数轴，依次显示组件名称、当前值、版本/分辨率和路径。
- **中等终端（67–106 列）**：上方四个节点、下方三个节点，流程连贯。
- **窄终端**：使用竖向流程；不会横向溢出导致菜单编号错位。

只有主菜单显示精简线轴（不显示图例和软件包清单）。子菜单继续使用简洁标题与编号，`hdm --chain` 保留图例和详细判据。节点所需路径较长时会缩略；可以用以下命令查看完整诊断：

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

## v4.3.0 阶段与菜单对应关系

状态图的第 1–7 个节点分别对应主菜单 1–7：显示输出、登录管理器、图形协议、桌面环境、图形用户会话、RustDesk、设备 ID。新增第 **8 菜单「HDM 脚本管理」**，负责更新及安全卸载 HDM、更新日志、安装日志、完整诊断导出、智能部署和备份。此第 8 项不属于图形/远控链路，属于管理工具本身。

## v4.5.1：双登录管理器与多个图形会话

**同时安装 GDM3 和 LightDM 并不等于两个登录管理器同时运行。** HDM 区分以下三种状态：

| 本机事实 | 登录管理器节点 | 意义 |
|---|---|---|
| GDM3 + LightDM 均安装；仅 LightDM 服务运行，默认也是 LightDM | `LightDM · 运行`（绿），详细信息含 `另装GDM3` | 已安装两套，但当前只有 LightDM 报告运行 |
| GDM3 和 LightDM 服务都报告运行 | `GDM3 + LightDM`（黄），`双服务运行` | 可能存在 seat 争用，不能直接断定哪个负责当前图形会话 |
| 默认 GDM3，实际只有 LightDM 服务在运行 | `LightDM · 运行`（黄），`默认GDM3` | 系统默认配置与运行状态不一致，需要排查 |

若存在 XFCE/X11 session c2 和 GNOME/Wayland session c3 两个 `class=user`、`state=active/online` 的图形用户会话，线轴的图形协议节点显示 `X11+Wayland`，桌面节点 `XFCE+GNOME`，会话节点 `多会话 2`，详细信息列出 `c2:XFCE/X11(active)` 和 `c3:GNOME/Wayland(online)`；所有涉及选择具体会话的节点均标黄。两个都为 XFCE/X11 仍然标注 `X11×2 / XFCE×2`，不会折叠成一条绿色会话。登录管理器的 greeter 和 SSH/TTY 不算登录的桌面用户会话。

**RustDesk 当前控制哪个座席 / DISPLAY 无法只靠 `systemctl` 和 `loginctl` 判定。** 因此服务正常和设备 ID 可读不代表特定会话已可捕获；多会话时线轴中 RustDesk 和设备 ID 同样显示待核实。Xrandr 只确认其自身有权限访问的 DISPLAY；只有与唯一 loginctl 图形会话的 Display 完全相同且 X Socket 匹配时才关联分辨率，其他情况不猜测。如果会话列表超过检测上限则标注扫描未完成，避免把截断的部分当成全部。

查看完整节点：`sudo hdm --chain`；程序结构化输出：`sudo hdm --chain-json`。以上都是只读检查；不会因为检测到两个管理器而自动停止或卸载任何服务。
