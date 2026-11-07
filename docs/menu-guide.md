# 完整终端菜单指南

当前保留 **10 个一级菜单、473 个编号/字母菜单条目**。在 SSH 上运行 `sudo hdm`；选项 `0` 返回、`q` 退出；不需要 `whiptail`。

完整的二级、三级菜单树请查看 [`AI_DEVELOPMENT_SPEC.md` §2](AI_DEVELOPMENT_SPEC.md)。程序本身可通过 `hdm --menu-tree` 导出完整条目。

菜单角色：1/3/5 安装；2/4/6 组件更新管理；7 RustDesk 客户端服务器/认证；8 HDM 管理器更新；9 推荐一键安装；10 故障诊断、源管理、日志备份。高级功能的未实现状态见 [`implementation-status.md`](implementation-status.md)。
