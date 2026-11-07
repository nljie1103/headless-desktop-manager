# 故障排查

- `sudo hdm --diagnose`：只读状态检查。
- `sudo hdm` → 10.2：Xorg/显示驱动与 DISPLAY；10.3：GNOME/GDM 会话；10.4：RustDesk；10.5：网络；10.8：日志；10.9：配置快照。
- 远程黑屏：先检查 GDM3 是否跑在 X11、Xorg 是否识别 Dummy、是否存在 GNOME Shell 会话，最后检查 RustDesk 画面捕获。服务 active 不等于画面正常。
- 系统更新或显示变更后失联：使用 SSH/云救援控制台检查 `/var/lib/hdm/pending-rollback` 和 `systemctl status hdm-recovery.timer`。必要时手动执行 `sudo hdm --rollback-pending`。
- 下载故障：菜单 10.6；GPG 签名、磁盘空间、依赖冲突属于停止处理情况，不能禁用签名跳过。
