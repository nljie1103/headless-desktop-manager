# 更新记录 / Changelog

## v0.3.1 — Ubuntu 26 ARM64 测试路径（2026-11-07）

- 移除 HDM 安装器及核心操作对 Ubuntu 24.04 x86_64 的硬性白名单，允许 Ubuntu 26 ARM64 进入测试流程。
- GNOME Wayland-only 检测：新版 Ubuntu 一键安装不再强制 GDM3 X11，不写入 Xorg Dummy 全局配置。
- 支持 RustDesk 官方 ARM64 `.deb` 架构匹配与已校验缓存；不能从无校验的未知来源强制安装。
- Ubuntu APT 官方备用源根据真实发行版代号与 CPU 架构生成，不再错误指向 noble。
- 升级 GNOME / RustDesk 诊断与中文、英文使用说明，明确 ARM64 Wayland 无人值守尚未验证。
- 保持 Windows 单命令自动提交推送与真实 commit 变更摘要规范。

## v0.3.0 — 2026-11-07（Preview）

- 将推荐组合安装改为**逐阶段可续装事务**：驱动软件包 → 完整 GNOME/GDM3 → RustDesk → Xorg Dummy 配置 → GDM3/X11。每一步使用实际系统状态核验，不信任进度文件里的“完成”标记。
- 新增安装进度账本 `/var/lib/hdm/quick-install-state.tsv`、`--quick-status` 和 `--quick-resume`；支持中断后续装、单项失败定位与 `flock` 并发保护；修复同一个菜单会话重试时锁未释放的问题。
- 推荐组合只在**开始时**统一确认一次危险操作（仅限该次安装事务），不再在每一步重复询问；单项维护菜单仍保持风险确认。
- 新增 `hdm --doctor` / `hdm --doctor-json` 中文诊断建议引擎，检查驱动、GDM3/X11、GNOME 会话、RustDesk 和显示配置恢复状态，并将建议指向已有菜单；修复只读命令在 root 身份下意外创建状态目录的问题。
- 修复 GDM3 X11 检测：仅解析 `[daemon]` 下有效的 `WaylandEnable=false`，忽略注释和其他 section，并处理重复配置键。
- RustDesk ID / Relay 地址新增语法、端口范围校验；阻止覆盖并非 HDM 生成的 Xorg Dummy 配置文件。
- 新增可重复的模拟安装中断/续装测试、纯诊断规则测试和端点输入测试；更新中英 README、开发状态和 Windows 一键推送版本。
- **仍未完成**：真实云服务器上的 GNOME 无显示器图像捕获、冷启动无人值守和 RustDesk 服务端到端验收。

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
