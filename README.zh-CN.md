# Headless Desktop Manager（HDM）

**Linux 无显示器远程桌面一键部署与管理工具**。默认使用完整 **GNOME** 桌面，不会自动更换成 XFCE。目标配置为 Ubuntu 24.04 x86_64 + Xorg Dummy + GDM3（X11）+ RustDesk。

> **当前版本：v0.1.1 预览开发版。** 已有完整菜单导航、核心安装代码、更新/诊断/备份保护，但尚未在真实云服务器完成 GNOME/RustDesk 远控、断电重启、画面捕获等验收。不要把“脚本可运行”与“无显示器远控已验证”混淆。

## 上传 GitHub 后的一行安装命令

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

上面是 **main 开发版入口**，上传前不可访问。安装器会要求确认信任来源。正式发行版应提供固定 tag 和独立校验值。可以先下载脚本自行审查，再执行。

解压源码后也可以在 Ubuntu 24.04 x86_64 通过 `sudo bash install.sh --local` 安装 HDM，本步骤不会自动安装 GNOME/RustDesk。

安装后运行 `sudo hdm`；首次建议进入 **9 → 9.1 → 9.1.6**。菜单 1～10 和全部 473 个编号条目已经保留。各项的实验性/未开放能力会明确提示。

## 关键使用提示

- 默认 GNOME，Xorg Dummy 推荐；XFCE/MATE/Xvfb/VKMS 为其他选择或实验方案。
- 软件包优先系统 APT；网络故障时可临时使用发行版可信镜像，绝不禁用签名。GitHub 备用资产必须真正发布且有 SHA256，当前仓库 **没有备用 `.deb`**。
- 不默认重启系统、关闭 SSH 或防火墙、设置自动登录、关闭锁屏。
- 改动 Xorg/GDM 前需要危险操作确认、配置快照和回滚计时器；确认正常后执行 `sudo hdm --confirm-display`，否则约 7 分钟后可能自动还原。
- RustDesk 的 `--password` CLI 有短时进程参数暴露风险，脚本会说明并要求明确确认。
- 登录画面是否可控制、GNOME Shell 软件渲染是否支持、冷重启后远程连接是否正常，仍需要真实服务器实测。

完整菜单、目录、接口、风险和里程碑：[`docs/AI_DEVELOPMENT_SPEC.md`](docs/AI_DEVELOPMENT_SPEC.md)。

Windows 一键上传脚本：[`tools/publish-windows.ps1`](tools/publish-windows.ps1)。

GitHub 地址：https://github.com/nljie1103/headless-desktop-manager

**Git 提交规范：** 提交标题必须以 `vX.Y.Z` 开头，随后明确写出本次真实更改。参见 [`docs/COMMIT_POLICY.md`](docs/COMMIT_POLICY.md)。
