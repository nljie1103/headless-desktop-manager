# HDM 环境检测、息屏状态与 RustDesk 权限说明（v0.3.3）

HDM 打开 `sudo hdm` 主菜单时，先执行**只读检测**，显示桌面、显示输出、图形会话三类结果。可以单独使用 `sudo hdm --preflight`，不会安装软件、修改 GDM/Xorg 或重启服务。

## 检测依据及边界

- 桌面是否安装：检查 GNOME Shell、XFCE、MATE、KDE 的软件包状态。**已安装不等于已运行。**
- 显示输出：检查 `/sys/class/drm/*/status`。`connected` 表示 DRM 连接器有输出，不证明存在实体显示器（可能是 VKMS、虚拟设备或假插头）；全是 `disconnected` 表示**未检测到已连接的输出**，也不证明物理上没有屏幕；没有 DRM 信息、存在 `unknown` 或检测不足时显示“未知”。
- 图形会话：使用 `loginctl` 判断 X11/Wayland 类型，SSH/TTY 不算桌面会话。超出扫描上限或无法读取时标记未知。即使有图形会话，也不证明 RustDesk 获得了屏幕捕获权限。

## 四种环境的默认策略

| 已安装桌面 | DRM 已连接输出 | 推荐动作 |
| --- | --- | --- |
| 有 | 有 | 保留桌面/显示配置，只安装或检查 RustDesk |
| 有 | 无 | 保留桌面，先判断虚拟输出是否适配现有显示协议 |
| 无 | 有 | 优先补齐 GNOME，不修改现有输出 |
| 无 | 无 | 优先安装 GNOME，再单独验证虚拟输出与远程抓屏 |

- **DRM 输出未知**：不应自动新增 Xorg Dummy 的全局配置，也不应强制重写 GDM。
- **Ubuntu 26 GNOME Wayland-only**：可以安装 GNOME、PipeWire、Portal 和 RustDesk，但不自动写入 Xorg Dummy 全局配置；这几项包安装完成仍**不能**代表存在可以抓取的虚拟屏幕。
- **Ubuntu 24.04 GNOME X11 场景**：如果明确未检测到已连接 DRM 输出，可提出 Dummy 配置，但仍须风险确认、备份及外部回归验收。
- XFCE/MATE 已存在时，不应无提示替换 GNOME 或显示管理器。

## `WaylandEnable=false` 的作用范围

这是旧版 GDM 的 **X11/Wayland 选择项**，不是熄屏/锁屏控制项：

```ini
[daemon]
WaylandEnable=false
```

只有发行版仍提供 GNOME Xorg 会话时，才应考虑启用。在 Ubuntu 26 / GNOME 49+，不应强制设置，以免出现图形登录失败或登录循环。

具体状态应区别对待：

- **显示器熄屏**：DPMS/省电输出可能关闭；服务运行仍不意味着图像流存在。
- **锁屏**：需要检测远端桌面协议和授权政策，不能默认绕过锁屏。
- **注销**：普通 Wayland 共享门户所依附的用户会话可能已经结束。
- **重启后尚未登录**：需要 RustDesk 版本及登录屏幕捕获机制明确支持；ARM64 标准版尚无 HDM 验收证明。
- **没有显示输出**：需要 compositor/DRM/KMS 层的显示输出，Xorg Dummy 不等于 Wayland 虚拟显示。可探索 VKMS、GNOME Remote Desktop headless RDP，但不谎称它们自动让标准 RustDesk 可以抓屏。

## RustDesk 灰色安全/网络设置

RustDesk GUI 中 Security/Network 的 Unlock 按钮涉及管理员权限与 Polkit 授权；在没有图形会话/Polkit 代理或不同用户配置作用域下可能无法启用。

运行 `sudo hdm --rustdesk-permissions` 或菜单 `7 → 12`，可只读查看：RustDesk 版本与服务、systemd 服务账户、pkexec/Polkit、root CLI TOML 和调用用户 TOML、设备 ID。HDM 不输出服务器公钥内容或密码。

对已确认的自建服务器设置，使用 `7 → 1` 草稿→预览→保存→TOML 读回校验。**该校验只保证所检查的配置文件与输入一致，不保证服务采用了该文件、注册成功或外部桌面画面已可用。**

不要为了让灰色按钮可点击而运行长期 root 图形会话、给配置 chmod 777、关闭认证或把密码写进启动脚本。具体的图形授权问题需要管理员的正常 Polkit 授权与远端连接实测。

## 上游技术参考

- RustDesk 官方 Linux 文档：https://rustdesk.com/docs/en/client/linux/
- RustDesk Wayland 无人值守预览发布：https://rustdesk.com/blog/unattended-remote-access-wayland/
- RustDesk 官方客户端设置文档：https://github.com/rustdesk/doc.rustdesk.com/blob/master/content/client/_index.en.md
- GNOME Remote Desktop headless RDP 配置：https://github.com/GNOME/gnome-remote-desktop/blob/main/docs/configuration.md
