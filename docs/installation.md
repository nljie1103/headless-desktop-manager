# 安装与启动

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

安装成功后，在交互终端自动显示 HDM 菜单；以后可使用 `sudo hdm`。如需非交互安装或由其它程序调用，可设置 `HDM_NO_AUTO_MENU=1`。

安装器只部署管理器本体，不会在安装时自动重启图形服务、切换显示配置或安装 GNOME。进入菜单后由用户选择安装项目。管理器默认安装至 `/opt/hdm`，当前运行版本位于 `/opt/hdm/current`。

## 安装前建议

保留 SSH、云服务商控制台和可用快照。不同发行版、内核和显示协议需要匹配显示方案。Ubuntu 26 的 GNOME 使用 Wayland，不应使用 `WaylandEnable=false` 强制不存在的 GNOME Xorg 会话。

## 常用命令

```bash
sudo hdm --preflight
sudo hdm --doctor
sudo hdm --check-update
sudo hdm --quick-status
```

详细项目功能见 [菜单指南](menu-guide.md)；组件运行状态与兼容性见 [测试边界](testing-and-limitations.md)。
