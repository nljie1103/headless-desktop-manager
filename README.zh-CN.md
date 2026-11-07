# 简体中文说明

HDM 的中文文档现已作为 GitHub 默认首页。请直接阅读 **[README.md（中文首页）](README.md)**。

英文版本： [README.en.md](README.en.md)。

## v0.3.3 启动环境检测

运行 `sudo hdm --preflight` 检查已安装桌面、DRM 已连接的显示输出和图形会话。新版本打开菜单就进行只读检测；一键安装不再默认所有机器无桌面、无显示器。运行 `sudo hdm --rustdesk-permissions` 排查 RustDesk 网络/安全设置灰色、Polkit 授权与服务账户作用域差异。Ubuntu 26 GNOME 不强制 `WaylandEnable=false`；息屏、锁屏、注销与登录前访问不等价。详细说明见 `docs/environment-detection.md`。


### 自建 RustDesk 服务器配置（v0.3.6）

使用菜单 7.1 先录入草稿，再选 7 备份并保存。HDM 将根据当前服务和 `sudo` 用户读取并写入独立的 TOML 配置文件，恢复服务后验证。如果失败会尝试还原快照。无法证明服务注册或图形会话可用时，仍应通过 `sudo hdm --doctor` 查明原因。
