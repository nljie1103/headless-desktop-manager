# 开发者指南

运行 `bash tests/run.sh` 和 `bash hdm.sh --self-test`。菜单源规范在 `docs/AI_DEVELOPMENT_SPEC.md` §2，修改规范后运行 `python3 scripts/generate-menus.py`、`python3 scripts/verify-menus.py`。

所有潜在破坏性操作必须：系统/架构检测、真实现状检查、展示变更、确认、备份、执行、验证、日志、恢复。运行时不得 `eval` 任意字符串，也不能把外部 TOML/manifest 当脚本 source。保持所有功能默认不自动关闭 SSH、不取消锁屏、不禁用包签名。

真实 GNOME、RustDesk 和 Windows 发布验收需在对应机器上执行，CI 语法检查不能代替。
