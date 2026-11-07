# 安装说明

1. 备份云 VM、确认 SSH 及云控制台均可使用。
2. Ubuntu 24.04 x86_64 下载 `install.sh`，检查来源，执行 `sudo bash install.sh`。
3. 安装器会部署 HDM 管理器到 `/opt/hdm`，不会直接更改已有桌面。
4. `sudo hdm` → 9 → 9.1 → 9.1.6 执行推荐组合。
5. 通过菜单 7 配置服务器与访问认证，菜单 10 检查运行情况。使用另一台设备实际连接。
6. 图形显示验证完成后必须按提示执行 `sudo hdm --confirm-display`；否则系统级回滚计时器会撤销图形配置。

主仓库：https://github.com/nljie1103/headless-desktop-manager
