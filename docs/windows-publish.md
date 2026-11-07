# Windows 一键推送到 GitHub

## 本次版本：v0.3.1

本工具只用于项目维护者已明确授权的 HDM 仓库；**不会 force push，不修改 GitHub 凭证，不覆盖仓库中 ZIP 未包含的其他文件**。

1. 下载 `headless-desktop-manager-v0.3.1.zip`，放入 Windows 当前账户 `Downloads` 文件夹。
2. 在 CMD 粘贴并回车（**只有一行，不需要输入 YES 或手填 commit**）：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\headless-desktop-manager-v0.3.1.zip') -DestinationPath (Join-Path $env:TEMP 'hdm-upload-v0.3.1') -Force" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\hdm-upload-v0.3.1\headless-desktop-manager\tools\publish-windows.ps1"
```

脚本自动克隆 `https://github.com/nljie1103/headless-desktop-manager.git` 的 `main`，合并新版项目文件，显示真实 staged diff 概况，并从 `VERSION` 和 `release/COMMIT_SUMMARY.txt` 拼装 `v0.3.1 真实变更摘要` 后自动提交推送。

> **仍需要的前置条件**：电脑已经安装 Git for Windows、配置 `git config --global user.name` 和 `git config --global user.email`，并已有仓库的写入权限及 Git Credential Manager 认证。凭证过期时 GitHub 可能仍会显示登录窗口，这不属于 HDM 的重复确认。用户授权已在执行这条命令时给出。

### 保护机制

- 远端版本 >= ZIP 版本时拒绝覆盖（防止下载旧 ZIP 误回退）。
- 不允许 force push、自动推送 tag 或跳过远端分支保护。
- 不会删除远端当前存在而新版 ZIP 没有包含的文件。
- 仅从 `release/COMMIT_SUMMARY.txt` 生成当前版本的 commit；维护者必须保证该摘要对应真实差异。
- 固定目标仓库，不将文件传到其他 GitHub 仓库。
- 不打开分页器（`--no-pager`），避免窗口停在冒号。
- 使用 `.gitattributes` 保持 `.sh` 为 LF，避免 Windows 上传后 Linux 出现 `^M`。

### 失败时如何处理

若 Git 返回 `non-fast-forward`，说明有人刚推送了新提交；脚本不会覆盖，请重新检查当前仓库状态后发布新版。其他错误可在终端原样复制给开发者，不需要分享任何 Token 或密码。

> 自动上传脚本尚未在你本次 Windows 环境中完成 v0.3.1 实机运行；需观察首次实际使用结果。
