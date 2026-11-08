# HDM Git 提交与版本规范（强制）

## 1. 提交标题格式

每一次 Git 提交的第一行必须严格遵循：

```text
vMAJOR.MINOR.PATCH 具体且真实的变更内容
```

正则形式：`^v[0-9]+\.[0-9]+\.[0-9]+ [^\s].+`。版本号必须在第一位，后面至少一个空格与可核验的变更描述。**不能以 `fix`、`update` 或只有版本号作为整个提交说明。**

**实际存在的例子：**

- `v0.1.0 初始实现 HDM 模块化框架、菜单导航与测试`（历史基础版）
- `v0.1.1 改善初始版本的跨平台兼容性与提交验证`（格式参考）

**以下仅是未来开发的格式范例，不代表功能已经实现：**

- `v0.1.2 修复 GNOME 虚拟显示器分辨率切换失败`

不合格例子：`Update files`、`Fix bugs`、`v0.1.1 修复xxx`、`v0.1.1 日常更新`。

## 2. 真实性原则

1. 先审查 `git diff --cached --stat`、`git diff --cached --name-status`，重要变更进一步审查完整 diff；再拟定提交标题。
2. 标题描述本次**实际代码或文档变化**，不可提前宣称待验证功能已完成。
3. 行为改变、修复、菜单调整、文档或安装器改动分别明确写出。非功能性更新不能写成“修复远程桌面黑屏”。
4. 发生用户可见改动时维护 `CHANGELOG.md`，发布时同步更新 `VERSION`。
5. 同一预发布版本允许多次提交，但每条提交都以当前开发版本为前缀；发布标签 `vX.Y.Z` 仅在实际发布时创建。
6. GitHub Pull Request 应使用 **Squash merge**，合并提交标题同样必须遵循此规则，避免自动生成无版本前缀的 `Merge pull request ...`。

## 3. 公开变更摘要与内部维护操作分离

- `release/COMMIT_SUMMARY.txt` 是对外可见的 Git 提交标题内容：仅描述本版项目功能、体验、缺陷修复或文档变化，不包含 Windows 上传、Git 推送、打标签、CI 工作流等内部发布操作。
- `release/RELEASE_TITLE.txt` 是 GitHub Release 的**唯一标题**，格式为 `vX.Y.Z · 简明功能主题`；`VERSION` 与发布 Tag 必须一致。
- `release/RELEASE_NOTES.md` 是 GitHub Release **正文**：仅列具体可核验的改动及真实限制；禁止再次写版本标题、版本号或内部发布步骤。
- Windows 维护工具保留在 `tools/`，不再为已淘汰的上传 ZIP 保留额外教程。
- `scripts/validate-public-release.py` 在测试和正式 Release 构建前检查以上规范。
- 已发布的 Git commit 标题不能不改写历史就直接修改；对于历史 Release 可安全更改其展示标题和正文，保留原标签/提交不变。

## 4. 自动检查的边界

`tools/publish-windows.ps1` 自动从 `VERSION` 读取版本前缀，打印真实修改清单，要求开发者填写真正的更改说明。

`scripts/check-commit-messages.py` 和 GitHub Actions 负责检查格式、空泛占位词等；**机器无法仅凭提交标题证明技术修复的真实性**，必须由开发者复核代码差异、测试结果与更新记录。

## 5. Windows 自动发布模式（v0.2.0 起）

维护者已授权每次在自己的 Windows 本地运行一条上传命令来发布交付 ZIP，**不需要再次输入 YES，也不需要填写 commit 标题**。

- 自动提交标题来自 `VERSION` + `release/COMMIT_SUMMARY.txt`。
- `COMMIT_SUMMARY.txt` 必须由实际修改代码的开发者如实撰写、与 `CHANGELOG.md` 一致。
- 上传前脚本打印实际 staged diff 统计；禁止 `--force`、无差异提交以及旧版覆盖新版。
- Windows 上 Git 既有的账户授权可以复用；若 GitHub 登录凭证失效，系统认证仍可能需要用户完成。
- 自动化只能检查格式、差异和基本版本关系，不能单独证明功能已经实机通过。
