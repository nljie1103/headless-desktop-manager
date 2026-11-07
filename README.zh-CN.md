# 简体中文说明

HDM 的中文文档现已作为 GitHub 默认首页。请直接阅读 **[README.md（中文首页）](README.md)**。

英文版本： [README.en.md](README.en.md)。

## v0.3.3 启动环境检测

运行 `sudo hdm --preflight` 检查已安装桌面、DRM 已连接的显示输出和图形会话。新版本打开菜单就进行只读检测；一键安装不再默认所有机器无桌面、无显示器。运行 `sudo hdm --rustdesk-permissions` 排查 RustDesk 网络/安全设置灰色、Polkit 授权与服务账户作用域差异。Ubuntu 26 GNOME 不强制 `WaylandEnable=false`；息屏、锁屏、注销与登录前访问不等价。详细说明见 `docs/environment-detection.md`。
