# HDM 推荐组合断点续装 / GNOME 安装事务设计（v0.3.0）

> **用途**：帮助开发者、AI 编程助手维护一键安装流程，不把本地软件包状态当成已经成功远程控制的证明。

## 默认部署目标

Ubuntu 24.04 LTS x86_64 + Xorg Dummy + 完整 GNOME + GDM3/X11 + RustDesk。不会替换用户选定的 GNOME，也不会在失败时自动改用 XFCE。

## 执行前检查

- 仅 Ubuntu 24.04 x86_64 可以执行系统写入；其他系统可以执行只读诊断。
- 检查根分区可用空间至少 4 GiB；可用内存不足 2 GiB 时提示，但不自动换桌面。
- 若存在 `/var/lib/hdm/pending-rollback`，必须先确认或恢复上一组显示变更，阻止新安装覆盖恢复点。
- 用户在一次综合风险提示后明确输入 `YES`，才进入推荐安装事务；这不是 Windows 上传脚本的确认流程。
- 使用独立的 `flock` 锁防止同时启动两个一键安装实例。锁必须在失败后释放，允许同一个 HDM 菜单进程立即重试。

## 状态机

顺序固定为：

1. `dummy-pkg`：检查 `xserver-xorg-video-dummy` + `xserver-xorg-core`，缺失时使用 APT 安装。
2. `gnome-pkg`：检查 `ubuntu-desktop` + `gdm3` + `gnome-shell`，缺失时安装完整 GNOME。
3. `rustdesk-pkg`：检查 RustDesk 软件包和命令，缺失时从可信源安装。
4. `dummy-config`：验证 HDM Xorg 配置、驱动标识和所选分辨率；缺失或不匹配则在快照与安全回滚保护下更新。
5. `gdm-x11`：在 `/etc/gdm3/custom.conf` 的 **[daemon]** 节中解析有效的 `WaylandEnable=false`，缺失时配置并保留恢复能力。

对于每个步骤：

- **先真实检查，后参考进度记录**。即使数据库标记 `done`，但系统检测未通过也必须重做。
- 开始时记录 `running`，结束并通过检查时记录 `done`，失败时记录 `failed`，并立即停止后续更改。
- 安装包不会因为中途中断而被自动卸载；避免 `autoremove` 导致图形环境失联。
- 不自动重启 GDM3、SSH 或整台服务器。图形会话和远程画面必须由用户在部署后验收。

持久账本位于 `/var/lib/hdm/quick-install-state.tsv`，由 root 拥有，仅保存合法阶段名、状态和 UTC 时间戳；不是任意命令文件，也**不存储密码、RustDesk 凭据或安装输出**。`--quick-status` 同时显示进度记录和实际状态，两者可能不一致。

## 失败恢复举例

GNOME 包下载失败：`dummy-pkg=done`、`gnome-pkg=failed`；下次选择 `9.7.2` 或执行 `sudo hdm --quick-resume`，HDM 会再次验证 Dummy 包是否存在，存在则跳过并从 GNOME 步骤继续。

若用户之后删除了 Dummy 驱动，即使账本仍为 `done`，下一次恢复也必须重新安装缺失驱动。

## 安全边界

- 修改 Xorg Dummy 文件之前检查文件是否确实属于 HDM；若被其他系统工具占用同名路径，拒绝自动覆盖。
- 重要显示变更保留配置快照和定时回滚；不能因为安装器运行结束就自动确认远端图像有效。
- 如果此前等待确认的自动回滚仍在进行，一键续装应停止，先处理当前保护任务。
- `hdm --doctor`、`hdm --doctor-json` 只读取包、服务、会话、套接字和非敏感配置标志，不导出密码或 RustDesk 原始 TOML，且即使使用 sudo 也不创建 HDM 状态目录。
- `hdm --doctor` 的“通过”只表示**本机信号正常**，不代表远端设备已经成功看到画面、认证或冷启动连接。

## 回归测试

运行 `bash tests/run.sh`。其中 `test_quick_install.sh` 使用完全模拟的宿主操作，在临时目录中测试失败与重试，不安装软件、不重启服务；`test_doctor.py` 对 GNOME/GDM 和 RustDesk 规则执行纯数据模拟与只读 JSON 校验。

## 云服务器验收（尚未完成）

请保留 SSH、云平台控制台与快照，依次验证 Xorg Dummy → GDM3 → GNOME X11 会话 → RustDesk ID/Relay → 密码 → 鼠标键盘及画面 → 重启后恢复。只有云端回归真正完成，才可把此功能标记为生产稳定。
