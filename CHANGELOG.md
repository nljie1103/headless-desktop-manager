# 更新记录 / Changelog

## v0.3.4 — 修复在线更新与自动发布（2026-11-07）

- 解释并修复菜单 8 原先仅识别正式 GitHub Releases、而 Windows 推送只更新 main 的发布断层。
- 新增 `8 → 1 → 1` 同时查询正式 Release 和开发版 main，`8 → 2 → 5` 更新到固定 Git SHA 的 main 预览版；新增 `hdm --check-update` 和 `hdm --update-preview` 命令。
- 预览升级检查远端 VERSION 严格递增、GitHub HTTPS 固定提交、归档路径与类型、菜单结构及启动自检；以原子符号链接切换版本并保留旧版，拒绝旧版本覆盖和同版本隐藏更新。
- Windows 一键发布将自动为新版本创建并推送 `vX.Y.Z` 标签，触发已有 GitHub Actions 预览版 Release 构建；如果 main 已经推送而 tag 失败，可以用同一命令仅补推缺失 tag。
- 正式 Release 更新支持 GitHub API 资产 SHA-256（HTTPS 信任模型）；如管理员配置了独立受信任哈希文件，仍必须匹配，不允许静默绕过。
- 注意：main 预览版没有独立代码签名；GitHub Actions 构建是否成功以及 Ubuntu ARM64 图形链路仍需实测验证。

## v0.3.3 — 启动环境识别与按需安装（2026-11-07）

- 新增 `core/environment.sh` 只读检测：已安装的 GNOME/XFCE/MATE/KDE、DRM 连接状态、真实 X11/Wayland 会话、GDM3/RustDesk 服务，并清楚标记未知情况。
- HDM 菜单首页显示环境识别结果及操作建议；增加 `hdm --preflight` 独立只读入口，不再假定所有服务器都无显示输出与无桌面。
- 一键安装根据检测生成步骤：保留已有桌面，已有连接输出时跳过 Xorg Dummy，未知显示状态时保守处理；Ubuntu 26 GNOME Wayland-only 不强制 GDM3 X11。
- 新增 RustDesk 安全/网络灰色设置只读诊断：`hdm --rustdesk-permissions`、菜单 `7 → 12`；区分 Polkit 授权、systemd 服务用户及不同用户的 TOML 配置，不绕过权限保护。
- 明确区分显示器有输出、息屏、锁屏、注销与重启前登录；`WaylandEnable=false` 不是息屏可连接开关，且不适用于 Ubuntu 26 GNOME。
- 原 10 个主菜单及 473 个旧条目均保留，新增一项权限诊断；加入四种环境组合、未知 DRM、权限诊断及只读行为单元测试。
- **仍未完成**：Ubuntu 26 ARM64 无显示输出下 GNOME Wayland 虚拟屏幕及 RustDesk 无人值守实机验收。

## v0.3.2 — 终端交互与 RustDesk 配置闭环修复（2026-11-07）

- 默认隐藏 APT/DNF/YUM 的逐包解压、下载与安装过程，仅显示步骤和成功/失败；原始输出写入权限受限的日志文件，`HDM_DEBUG_INSTALL=1` 可打开详细输出。
- 增加磁盘不足、网络/DNS 故障、下载超时、镜像 404、签名校验、依赖冲突和权限不足的错误分类，只有合理的网络类故障才尝试可信备用镜像。
- 修复菜单 7.1.1～7.1.8 被错误地映射到同一个 RustDesk 配置向导的问题：一次填写草稿、分别编辑、只读预览、保存应用、读回校验及设备 ID 查询均使用独立处理函数。
- 支持读取 root CLI 作用域与现有用户作用域的 RustDesk2.toml，明确区分磁盘配置、系统服务状态及服务器注册状态；不输出公钥内容或访问密码。
- RustDesk 网络诊断直接使用已经保存的 `主机:端口`，不再反复要求用户输入同一地址；UDP 和实际远控能力不伪报为已验证。
- 终端菜单在 TTY 中自动清屏并精简页眉，加入状态提示，Wayland-only 平台不再错误把 Xorg Dummy 标成 GNOME 推荐方案；10 个主菜单、473 个条目保留。
- 增加静默安装失败分类、配置草稿独立操作、TOML 读回校验等自动化测试。
- 以上改进尚未经 Windows / Ubuntu 26 ARM64 真机端到端验收，不代表 GNOME Wayland 无人值守问题已经解决。

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
