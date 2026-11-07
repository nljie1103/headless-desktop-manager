# 架构说明

项目入口 `install.sh` → `/opt/hdm/releases/vX.Y.Z` → `/opt/hdm/current` → `/usr/local/bin/hdm`。

`hdm.sh` 只从本地预先审核的源码模块加载 `core/*.sh`、`modules/*/*.sh` 和 `ui/*.sh`，不在运行时 `source` 从网络获得的代码。`ui/menus.tsv` 由开发期 `scripts/generate-menus.py` 从批准的 AI 规格书 §2 生成。未知菜单叶子会明确提示“暂不支持/实验性”，不会误执行。

公共底层：`core/common.sh`（系统识别与确认）、`core/packages.sh`（APT 与来源故障分类）、`core/downloader.sh`（GitHub API 与 SHA256）、`core/backup.sh`（快照与系统级回滚）。各 provider 放在 `modules`。一键安装只是按顺序调用相同 provider。

正式架构仍以 `docs/AI_DEVELOPMENT_SPEC.md` 为最高需求基线。
