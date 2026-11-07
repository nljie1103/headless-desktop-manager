# 虚拟显示方案

- Xorg Dummy：Ubuntu `xserver-xorg-video-dummy` 包，GNOME 推荐主路径；有风险确认、模式选择、旧配置快照和计时回滚。
- Xvfb：APT 安装并可创建独立 `hdm-xvfb.service`，但它**不会自动提供 GNOME/GDM 用户登录会话**。
- VKMS：Linux 内核 DRM/KMS 模块，按当前内核是否提供 `vkms` 检测，**不是独立通用下载包**，与 GNOME 和 RustDesk 需要额外实测。
