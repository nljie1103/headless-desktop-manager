# 完整终端菜单指南

当前保留 **10 个一级菜单、473 个编号/字母菜单条目**。在 SSH 上运行 `sudo hdm`；选项 `0` 返回、`q` 退出；不需要 `whiptail`。

完整的二级、三级菜单树请查看 [`AI_DEVELOPMENT_SPEC.md` §2](AI_DEVELOPMENT_SPEC.md)。程序本身可通过 `hdm --menu-tree` 导出完整条目。

菜单角色：1/3/5 安装；2/4/6 组件更新管理；7 RustDesk 客户端服务器/认证；8 HDM 管理器更新；9 推荐一键安装；10 故障诊断、源管理、日志备份。高级功能的未实现状态见 [`implementation-status.md`](implementation-status.md)。


## v0.3.0 已接通的菜单功能

- `9.1.6`：推荐 GNOME + Dummy + RustDesk 安装（首次或缺失阶段续装）。
- `9.1.7`、`9.6.1`、`9.7.1`：查看记录状态与实际组件检测。
- `9.7.2`：检查现有事务，确认后仅续装缺失或失败的阶段。
- `10.10.1`、`10.10.7`：只读中文诊断与针对性修复建议。

详细执行顺序、事务格式和限制见 [`resumable-install.md`](resumable-install.md)。
