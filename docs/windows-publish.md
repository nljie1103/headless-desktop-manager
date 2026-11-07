# Windows 一键上传 GitHub（v0.1.1）

**仓库：** https://github.com/nljie1103/headless-desktop-manager

上一版 v0.1.0 的 `publish-windows.ps1` 在 Windows PowerShell 5.1 上可能被错误地按本地代码页解释，导致中文乱码和 `TerminatorExpectedAtEndOfString`。v0.1.1 改用 **UTF-8 BOM + 纯 ASCII PowerShell 源文件**，并修复 Git 参数传递问题。

1. 把 `headless-desktop-manager-v0.1.1.zip` 放在 Windows `Downloads` 下载目录（不用手动解压）。
2. 打开 **CMD 命令提示符**，执行以下完整一行：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\headless-desktop-manager-v0.1.1.zip') -DestinationPath (Join-Path $env:TEMP 'hdm-upload-v0.1.1') -Force" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\hdm-upload-v0.1.1\headless-desktop-manager\tools\publish-windows.ps1"
```

也可以将独立的 `HDM_一键上传GitHub_v0.1.1.cmd` 放到下载目录并双击。

3. 同意检查 Git / 安装 Git 的提示（若未安装），以及克隆和查看变更的操作。
4. 上传脚本打印 Git 暂存区实际文件清单，让用户核对。
5. 按提示**输入真实改动摘要，不包括版本号**。例如首次导入：`首次导入 HDM 项目并修复 Windows PowerShell 5.1 上传脚本解析问题`。
6. 脚本自动形成提交标题 `v0.1.1 <你的摘要>`，要求再次确认后提交并推送到 `main`。如果远程已有保护规则或权限不足，脚本会提示失败，不会强制推送。

**注意：** `git commit` 只能记录真实的代码差异，不能仅靠版本号证明变更正确；开发者必须核查暂存区差异。未来仓库的所有提交消息都必须遵循 [`docs/COMMIT_POLICY.md`](COMMIT_POLICY.md) 并通过 GitHub Actions 验证。不要提交密码和个人访问令牌。

推送成功后，可使用 Linux 开发版入口：

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
sudo hdm
```

请先在可回滚的 Ubuntu 24.04 测试机上验证，不要直接用于生产。
