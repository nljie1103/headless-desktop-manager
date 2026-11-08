# HDM v5 架构与文件职责

`install.sh` 安装管理器，并将经过验证的版本放到 `/opt/hdm/releases/vX.Y.Z`；`/opt/hdm/current` 指向当前版本。更新 HDM 不会自动重启桌面或 RustDesk。

| 路径 | 职责 |
|---|---|
| `core/` | 平台、安全检测、系统软件包、可信下载、备份与回滚 |
| `modules/` | 显示、桌面、会话、RustDesk、部署、诊断及更新功能 |
| `ui/` | 七节点菜单、动作路由、旧动作兼容层 |
| `scripts/` | 菜单生成/校验、RustDesk TOML 更新、诊断导出 |
| `config/` | 实际使用的默认值、兼容性和下载地址 |
| `templates/systemd/` | 显示配置定时恢复服务与计时器（必须保留） |
| `tests/` | 自动化回归与安全测试，不等于远端 ARM64 实机验收 |

## 唯一菜单定义

**`scripts/build-menus-v2.py` 是唯一菜单结构源**。运行该脚本生成 `ui/menus.tsv` 和 `ui/menu-targets.tsv`；这两份是运行期索引，不是额外的菜单源。`ui/menu.sh` 是终端导航，`ui/actions_v2.sh` 是当前动作。

`ui/legacy-menus.tsv` 和 `ui/actions.sh` 是受测试保护的旧动作兼容层：当前菜单仍调用其中的少数动作，**不能因为文件名带 legacy 就删除**。菜单 1–7 与首页七节点状态线轴逐一对应，8 为 HDM 管理。

## 配置与下载

默认值见 `config/defaults.conf`；可信仓库地址见 `config/github-endpoints.conf`。系统服务配置由模块验证后生成，不靠过期模板覆盖系统文件。依赖优先使用可信系统包管理器；RustDesk 可从官方 Releases 获取经过摘要校验的资产。目前没有真正发布过独立的 HDM RustDesk 镜像备用包，故不在仓库保存空白的备用包清单。没有可验证资产时仍安全拒绝。

## 判断边界

DRM/KMS 是内核显示层；Xorg 实现 X11；LightDM/GDM3 是登录管理器；XFCE/MATE/GNOME 是桌面。绿色只说明对应**本地检查条件**满足；未登录的 Greeter 不等于用户会话，RustDesk 服务运行也不证明远程控制、锁屏或冷启动恢复已实测成功。

[菜单指南](menu-guide.md) · [开发指南](development.md) · [测试限制](testing-and-limitations.md)
