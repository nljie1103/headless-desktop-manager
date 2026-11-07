# 更新记录 / Changelog

## v0.2.0 — 2026-11-07（Preview）

- 将 GitHub 默认 `README.md` 调整为中文首页，增加功能矩阵、架构图、菜单导航与安全说明；英文迁移至 `README.en.md`。
- 重构 Windows PowerShell 推送脚本：固定仓库、自动读取 VERSION 和真实发布摘要、自动提交/推送；移除重复确认与 Git 分页器；禁止将旧版本覆盖新版本。
- 增加 `.gitattributes`，为 Linux 脚本固定 LF 换行规则。
- 实现 Xvfb 显示编号、分辨率和色深的参数保存，以及按配置生成 systemd 服务与状态验证（仍属实验性方案）。
- 为 RustDesk 已验证官方下载缓存建立 SHA256 索引，并提供有校验的本地版本回滚选项；导入自建服务器配置失败时尝试恢复快照。
- 新增 GNOME/X11 与 RustDesk 分项诊断、`hdm --status-json` 机器可读健康报告；完善测试。
- 更新 Windows 发布说明、功能实施状态和测试；本版本尚未通过真实 GNOME 无显示器远控验收。

## v0.1.1 — 2026-11-07

- 修复 Windows PowerShell 5.1 脚本 UTF-8 BOM 编码兼容问题。
- 优化 Git 克隆 / 首次上传及提交格式验证，增加 commit policy 自动化测试。

## v0.1.0 — 2026-11-07

- 建立模块化 Bash 项目与 473 个菜单入口。
- 支持 Ubuntu 24.04 x86_64 主要安装流程、RustDesk 下载校验与显示配置回滚框架。
