# 测试矩阵与限制（v0.1.1）

| 测试项目 | 当前状态 | 验收方法 |
|---|---|---|
| Bash 语法与菜单完整性 | 本地自动测试 | 全脚本 `bash -n`，473 菜单项、无孤立菜单 |
| Release 元数据筛选 | 本地模拟 JSON | 禁止 nightly、过滤 mirror 标签、要求 SHA256 |
| 归档路径安全 | 本地自动测试 | 拒绝路径穿越、软链接、异常大小 |
| Ubuntu 24.04 amd64 GNOME 安装 | 尚未真实执行 | 空白实例安装完整 GNOME |
| Dummy 1080p X11 显示 | 尚未真实执行 | 通过 GDM3 启动、确认 Xorg 日志和 xrandr |
| 无 GPU GNOME Shell 渲染 | 尚未真实执行 | 检查 GNOME 会话、渲染、操作流畅度 |
| RustDesk ID / 中继配置 | CLI 已设计、未远端验收 | 验证服务进程使用的配置、ID 实际注册 |
| 无人值守认证 | 未真实执行 | 另一端测试永久密码认证且重启保持 |
| 软件源失败切换 | 静态逻辑检查 | 注入 DNS / TLS / GPG / 空间故障 |
| GitHub 备用包 | 尚未发布 | 镜像 Release 与 manifest 上传后验证 |
| Windows Git 推送 | 尚未 Windows 实机运行 | Git for Windows + GitHub 身份认证 + push |
| GNOME/远控冷重启 | 尚未真实执行 | 云平台完整重启测试、SSH 救援路径 |

由于当前环境不是 Ubuntu 24.04 的独立 GNOME 云服务器，本文件没有宣称实际部署验收通过。

## 必须提前完成的外部事项

1. 在空白 Ubuntu 24.04 amd64 VM 创建快照、保留 SSH/云控制台。
2. 推送代码至正式仓库；GitHub Actions 通过后再按需创建正式 Release。
3. GNOME + Dummy + RustDesk 的实机录屏、输入、注销、重启验证。
4. RustDesk 的服务器配置 CLI 对服务运行账户的生效路径实测。
5. 如需 GitHub 备用二进制：发布合规资产、校验 SHA256、维护 manifest。
6. 如需自动自升级：采用签名/独立可信摘要发布机制。
