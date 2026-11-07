# Contributing

1. 阅读 `docs/AI_DEVELOPMENT_SPEC.md` 与 `docs/testing-and-limitations.md`。
2. 保持 GNOME 优先目标及全部 10 个主菜单；菜单新编号修改后运行 `python3 scripts/generate-menus.py`。
3. 提交前运行 `bash tests/run.sh`、`bash hdm.sh --self-test`。
4. 包、模块或可用性变更要追加 CHANGELOG 并更新明确的测试状态。
5. 不要提交密码、私钥、token 或没有合法再分发授权的第三方二进制包。
6. **所有 commit 必须以 `vX.Y.Z` 开头并明确描述实际改动**；详见 `docs/COMMIT_POLICY.md`。提交前运行 `python3 scripts/check-commit-messages.py --message "v0.1.1 修复 Windows 上传脚本乱码"` 检查格式。避免 `Update files` 或其他空泛消息。
