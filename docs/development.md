# HDM 开发指南

先阅读 [架构](architecture.md)、[菜单](menu-guide.md)、[验证限制](testing-and-limitations.md)。

1. 菜单结构只修改 `scripts/build-menus-v2.py`，然后生成 `ui/menus.tsv` 和 `ui/menu-targets.tsv`。`ui/actions.sh` 与 `ui/legacy-menus.tsv` 是仍有引用的兼容层，不是可以随意删除的冗余文件。
2. 修改系统状态前须检查发行版与实际组件。停止服务、注销用户、删除软件包等高风险动作必须保留明确确认、快照和失败恢复。
3. 提交前运行：

   ```bash
   python3 scripts/build-menus-v2.py --check
   python3 scripts/verify-menus.py
   python3 scripts/audit-menu-actions.py
   bash tests/run.sh
   git diff --check
   ```

4. 更新 `VERSION`、`CHANGELOG.md`、`release/` 元数据，并遵守 [提交规范](COMMIT_POLICY.md)；当前版本发布按一条中文版本提交处理。
5. 单元测试不代表真实 RustDesk 登录前、锁屏或重启验收。不要添加未实现的空目录、虚构的镜像备用包、复制 README 或过期开发规格书。

Windows 发布工具保留在 `tools/`；不得为简化维护而强制覆盖其他分支或清空历史 Release。
