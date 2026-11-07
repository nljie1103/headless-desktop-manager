# 安装说明

1. 备份云 VM、确认 SSH 及云控制台均可使用。
2. Ubuntu 24.04/26 ARM64 等 Linux 测试主机下载 `install.sh`，检查来源，执行 `sudo bash install.sh`。
3. 安装器会部署 HDM 管理器到 `/opt/hdm`，不会直接更改已有桌面。
4. `sudo hdm` → 9 → 9.1 → 9.1.6 执行推荐组合。
5. 通过菜单 7 配置服务器与访问认证，菜单 10 检查运行情况。使用另一台设备实际连接。
6. 图形显示验证完成后必须按提示执行 `sudo hdm --confirm-display`；否则系统级回滚计时器会撤销图形配置。

主仓库：https://github.com/nljie1103/headless-desktop-manager


## v0.3.0 断点续装和诊断

```bash
sudo hdm --doctor        # 中文只读健康检查，不会更改系统
sudo hdm --quick-status  # 比较安装进度与当前包/配置状态
sudo hdm --quick-resume  # 再次确认风险后续装缺失/失败阶段
```

首次安装或续装都不会启用自动登录、停止 SSH 或强制重启显示管理器。配置变更可能启动自动恢复计时器，务必从其他设备测试后再决定确认/回滚。详见 [断点续装设计](resumable-install.md)。


> v0.3.1：取消发行版/架构硬性安装白名单。Ubuntu 26 的 GNOME 仅支持 Wayland 会话，请参阅 [Ubuntu 26 ARM64 测试指引](ubuntu26-arm64.md)；不要强制设置 GDM3 `WaylandEnable=false`。
