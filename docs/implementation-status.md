# 实施进度（与菜单设计分开）

版本：v0.1.1 Preview · 2026-11-07。**菜单存在 != 功能已经实机验证。**

| 领域 | 当前实现 | 未完成 / 需测试 |
|---|---|---|
| 启动安装器 | 本地安装、GitHub main 下载、版本目录/原子 symlink | 发布固定 tag 的独立签名引导 |
| 所有 1～10 菜单 | 按规格书生成 473 个可导航条目，安全反馈/返回 | 一部分高级叶子仅说明限制 |
| Xorg Dummy | APT 安装、预设分辨率、生成 Xorg、快照+七分钟回滚 | 真实云端 GDM3/无 GPU 实测 |
| Xvfb | APT + 独立 systemd 模板 | GNOME 桌面会话与 RustDesk 捕获联动 |
| VKMS | 内核检查、modprobe、自启配置 | 特定内核的 DRM 到 GNOME 使用链路 |
| GNOME | ubuntu-desktop/最小/依赖补齐、GDM3 X11 设置 | 实际登录界面画面、软件渲染/自动恢复 |
| XFCE/MATE | 基础 APT 安装 | 安全的 LightDM 切换与实机测试 |
| RustDesk | 官方 Release 筛选 SHA256 校验、`.deb` 安装、ID、基础配置导入 | 配置生效账户、自建服务器测试、永久密码重启保持 |
| GitHub 备用源 | 机制、清单校验、空仓库显式失败 | **需要实际上传经许可验证的二进制资产** |
| HDM 自更新 | 稳定 tag 筛选、独立摘要信任清单、完整包原子切换 | 发布第一个 Release 并测试 Windows/Linux 下载 |
| 故障诊断 | 已安装、日志、网络、服务、脱敏导出、快照还原 | GPU/黑屏精细自动修复策略 |
| Windows 推送 | PowerShell + Git 克隆/增量提交/推送 | **已修复 PowerShell 5.1 BOM 编码兼容性；仍需用户 Windows / GitHub 实测** |

## 严格使用要求

1. **不能声称 GNOME 远程桌面已经经过实机验收**。`--self-test` 只是离线逻辑与语法测试。
2. 先在云测试 VM 创建快照并保留 SSH/救援控制台，再运行 9.1.6。
3. 按顺序验证 Xorg/GDM、GNOME Shell/X11、RustDesk 设备 ID/密码、自建服务器、外部画面、重启。
4. 运行效果缺陷需提交 Issue/日志，再根据具体错误修复，不要在云实例上盲目 `chmod 444` 或关闭系统安全服务。
