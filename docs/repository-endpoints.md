# Headless Desktop Manager — GitHub 仓库地址与下载更新规范

> **规范版本**：1.0.1 · 2026-11-07  
> **正式仓库**：https://github.com/nljie1103/headless-desktop-manager  
> **用途**：放入 GitHub 仓库的 `docs/repository-endpoints.md`，供安装器、HDM 更新器、GitHub 备用包模块、AI 编程助手统一引用。  
> **与开发规格书关系**：本文件是 `docs/AI_DEVELOPMENT_SPEC.md` §4.6 的独立副本，发生冲突时以最新批准的规格书与真实 Release 为准。

## 仓库地址、下载接口与更新地址

> **仓库已创建并核实**：`https://github.com/nljie1103/headless-desktop-manager`。截至 2026-11-07 查询时该仓库尚为空仓库，**没有可用的 `install.sh`、Git 分支文件、Release、二进制备份包或版本清单**。本节确定未来代码应使用的**地址规则**，不是声称这些资源现在可以下载。
>
> **单一权威配置**：仓库所有模块统一读取 `config/github-endpoints.conf`；禁止 `install.sh`、`modules/updater/`、`modules/rustdesk/`、`core/downloader.sh` 各自手写不同的 `OWNER/REPO` 或硬编码旧仓库名。

### 4.6.1 已确认可作为项目标识的链接

| 用途 | 地址 | 现时状态/用途 |
|---|---|---|
| 官方项目主页 | `https://github.com/nljie1103/headless-desktop-manager` | **已确认存在** |
| Git 克隆地址 | `https://github.com/nljie1103/headless-desktop-manager.git` | 已确定地址；空仓库需先提交源码 |
| Issues | `https://github.com/nljie1103/headless-desktop-manager/issues` | 后续反馈与故障跟踪 |
| Releases 页面 | `https://github.com/nljie1103/headless-desktop-manager/releases` | 发布入口；目前不得声称有可下载包 |
| GitHub Release API | `https://api.github.com/repos/nljie1103/headless-desktop-manager/releases` | 发行版元数据接口（受 API 限流和网络状态影响） |
| 指定标签 Release API | `https://api.github.com/repos/nljie1103/headless-desktop-manager/releases/tags/<TAG>` | `<TAG>` 必须来自验证过的发布清单 |
| 安装脚本原始文件 | `https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh` | **待创建文件和默认分支**，仅适合开发说明/受控测试；不能宣传目前可用 |
| 按固定 Git tag 读取脚本 | `https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/<TAG>/install.sh` | `<TAG>` 为已发布且经验证的 tag；优先使用固定版本而不是 `main` |
| 指定 Release 资产 | `https://github.com/nljie1103/headless-desktop-manager/releases/download/<TAG>/<ASSET>` | 仅在对应 Release 和资产真实存在后才可执行下载 |

`<TAG>` 与 `<ASSET>` 是**代码模板参数**，不是实际下载地址。运行时不可直接保留尖括号；必须按经过校验的 manifest 或 GitHub API 响应解析、验证并替换。严禁拼接来自不可信终端输入的任意 URL 作为 root 安装来源。

### 4.6.2 URL 常量、使用方及配置文件（确定规范）

建议新建 `config/github-endpoints.conf`，内容为**可信的只读静态常量**；外部数据清单另用结构化解析，不能 `source` 从网络下载的脚本：

```bash
# HDM 项目官方仓库（供所有模块统一引用）
HDM_GITHUB_OWNER='nljie1103'
HDM_GITHUB_REPO='headless-desktop-manager'
HDM_REPO_URL='https://github.com/nljie1103/headless-desktop-manager'
HDM_GIT_CLONE_URL='https://github.com/nljie1103/headless-desktop-manager.git'
HDM_GITHUB_API_BASE='https://api.github.com/repos/nljie1103/headless-desktop-manager'
HDM_RAW_BASE='https://raw.githubusercontent.com/nljie1103/headless-desktop-manager'
HDM_RELEASES_URL='https://github.com/nljie1103/headless-desktop-manager/releases'
HDM_RELEASE_ASSET_BASE='https://github.com/nljie1103/headless-desktop-manager/releases/download'
# 第三方上游（RustDesk 官方），不要与 HDM 镜像地址混淆
RUSTDESK_UPSTREAM_RELEASES_URL='https://github.com/rustdesk/rustdesk/releases'
RUSTDESK_UPSTREAM_API_BASE='https://api.github.com/repos/rustdesk/rustdesk'
```

| 模块/功能 | 使用方式 |
|---|---|
| `install.sh` / `bootstrap/download-core.sh` | 使用固定 `<TAG>` 的 HDM `install.sh` / `hdm-vX.Y.Z.tar.gz`；校验独立信任锚及签名 |
| `modules/updater/check.sh` | 调用 HDM GitHub Releases API；只识别项目本体的稳定 tag；不得把备用包发布误识别成最新 HDM |
| `modules/updater/update.sh` | 通过 API 获取经允许的 `browser_download_url`，校验主机、tag、文件名、签名/哈希后下载 |
| `modules/rustdesk/download.sh` | 系统可信包管理器 → RustDesk 官方 Releases → HDM 已验证镜像资产 |
| `core/mirror-manager.sh` | 只处理有明确 manifest、来源和适配约束的镜像；GitHub 站点失效不等于存在可用的独立备份 |
| `modules/diagnostics/network-check.sh` | 分别检测系统包源、RustDesk 官方上游、HDM 仓库及 Releases 资产地址 |
| `ui/source-menu.sh` / 菜单 10.6 | 展示当前真实生效来源、最后校验结果、备用包库存与回退策略 |

### 4.6.3 Release 标签、资产命名及混淆防护

**建议的发布命名约定（未来实施；当前未发布）：**

```text
项目本体正式版：  v1.0.0                  （示例 tag）
项目源码/运行包： hdm-v1.0.0.tar.gz      （示例 asset）
启动安装器：      install.sh             （示例 asset）
哈希清单：        SHA256SUMS            （示例 asset）
签名/认证材料：   SHA256SUMS.sig        （示例 asset，格式需选定并公示）
备用软件包发行：  mirror-2026-11         （示例 tag，单独标识为非项目本体版本）
RustDesk 镜像：   rustdesk-<VERSION>-ubuntu24.04-amd64.deb（示例命名）
```

- 检查更新不能只依赖 GitHub `/releases/latest`：它可能不符合项目对推荐通道的定义，尤其当仓库同时发布镜像包时。应使用经验证的发布索引或 Release API **按 tag/类型筛选**，只接受 `vMAJOR.MINOR.PATCH` 的本体稳定发布；过滤 `mirror-*`。
- 备用包建议在独立 `mirror-*` Release 中存储，避免与项目版本资产混杂；如使用 prerelease 标记，应记录这表示“备份资产而非可执行项目更新”，不代表备份文件可跳过校验。
- 由 GitHub API 返回的资产地址必须限制在允许的域名与发布归属范围内，明确是否有 HTTPS 重定向、下载失败、404/403/429/5xx、空文件、哈希不符的处理逻辑。
- 任何发布前必须核对**真实上传的资产名**与文档中的规则，不得让文档/脚本猜测一个未上传的文件名。

### 4.6.4 用户安装入口：开发阶段与正式阶段分开

**开发阶段（仓库提交 `main/install.sh` 后才可用，不是正式推荐的一键安装方式）：**

```bash
curl -fsSLo hdm-install.sh \
  https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh
# 审阅脚本与来源后再执行
sudo bash hdm-install.sh
```

**正式发布阶段（示例：必须先创建 v1.0.0 Release 并确实上传 install.sh）：**

```bash
curl -fsSLo hdm-install.sh \
  https://github.com/nljie1103/headless-desktop-manager/releases/download/v1.0.0/install.sh
# 核对版本发布公告、可验证签名/校验值后执行
sudo bash hdm-install.sh
```

固定版本入口是首选。要提供“始终安装最新稳定版”的便捷入口，应先通过**可信的更新元数据**识别版本并校验资产，不能把 `latest` 的返回内容直接交给 `sudo bash`。安装器的**初始信任锚**应由仓库随代码发布并在独立可信渠道公开验证值；同一个被攻击下载来源同时返回代码和 SHA-256 值不能提供独立的身份认证。

### 4.6.5 GitHub 备用安装包的地址解析示例

```text
HDM 发布列表：
https://github.com/nljie1103/headless-desktop-manager/releases

具体备用资产 URL 模板（仅示例，不是现存下载文件）：
https://github.com/nljie1103/headless-desktop-manager/releases/download/mirror-2026-11/rustdesk-<VERSION>-ubuntu24.04-amd64.deb
```

实际下载必须通过 `packages/manifests/*.tsv` 指定的 release tag + asset name（或通过已验证的 Release API 索引）定位；核对系统发行版、版本、CPU 架构、软件许可证、可信来源、SHA256 和签名。**当 RustDesk 官方 Releases 与 HDM Releases 都因同一 GitHub 网络故障不可达时，GitHub 镜像不构成独立的故障备援**；此时允许使用已验证的本地缓存，后续可增加独立镜像站，但须另行安全审查。

### 4.6.6 仓库迁移、改名和地址集中管理

- 仓库所有者、仓库名或默认分支改变时，仅维护 `config/github-endpoints.conf`（及签名信任策略与相关文档），不要全仓库搜索硬编码 URL 才能迁移。
- 默认分支 `main` 仅用于开发期源码浏览，正式安装与更新依赖**固定 Release tag 和签名清单**，不依赖分支名。
- GitHub 可能自动重定向已改名仓库，但 HDM 不应把重定向当作长期可用性保证；需检测并更新规范地址。
- 用户设置的 RustDesk **ID/中继服务器地址**与上面 HDM GitHub 仓库地址完全不同，分别存储、验证和显示，不得互相覆盖。
- 菜单 8 更新的是 HDM 项目本身；菜单 6 更新 RustDesk；菜单 10.6 控制备用软件源；菜单 7 只配置 RustDesk 连接服务器，不能通过菜单 7 修改 HDM 的程序下载地址。

### 4.6.7 下载/更新/备用包的端到端验收

- [ ] 全部 1～10 菜单及模块均能显示并使用同一个正式仓库标识 `nljie1103/headless-desktop-manager`。
- [ ] 构造 `v1.0.0` 项目本体 Release 与 `mirror-2026-11` 备份包 Release，测试更新器不会混淆。
- [ ] 新版下载失败、资产不存在或 API 限流，保持已安装 HDM 正常可用。
- [ ] 更新仅下载真实存在的 Release 资产；拒绝冒用域名、非法 tag、路径穿越、错误签名及哈希不符资产。
- [ ] 未发布 `install.sh` 的情况下，README 不展示“可立即使用”的一键下载承诺。
- [ ] RustDesk 官方源失败 → 有已验证镜像才使用 HDM 备用包；两个 GitHub 源都失败时识别共同故障并尝试已验证缓存。
- [ ] 备用包只有 manifest 而没有实际资产时必须报“不可用”，绝不能伪装为安装成功。

---


## v0.3.4 更新通道

- 发布者：Windows 推送成功后，使用 Git 为对应 VERSION 创建 `vX.Y.Z` 注释 tag 并推送；版本不变化且无文件差异时可补推缺失 tag。
- 预览发布：GitHub Release 工作流生成 `hdm-vX.Y.Z.tar.gz`，菜单 8 从 GitHub Releases API 获取资产 SHA256 下载并验证。
- 预览版：菜单 8 通过 GitHub API 查询 main 的不可变提交 SHA，再用该 SHA 从 codeload 下载源码包；校验路径、类型、版本与启动自检。SHA 不代表独立发布者签名。
- 仅升级 HDM 代码；保留 GNOME、RustDesk 以及 HDM 的配置、缓存和旧版目录。
