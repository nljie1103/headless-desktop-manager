> **v4.4.0 优先说明**：本文件含历史的“先安装替代桌面再卸载旧桌面”限制，现已被用户选择的卸载顺序取代。保留 APT 依赖保护和一次确认；允许先卸载再安装，前提是操作人员理解活动图形通道可能立即中断，并拥有独立 SSH/云控制台。最新规范以 [菜单指南](menu-guide.md) 为准。

> **当前菜单规范（v4.3.0）**：此前 10 项主菜单为历史设计。现在主菜单采用七节点桌面链路对应的 1–7 阶段，加第 8 项 HDM 脚本管理。所有原动作保存在 `ui/legacy-menus.tsv` 并通过 `ui/menu-targets.tsv` 显式路由，新的实现及导航以 [菜单指南](menu-guide.md) 为准。不要从本历史规格重新生成生产菜单。

> **最新需求决策（2026-11-08，v4.1.0）**：HDM 定位为便携、按需的 Linux 图形桌面管理脚本，不以 GNOME 登录前无人值守为硬性目标。Ubuntu 26 GNOME Wayland-only 环境优先推荐 XFCE + X11 + LightDM + RustDesk；GNOME 和 MATE 均可由用户选装；已有桌面保留，切换登录管理器须明确确认。以下历史菜单规格及旧默认方案仅保留供设计追溯，发生冲突时以本决策和当前源码为准。

# Headless Desktop Manager（HDM）AI 开发规格书

> **项目**：Headless Desktop Manager（HDM）／Linux 无显示器远程桌面一键部署与管理工具
> **文档版本**：1.0.1（已绑定正式 GitHub 仓库的需求基线草案）
> **界面文案规则**：§2 的长菜单文字用于功能定义；实际终端菜单使用 `ui/menus.tsv` 中的简短标题，不应把功能解释、发布阶段或兼容风险堆入选项名称。详细检查留在执行和诊断中。
> **整理日期**：2026-11-07
> **正式仓库**：https://github.com/nljie1103/headless-desktop-manager
> **仓库状态**：已发布 v4.x；历史设计稿中的“空仓库/默认 GNOME/固定旧版本”属于历史要求，以最新变更说明与仓库源码为准
> **主要语言**：简体中文；代码、文件名、CLI 接口使用英文
> **目标读者**：接手项目的 AI 编程助手、开发者、测试者、维护者
> **性质**：产品需求 + 完整交互菜单 + GitHub 仓库结构 + 架构约束 + 技术实施规范 + 验收清单
> **重要声明**：本文件是**开发规格书**，不是已测试通过的安装方案；所有 GNOME/Xorg/RustDesk 配合的正确性均须在目标云服务器实机验证。

---

## 0. 给接手开发的 AI：先读此节

### 0.1 最优先的不可变约束（Must）

1. 最终用户通过**一个 `curl` 下载的 `.sh` 入口**安装 HDM，后续通过 `sudo hdm`（必要时 `hdm` 提示提权）打开终端数字菜单；无需学习或逐一手动敲安装命令。
2. **保留本文规定的 1～10 一级菜单及完整二级/三级菜单**。实现时可增加状态信息、帮助与明确的安全确认，不要擅自删除、重命名或合并用户要求的关键入口。所有菜单必须有可执行处理函数或明确标为“暂不支持/实验性”，不允许“选择后什么都不做”。
3. **桌面按图形协议及实际使用目标推荐**。Ubuntu 25.10+ GNOME Wayland-only 主机若需要标准 RustDesk 登录前的传统 X11 路径，优先推荐 XFCE + LightDM；GNOME 与 MATE 保持可选。不得擅自卸载现有桌面或强制切换登录管理器。
4. 虚拟显示器菜单必须支持 **Xorg Dummy、Xvfb、VKMS** 三条技术路径的可发现性和适配检测；正式默认目标为 **Ubuntu 24.04 + GNOME (X11) + Xorg Dummy + RustDesk**。对未验证的 Xvfb/VKMS 组合用“实验性/待验证”状态，不能虚假宣称可用。
5. **首选系统原生包管理器**：Ubuntu/Debian → APT；Fedora/RHEL 新版 → DNF；确属旧版环境才使用 YUM。优先使用用户现有的可信软件源，不轻易修改系统全局源。
6. 当源下载失败时：分类诊断 → 可信发行版/官方镜像重试 → 对已备份且校验过的适用软件包尝试 **HDM GitHub Releases 备用安装包**。GitHub 备份应真正包含经过授权、记录来源和校验信息的二进制文件，不能只是一个失效时仍跳回上游的 URL；但**不承诺一个 GitHub `.deb` 就能代替 GNOME 的完整依赖仓库**。
7. 具备 **安装、管理/更新、切换、版本回滚、诊断修复、脚本自更新、配置备份和日志**。显示服务 / GNOME / RustDesk 改动前必须评估远程断连风险，保持 SSH 与云控制台恢复路径。
8. **安全默认**：不关闭 SSH、不默认禁用防火墙、不默认启用桌面自动登录、不默认取消锁屏、不明文写 RustDesk 永久密码、不在日志中记录密码或秘钥、不随意 `chmod 444` 锁死配置、不为绕过错误关闭包签名验证。
9. 先交付一个**可测、稳定的 Ubuntu 24.04 amd64 最小闭环**，然后扩展 Ubuntu arm64、Debian、Fedora/RHEL；不能为“多系统支持”牺牲第一目标的稳定性。
10. **正式 GitHub 仓库已创建**：`https://github.com/nljie1103/headless-desktop-manager`，但目前为空仓库。当前只指定设计，不代表已经完成代码、发布安装包或通过远程重启验证；AI 必须用真实测试结果更新进度，不得假报成功。

### 0.2 约束优先级与需求状态

- **P0 / 必须**：首次安装入口、完整菜单导航、协议适配桌面推荐、Dummy 安装、RustDesk 安装/基础配置、可靠诊断、来源和哈希校验、状态识别、失败处理、备份、受控回滚、原生包管理器优先。
- **仓库 P0**：绑定 `nljie1103/headless-desktop-manager`；由单一配置统一供应 HDM 下载入口、菜单 8 更新源、菜单 10.6 GitHub 备用包；实际发版前不得在 README 宣称不存在的下载地址已可用。
- **P1 / 应实现**：RustDesk 自更新/回滚、HDM 自更新/回滚、桌面管理与升级、分辨率修改、软件源管理、故障修复向导、安装中断续做。
- **P2 / 分阶段或实验**：Xvfb 与 GNOME 的完整联动、VKMS 与 GNOME 的完整联动、XFCE/MATE 登录前远控验收、多发行版、多架构、预发布通道、自动定时更新。
- 规格书中出现的**菜单项表示目标信息架构**，不意味着 V1.0 必须将所有 P2 完成并声称稳定。未实现项需有解释、支持计划或“实验”标签。
- 对用户要求有疑义时，保留已有设计，优先实现可逆、可验证、最小影响的版本，并在文档 `docs/decisions/` 记录决策，不在代码中隐含改变需求。

### 0.3 不在当前范围内

- 不安装/管理 RustDesk 自建 `hbbs` / `hbbr` **服务端**：菜单 7 配置的是**被控端 RustDesk 客户端**如何连接已有 ID/中继服务器。
- 不替代云平台的快照、备份、救援控制台；HDM 的回滚主要覆盖自有配置与管理器版本，系统包回滚有条件限制。
- 不承诺无 GPU 云服务器的 GNOME Shell 一定支持任意虚拟显示方案；需实验验证。
- 不默认进行整个发行版升级、内核升级或自动重启。

---

## 1. 产品说明与使用体验

### 1.1 使用场景

用户通过 SSH 管理没有显示器的 Linux 云服务器，希望通过 RustDesk 远程访问真实 GNOME 图形会话。以往需要自己安装 Xorg、显示驱动、GDM3、GNOME、RustDesk、配置文件和 systemd 等，HDM 必须通过一个菜单式工具统一完成这些工作，并提供维护与恢复机制。

### 1.2 目标操作流程

```text
SSH 登录 Ubuntu 24.04 云服务器
  ↓
curl -fsSLo install.sh <HDM 官方固定版本安装器 URL>
  ↓
校验下载内容、显示来源和版本；用户确认后 sudo bash install.sh
  ↓
安装 HDM 到 /opt/hdm ，注册 /usr/local/bin/hdm
  ↓
sudo hdm
  ↓
首次使用建议 9 → 9.1 完整推荐组合
  ↓
自动检测→预览变更→备份→安装 Xorg Dummy→安装 GNOME→安装 RustDesk
  ↓
选择 7 配置 ID/中继服务器、公钥、永久密码
  ↓
选择 10 完整体检→如需重启则保留安装事务并重启后验证
  ↓
用户从另一台设备实际连接成功并确认画面、输入和重启恢复
```

**关于“一个 curl 直接执行”**：用户要求的是极简操作；正式 README 同时提供便捷入口和更安全的“下载、查看、校验、执行”方式。不得强制用户运行未经校验的 `curl | bash`，不要以安全为由取消一键体验。正式版可提供下列**单行命令**（**以下地址绑定正式仓库，但文件只有在 v1.0.0 Release 确实上传后才存在**；发布前不得宣传可用，且安装器必须验证后续下载的签名和哈希）：

```bash
curl -fsSLo hdm-install.sh https://github.com/nljie1103/headless-desktop-manager/releases/download/v1.0.0/install.sh && sudo bash hdm-install.sh
```

维护者必须同时公布独立可验证的安装器哈希、签名或可信发布通道，供用户审阅校验；一键命令是便利入口，不能被宣传为“网络脚本天然安全”。

### 1.3 基础 UI 约定

- 纯 SSH 终端可用；优先 Bash + `printf/read`，有 `whiptail` 时可以提供增强交互，但**不能把 whiptail 作为安装器首先必须安装成功的前置条件**。
- 只接受明确菜单编号；`0` 返回上一级，主菜单的 `0` 退出；`q` 安全退出；`Ctrl+C` 请求取消（关键事务需要清理/恢复）；输入无效不退出。
- 主菜单始终显示系统、架构、HDM 版本、当前显示方案、桌面环境、RustDesk 版本和检测状态，不能采用文档里的固定示例值当实时结果。
- 安装中显示步骤、百分比或可观测进度、当前来源、日志位置；不能用假的百分比。
- 凡影响系统配置或可能中断现有远程控制的行为都要**显示变更预览并确认**。默认“否”，对高风险变更可要求输入明确确认词。
- 所有可选择项要注明“推荐/已验证/实验/不支持/已安装/可更新/待配置/异常”等状态。
- 中文为首发界面语言；界面字符串隔离以预留英文翻译。

### 1.4 首屏参考（数字菜单）

```text
╔══════════════════════════════════════════════════════════╗
║ Headless Desktop Manager                                 ║
║ Linux 无显示器远程桌面一键部署工具  HDM vX.Y.Z            ║
╠══════════════════════════════════════════════════════════╣
║ 系统：Ubuntu 24.04 LTS   架构：x86_64                    ║
║ 虚拟显示：未安装   桌面：未安装   RustDesk：未安装        ║
╠══════════════════════════════════════════════════════════╣
║  1. 安装虚拟显示器           Xorg Dummy / Xvfb / VKMS    ║
║  2. 管理 / 更新虚拟显示器    分辨率 / 驱动 / 切换 / 回滚   ║
║  3. 安装桌面环境             GNOME / XFCE / MATE         ║
║  4. 管理 / 更新桌面环境      更新 / 切换 / 会话管理       ║
║  5. 安装 RustDesk 客户端     版本 / 架构 / 来源           ║
║  6. 更新 RustDesk 客户端     升级 / 降级 / 回滚           ║
║  7. 配置 ID / 中继服务器     地址 / 公钥 / 访问密码       ║
║  8. 更新管理脚本             HDM Release / 回滚          ║
║  9. 一键安装推荐组合         GNOME + Dummy + RustDesk    ║
║ 10. 系统检测 / 故障修复      黑屏 / 服务 / 源 / 日志      ║
║  0. 退出                                                ║
╚══════════════════════════════════════════════════════════╝
请选择 [0-10]：
```

---

## 2. 完整菜单树（必须保留，包含二级及三级菜单）

> **阅读方法**：`1.1.2` 表示“主菜单 1 → 二级 1 → 三级 2”。有些项目是直接执行动作、有些是配置向导。所有菜单默认还包含 `0. 返回上一级`；主菜单有 `0. 退出`。下述子项目是**菜单项**，不是 GitHub 文件目录。

### 2.1 主菜单 1 — 安装虚拟显示器

```text
[1] 安装虚拟显示器
  1.1 安装 Xorg Dummy [GNOME 推荐]
      1.1.1 自动安装推荐配置
      1.1.2 自定义安装配置
            A. 选择分辨率
               1280×720 / 1600×900 / 1920×1080 [默认] / 2560×1440 / 自定义
            B. 设置色深（默认 24-bit，其他值须检测支持）
            C. 选择是否配置为启动默认显示
            D. 预览 Xorg 变更
            E. 保存并开始安装
      1.1.3 查看依赖与预计磁盘占用
      1.1.4 检测当前 Xorg 环境
  1.2 安装 Xvfb [实验]
      1.2.1 自动安装 Xvfb
      1.2.2 选择 DISPLAY 编号（默认建议 :99；检查冲突）
      1.2.3 设置分辨率
      1.2.4 设置色深
      1.2.5 配置 systemd 自启（仅在适用的独立显示会话中）
      1.2.6 测试 Xvfb 运行
      1.2.7 查看 GNOME 兼容性和风险说明
  1.3 安装 VKMS [实验/需内核支持]
      1.3.1 检查内核 VKMS 能力
      1.3.2 加载 VKMS 内核模块
      1.3.3 设置开机加载
      1.3.4 检查 DRM 虚拟显示设备
      1.3.5 检查 Xorg / GNOME 适配
      1.3.6 撤销本次 VKMS 设置
  1.4 自动推荐显示方案
      1.4.1 执行环境检测及生成推荐结果
      1.4.2 查看推荐依据和兼容矩阵
      1.4.3 确认后安装推荐方案
  1.5 查看 Xorg Dummy / Xvfb / VKMS 的区别
      1.5.1 工作原理
      1.5.2 GNOME / RustDesk 兼容状态
      1.5.3 系统资源与运维差异
```

**动作规则**：优先检测已有 X/桌面/GDM/显卡/包版本；通过包管理器获取 Dummy 或 Xvfb；VKMS 优先检测内核，不假定存在独立通用软件包；备份所要修改的 Xorg/GDM 配置、测试屏幕存在并区分“驱动安装成功”和“GNOME 会话成功”。选用 A 方案失败时**不得静默切换 B 方案**。

### 2.2 主菜单 2 — 管理 / 更新虚拟显示器

```text
[2] 虚拟显示器管理
  2.1 查看显示环境详细状态
      2.1.1 驱动与软件包版本
      2.1.2 运行中的 X server / DISPLAY / 会话使用情况
      2.1.3 分辨率与日志
  2.2 更新当前虚拟显示驱动
      2.2.1 检查更新
      2.2.2 更新当前驱动与必要依赖
      2.2.3 重新安装当前驱动
      2.2.4 查看已安装版本
      2.2.5 查看可用版本
      2.2.6 查看更新日志
  2.3 切换虚拟显示方案
      2.3.1 切换到 Xorg Dummy
      2.3.2 切换到 Xvfb
      2.3.3 切换到 VKMS
      2.3.4 查看切换风险 / 恢复方式
      2.3.5 恢复上一次成功方案
  2.4 修改分辨率 / 色深
      2.4.1 1280×720
      2.4.2 1600×900
      2.4.3 1920×1080
      2.4.4 2560×1440
      2.4.5 自定义分辨率
      2.4.6 查看当前及可用分辨率
      2.4.7 恢复默认分辨率
      2.4.8 色深设置（仅兼容时开放）
  2.5 启动 / 停止 / 重启相关服务
      2.5.1 查看受影响的服务
      2.5.2 启动
      2.5.3 停止 [高风险确认]
      2.5.4 重启 [高风险确认]
  2.6 配置开机启动
      2.6.1 查看当前自启状态
      2.6.2 启用
      2.6.3 禁用 [可能失联]
  2.7 重新安装 / 修复驱动
      2.7.1 自动诊断后定向修复
      2.7.2 重装相同版本
  2.8 卸载虚拟显示方案
      2.8.1 卸载当前方案 [警告]
      2.8.2 卸载已安装但未使用的方案
      2.8.3 仅移除 HDM 创建的配置
      2.8.4 预览删除范围
  2.9 恢复之前的显示配置
      2.9.1 查看历史快照
      2.9.2 恢复选定快照
      2.9.3 验证恢复结果
```

**动作规则**：Dummy/Xvfb 更新应由相应包管理器处理；VKMS 随内核，不把“更新 VKMS”实现成无法解释的内核自动升级。切换前必须保存最后可用配置，保留 SSH/云控制台；如果可行使用与图形会话解耦的定时恢复机制，并要求用户在新显示会话验证后确认保留。

### 2.3 主菜单 3 — 安装桌面环境

```text
[3] 安装桌面环境
  3.1 安装 GNOME [默认/首要支持]
      3.1.1 安装完整 Ubuntu GNOME 桌面（Ubuntu 下优先 ubuntu-desktop）
      3.1.2 安装精简 GNOME（由发行版提供的匹配包）
      3.1.3 仅补齐缺失的 GNOME 组件
      3.1.4 安装 / 配置 GDM3
      3.1.5 配置 GNOME X11 会话
      3.1.6 查看安装包和预计磁盘占用
      3.1.7 检测 GNOME 安装环境
  3.2 安装 XFCE [可选]
      3.2.1 标准 XFCE
      3.2.2 最小化 XFCE
      3.2.3 LightDM 配置
      3.2.4 X11 会话检查
      3.2.5 依赖检查
      3.2.6 执行安装
  3.3 安装 MATE [可选]
      3.3.1 标准 MATE
      3.3.2 最小化 MATE
      3.3.3 LightDM 配置
      3.3.4 X11 会话检查
      3.3.5 依赖检查
      3.3.6 执行安装
  3.4 自动推荐桌面
      3.4.1 检测资源与系统环境
      3.4.2 默认 GNOME 并解释资源限制
      3.4.3 用户主动选择其他桌面
  3.5 查看桌面环境对比
      3.5.1 功能与资源对比
      3.5.2 与虚拟显示方案兼容矩阵
  3.6 检测现有桌面
      3.6.1 已装桌面和包
      3.6.2 当前会话、显示管理器及状态
```

**动作规则**：GNOME 是第一等公民；若虚拟显示器尚未就绪，弹出“1. 先安装推荐 Dummy；2. 只安装 GNOME，稍后配置；0. 返回”。GDM3 负责标准 GNOME 会话；不把 `gnome-session & rustdesk` 作为默认 systemd 启动方案。GNOME 软件包成功安装 ≠ GNOME 会话可用。

### 2.4 主菜单 4 — 管理 / 更新桌面环境

```text
[4] 桌面环境管理
  4.1 查看桌面环境状态
      4.1.1 已装桌面与版本
      4.1.2 当前会话 / GDM3 / X11 状态
  4.2 更新当前桌面
      4.2.1 检查 GNOME（或当前桌面）相关更新
      4.2.2 更新桌面及必要依赖
      4.2.3 修复缺失依赖
      4.2.4 重装桌面组件
      4.2.5 查看更新历史
      4.2.6 查看软件包版本
  4.3 切换桌面环境
      4.3.1 切换到 GNOME
      4.3.2 切换到 XFCE
      4.3.3 切换到 MATE
      4.3.4 查看已安装桌面
      4.3.5 恢复之前的桌面
  4.4 管理登录管理器
      4.4.1 查看当前 GDM3/LightDM 状态
      4.4.2 配置 GDM3
      4.4.3 配置 LightDM
      4.4.4 切换默认登录管理器
      4.4.5 开启 / 关闭图形登录服务 [高风险]
      4.4.6 恢复默认设置
  4.5 管理图形会话
      4.5.1 查看 X11 / Wayland 会话
      4.5.2 配置默认 GNOME X11 会话
      4.5.3 配置桌面启动方式
      4.5.4 检查 D-Bus / 用户会话
      4.5.5 重启图形会话 [高风险]
      4.5.6 查看图形会话日志
  4.6 GNOME 专项配置
      4.6.1 检查 GNOME Shell
      4.6.2 检查软件渲染支持
      4.6.3 查看分辨率
      4.6.4 屏幕锁定 / 空闲设置 [安全提示]
      4.6.5 登录管理器与登录行为 [默认不自动登录]
      4.6.6 检查 RustDesk 捕获条件
      4.6.7 恢复 GNOME 默认配置
  4.7 修复桌面环境
      4.7.1 自动诊断后修复
      4.7.2 仅补齐缺失软件包
      4.7.3 恢复会话/显示管理器配置
  4.8 卸载桌面环境
      4.8.1 预览依赖与删除计划
      4.8.2 卸载指定桌面 [高风险]
      4.8.3 清理 HDM 自建配置
  4.9 恢复之前的桌面配置
      4.9.1 查看快照
      4.9.2 选择并恢复
      4.9.3 验证恢复结果
```

**动作规则**：不强制执行发行版全面升级。切换桌面前先安装并验证新目标，保留旧环境，绝不在唯一可用的图形通道上未经确认地卸载当前桌面。GNOME X11 会话可用性和 GDM3 登录界面捕获需要分别测试。

### 2.5 主菜单 5 — 安装 RustDesk 客户端

```text
[5] 安装 RustDesk 客户端
  5.1 自动安装 HDM 推荐稳定版本
      5.1.1 检测 RustDesk / 系统 / 架构 / 可用来源
      5.1.2 查看安装计划并确认
      5.1.3 安装并检查服务、查询设备 ID
      5.1.4 安装后快捷入口：配置服务器 / 设密码 / 连通检测
  5.2 安装官方最新正式版本
      5.2.1 实时查询官方 Stable Release
      5.2.2 兼容性提示、用户确认、下载安装
  5.3 选择指定历史版本
      5.3.1 查看官方可用版本
      5.3.2 查看 HDM 已验证版本
      5.3.3 手动输入版本
      5.3.4 从本地缓存选择
  5.4 从本地安装包安装
      5.4.1 输入/选择路径
      5.4.2 验证文件类型、架构、校验及依赖
      5.4.3 用户确认安装
  5.5 从 HDM GitHub 备用包安装
      5.5.1 下载验证过的 RustDesk 包
      5.5.2 查看备用版本
      5.5.3 查看哈希、发布源和许可信息
      5.5.4 验证本地缓存
      5.5.5 清理无效缓存
  5.6 查看 RustDesk 版本列表
      5.6.1 已安装版本
      5.6.2 HDM 已验证版本
      5.6.3 官方正式与可用历史版本
  5.7 检查安装条件
      5.7.1 软件源/网络/架构
      5.7.2 虚拟显示器及桌面环境
      5.7.3 systemd 和软件依赖
  5.8 查看软件包下载来源
      5.8.1 当前源策略
      5.8.2 上游与备用资产
      5.8.3 签名/校验信息
```

**动作规则**：优先检查是否存在受信任的系统软件包仓库中的可用 RustDesk；默认发行版仓库没有时不把“包不存在”算源故障，改查 RustDesk 官方 Release，再查 HDM 的已验证备份包。自动识别 Debian `.deb`、Fedora/RHEL `.rpm` 及 cpu 架构，禁止按用户输入拼 URL 直接执行脚本。成功安装后 RustDesk 原生 systemd 服务优先，不能无故关闭；安装完成必须显示真实获取的 ID 或说明查询失败。

### 2.6 主菜单 6 — 更新 RustDesk 客户端

```text
[6] RustDesk 更新管理
  6.1 检查更新
      6.1.1 当前安装版本
      6.1.2 HDM 已验证推荐版本
      6.1.3 官方最新 Stable（实时查询）
      6.1.4 查看版本变化 / 风险
  6.2 升级到 HDM 推荐版本
      6.2.1 预览、备份、下载安装、验证
  6.3 升级到官方最新正式版
      6.3.1 兼容性提示、预览、确认后安装
  6.4 选择特定版本安装
      6.4.1 查看列表
      6.4.2 输入版本
      6.4.3 检查可安装性并执行
  6.5 回滚到上一个版本
      6.5.1 上次成功版本
      6.5.2 本地缓存版本
      6.5.3 官方历史版本
      6.5.4 查看回滚记录
  6.6 重新安装当前版本
      6.6.1 预览影响并执行
  6.7 查看版本更新日志
      6.7.1 本地版本历史
      6.7.2 官方 Release Notes
  6.8 更新设置
      6.8.1 版本通道：HDM 已验证 / 官方正式 / 预发布[实验]
      6.8.2 检查频率：手动 / 打开 HDM 时检查
      6.8.3 缓存策略：保留当前和上次成功 / 全留 / 清理
      6.8.4 更新后验证设置
      6.8.5 恢复默认
  6.9 查看版本与安装历史
      6.9.1 更新记录
      6.9.2 失败与恢复记录
  6.10 卸载 RustDesk
      6.10.1 预览卸载范围
      6.10.2 保留 / 清除客户端配置（默认保留）
      6.10.3 确认并执行
```

**动作规则**：更新前备份受影响配置并保存可用安装包；旧版可能与新版配置不兼容，因此回滚是“尽力恢复 + 严格验证”，不能保证一定成功。更新 RustDesk **不等于**更新 HDM 或整个 Linux 系统。

### 2.7 主菜单 7 — 配置 ID / 中继服务器

```text
[7] RustDesk 服务器与安全配置
  7.1 配置自建 ID / 中继服务器
      7.1.1 输入 ID 服务器主机 / 端口（例：21116；允许自定义）
      7.1.2 输入中继服务器主机 / 端口（例：21117；允许自定义）
      7.1.3 输入服务器公钥
      7.1.4 端口使用默认值 / 自定义值
      7.1.5 检查主机和网络条件
      7.1.6 预览（公钥必要时遮蔽）
      7.1.7 备份并保存应用
      7.1.8 查询设备 ID / 提示外部连接验证
  7.2 恢复 RustDesk 默认服务器
      7.2.1 预览并确认
  7.3 查看当前服务器配置
      7.3.1 有效配置来源、当前目标、注册状态
  7.4 修改 ID 服务器
      7.4.1 修改主机 / 端口
  7.5 修改中继服务器
      7.5.1 修改主机 / 端口
  7.6 修改服务器公钥
      7.6.1 输入并验证格式
  7.7 设置 / 修改无人值守密码
      7.7.1 设置新永久访问密码
      7.7.2 修改永久访问密码
      7.7.3 查看配置状态（绝不显示明文）
      7.7.4 查看安全设置说明
  7.8 查看 / 设置本机设备 ID
      7.8.1 查看当前 ID
      7.8.2 复制 ID（终端支持时）
      7.8.3 尝试设置自定义 ID [检查支持和冲突]
      7.8.4 刷新 ID
      7.8.5 查看注册状态
  7.9 测试服务器连接
      7.9.1 DNS 解析
      7.9.2 ID 服务器 TCP 可达
      7.9.3 ID 服务相关 UDP 条件
      7.9.4 中继 TCP 可达
      7.9.5 公钥配置检查
      7.9.6 RustDesk 服务/注册状态
      7.9.7 全面连接诊断
  7.10 导入 / 导出服务器配置
      7.10.1 导入 RustDesk 支持的配置格式
      7.10.2 导出已脱敏的可移植配置
      7.10.3 校验导入文件
  7.11 备份 / 恢复服务器配置
      7.11.1 查看备份
      7.11.2 创建受保护备份
      7.11.3 恢复指定备份
```

**动作规则**：永久密码要隐藏输入并二次确认，不写 HDM 明文配置，不出现在日志或导出的诊断包。RustDesk 文档提供 `--password`、`--get-id`、`--set-id` 等参数，但 CLI 参数可能对本地进程列表可见；实现必须评估进程参数暴露并使用当前版本支持的安全设置方式/最小暴露窗口，做不到无泄露时明确风险并要求确认。不得直接把明文 `password = 'xxx'` 写进 TOML 假装生效。RustDesk 配置文件可能位于不同用户/服务上下文，必须探测**实际运行服务使用的配置**，不凭固定 `/home/ubuntu` 路径猜测。

### 2.8 主菜单 8 — 更新管理脚本（HDM）

```text
[8] HDM 脚本更新管理
  8.1 检查 HDM 更新
      8.1.1 查询当前与稳定版 Release
  8.2 更新到最新稳定版
      8.2.1 查看变更说明
      8.2.2 下载并验证签名/校验
      8.2.3 备份旧版本，原子切换
      8.2.4 自检失败恢复旧版本
  8.3 查看历史发布版本
      8.3.1 已验证的历史版本
  8.4 安装指定 HDM 版本
      8.4.1 选择版本并校验兼容性
  8.5 回滚到上一个 HDM 版本
      8.5.1 查看旧版本
      8.5.2 回滚并自检
  8.6 更新功能模块
      8.6.1 检查全部模块
      8.6.2 虚拟显示器模块
      8.6.3 桌面环境模块
      8.6.4 RustDesk 模块
      8.6.5 软件源管理模块
      8.6.6 诊断模块
      8.6.7 恢复匹配当前 HDM 版本的模块
  8.7 查看更新日志
      8.7.1 HDM ChangeLog
  8.8 管理更新设置
      8.8.1 Stable / Preview [预览通道可选]
      8.8.2 手动 / 启动时检查
      8.8.3 缓存及旧版本保留
  8.9 检查脚本完整性
      8.9.1 校验已安装文件
      8.9.2 校验模块版本一致性
  8.10 恢复默认配置
      8.10.1 预览重置范围并确认
```

**动作规则**：HDM 主程序和模块应由**同一 Release 的匹配版本**提供；不能热更新一个尚不兼容的模块并混用主程序。先将新版本完整放进版本目录、校验并运行自检，然后切换 `/opt/hdm/current`；失败恢复旧版。不把菜单 8 当作 RustDesk、GNOME 或系统软件升级入口。

### 2.9 主菜单 9 — 一键安装推荐组合

```text
[9] 一键安装向导
  9.1 一键安装完整推荐组合 [默认]
      9.1.1 环境体检与已装组件识别
      9.1.2 默认：GNOME + Xorg Dummy + RustDesk
      9.1.3 选择分辨率：1280×720 / 1920×1080 / 2560×1440
      9.1.4 服务器设置：稍后配置 [默认] / 公共服务器 / 自建服务器
      9.1.5 预览安装计划、下载来源、风险与备份范围
      9.1.6 确认并执行
      9.1.7 安装结束状态/重启验证/外部连接验证
  9.2 选择其他桌面组合
      9.2.1 GNOME + Xorg Dummy + RustDesk [推荐]
      9.2.2 GNOME + Xvfb + RustDesk [实验]
      9.2.3 GNOME + VKMS + RustDesk [实验]
      9.2.4 XFCE + Xorg Dummy + RustDesk
      9.2.5 XFCE + Xvfb + RustDesk
      9.2.6 MATE + Xorg Dummy + RustDesk
      9.2.7 自定义组合
  9.3 自定义一键安装方案
      9.3.1 选择显示：Dummy / Xvfb / VKMS
      9.3.2 选择桌面：GNOME / XFCE / MATE
      9.3.3 选择 RustDesk：HDM 推荐 / 最新 Stable / 指定版
      9.3.4 选择分辨率
      9.3.5 选择软件源策略
      9.3.6 配置服务器
      9.3.7 预览安装计划
      9.3.8 确认安装
  9.4 仅安装缺失组件
      9.4.1 比较当前安装状态与目标组合
      9.4.2 预览最小变更计划
      9.4.3 执行缺失项安装
  9.5 查看推荐方案与兼容性
      9.5.1 检查内存/CPU/架构/内核/图形环境
      9.5.2 显示经验证组合及缺口
  9.6 查看上次安装记录
      9.6.1 查看步骤、日志、快照
  9.7 恢复上次中断的安装
      9.7.1 检查旧事务状态
      9.7.2 选择安全重试 / 恢复 / 中止
```

**动作规则**：一键安装只**编排**菜单 1、3、5、7 已实现的底层操作，不能另写一套不一致的安装命令。默认先检测是否存在桌面/驱动/ RustDesk，已安装且健康的组件尽量不动。顺序：环境体检→软件源准备→Dummy→GNOME/GDM3/X11→RustDesk→服务器/认证（可跳过）→联合验证。需要重启时留下事务标记，开机后通过 HDM 或安全恢复任务继续验证。云服务器冷启动后的实际远程画面确认必须由外部客户端人工确认，不能软件自测替代。

### 2.10 主菜单 10 — 系统检测 / 故障修复

```text
[10] 系统检测 / 故障修复
  10.1 一键完整系统体检
       10.1.1 运行全部检测
       10.1.2 查看详细报告
       10.1.3 进入针对性修复
       10.1.4 再次检测
       10.1.5 导出脱敏报告
  10.2 虚拟显示器故障检测
       10.2.1 驱动
       10.2.2 Xorg / Xvfb 服务
       10.2.3 DISPLAY 与 X server 可连接性
       10.2.4 分辨率
       10.2.5 显示服务日志
       10.2.6 兼容性
       10.2.7 定向修复
       10.2.8 恢复上次成功配置
  10.3 GNOME / 桌面环境故障检测
       10.3.1 已安装包完整性
       10.3.2 GDM3 / LightDM
       10.3.3 X11 / Wayland 会话
       10.3.4 D-Bus / 用户会话
       10.3.5 GNOME Shell
       10.3.6 软件渲染
       10.3.7 启动日志
       10.3.8 定向修复配置
       10.3.9 补装缺失组件
       10.3.10 恢复初始配置
  10.4 RustDesk 故障检测
       10.4.1 安装包/版本
       10.4.2 systemd 服务
       10.4.3 设备 ID
       10.4.4 ID/Relay 配置
       10.4.5 永久密码配置状态（不读明文）
       10.4.6 画面捕获条件
       10.4.7 RustDesk 日志
       10.4.8 修复服务
       10.4.9 重装当前版本
       10.4.10 回滚上一版本
  10.5 网络 / 连接诊断
       10.5.1 DNS
       10.5.2 当前软件源
       10.5.3 GitHub
       10.5.4 ID 服务器
       10.5.5 中继服务器
       10.5.6 公钥配置
       10.5.7 本机网络信息
       10.5.8 完整网络诊断
  10.6 软件源管理（用户特别指定的核心功能）
       10.6.1 检测当前软件源
       10.6.2 自动寻找可信备用源
       10.6.3 手动选择软件源
              A. 当前系统默认软件源
              B. 官方备用镜像
              C. 经验证的第三方发行版镜像
              D. HDM GitHub Releases 备用包（仅适用组件）
              E. 返回自动模式
       10.6.4 管理 GitHub 备用包
              A. 查看 RustDesk 备份版本
              B. 查看显示驱动备份版本
              C. 检查发行版/架构/依赖匹配
              D. 下载到本地缓存
              E. 校验 SHA-256 / 签名
              F. 清理过期或无效缓存
              G. 查看上游来源与许可证
       10.6.5 下载失败切换策略
              A. 仅当前系统源
              B. 系统源 → 官方备用镜像
              C. 系统源 → 可信镜像 → GitHub（适用时）[推荐]
              D. 每次切换前询问
              E. 超时和重试次数
              F. 恢复默认
       10.6.6 检查软件包完整性
       10.6.7 清理下载缓存
       10.6.8 查看软件源切换历史
       10.6.9 恢复系统原始软件源
  10.7 系统服务管理
       10.7.1 全部 HDM 相关服务
       10.7.2 Xorg/Xvfb 相关服务
       10.7.3 GDM3/LightDM
       10.7.4 RustDesk
       10.7.5 重启指定服务 [确认]
       10.7.6 设置开机自启
       10.7.7 检查依赖
       10.7.8 错误日志
  10.8 日志查看 / 导出
       10.8.1 HDM 安装日志
       10.8.2 显示器日志
       10.8.3 GNOME / GDM3 日志
       10.8.4 RustDesk 日志
       10.8.5 软件源切换日志
       10.8.6 更新/回滚日志
       10.8.7 导出脱敏诊断包
       10.8.8 清理过期日志
  10.9 备份 / 恢复配置
       10.9.1 新建配置快照
       10.9.2 查看历史快照
       10.9.3 恢复指定快照
       10.9.4 恢复虚拟显示配置
       10.9.5 恢复 GNOME / 登录配置
       10.9.6 恢复 RustDesk 配置
       10.9.7 恢复 HDM 设置
       10.9.8 删除旧备份
  10.10 自动诊断与建议修复
        10.10.1 扫描常见故障
        10.10.2 修复虚拟显示配置
        10.10.3 修复 GNOME 会话
        10.10.4 修复 RustDesk 服务
        10.10.5 修复缺失软件依赖
        10.10.6 恢复最后成功配置
        10.10.7 仅给建议、不修改
  10.11 查看系统环境详情
        10.11.1 系统/内核/架构
        10.11.2 CPU / 内存 / 磁盘
        10.11.3 虚拟化 / GPU / 内核模块
        10.11.4 图形环境 / 软件包管理器
```

**动作规则**：检测输出区分 `[通过]`、`[异常]`、`[待配置]`、`[未验证]`、`[实验]`；比如 TCP 通不等于 RustDesk 注册成功，RustDesk 服务在运行不等于 GNOME 可被捕获。自动修复只能执行规则确定且可预览的方案，不能对未知问题盲目重装桌面。导出诊断包必须脱敏。

### 2.11 各菜单的角色分工（避免实现重复）

| 主菜单 | 唯一职责 | 复用谁的底层接口 |
|---|---|---|
| 1 | 首次显示驱动安装 | display provider、package manager |
| 2 | 已装显示驱动管理 | 同一个 display provider，含 rollback |
| 3 | 首次桌面安装 | desktop provider、session/login adapter |
| 4 | 已装桌面管理 | 同一个 desktop provider，含 rollback |
| 5 | 首次 RustDesk 安装 | rustdesk provider、downloader |
| 6 | RustDesk 版本管理 | 同一个 rustdesk provider、state |
| 7 | RustDesk 客户端服务器/安全配置 | rustdesk config provider |
| 8 | **HDM 自身**更新 | updater、release verifier |
| 9 | 编排完整部署 | 依序调用 1、3、5、7 底层能力 |
| 10 | 诊断、源、服务、日志、恢复 | 所有 provider 的检测/恢复接口 |

---
## 3. GitHub 仓库完整目录树（保留此前约定，包含子目录）

> 这部分是**项目源代码目录树**；与第 2 章的**用户终端菜单树**是两种不同结构，不可混淆。`install.sh` 是唯一公开的首次安装入口，`hdm.sh` 是本地管理入口。下列文件的创建可按迭代分阶段完成；新建项目不必第一天创建大量空壳文件，但最终结构及功能归属按此设计。已经讨论过的目录命名原则上保留。

```text
headless-desktop-manager/
│
├── install.sh                    # curl 下载的一键安装入口
├── hdm.sh                        # HDM 菜单程序入口
├── VERSION                       # HDM 版本
├── README.md                     # 英文主页
├── README.zh-CN.md               # 中文主页
├── LICENSE                       # 开源许可证
├── CHANGELOG.md                  # 版本记录
├── CONTRIBUTING.md               # 贡献指南
├── SECURITY.md                   # 安全报告渠道
│
├── bootstrap/                    # 初始安装器
│   ├── setup.sh                  # 安装 HDM
│   ├── detect-system.sh          # 发行版 / 架构识别
│   ├── check-requirements.sh     # root / 网络 / 空间
│   ├── download-core.sh          # 版本化模块下载和校验
│   └── register-command.sh       # 注册 sudo hdm
│
├── core/                         # 通用核心
│   ├── main.sh                   # 初始化与调度
│   ├── config.sh                 # 配置读写
│   ├── logger.sh                 # 结构化日志
│   ├── error-handler.sh          # 错误处理
│   ├── downloader.sh             # 通用 HTTP 下载
│   ├── checksum.sh               # hash / 签名校验
│   ├── package-manager.sh        # apt / dnf / yum 抽象
│   ├── mirror-manager.sh         # 可信镜像及失败切换
│   ├── version-manager.sh        # 版本比较
│   ├── dependency-manager.sh     # 软件包依赖检测
│   ├── backup.sh                 # 快照
│   ├── rollback.sh               # 回滚
│   ├── state.sh                  # 实际状态 + 事务状态
│   ├── service-manager.sh        # systemd 操作
│   ├── user-session.sh           # 用户图形会话
│   └── lock.sh                   # 防止重入并发
│
├── adapters/                     # 不同 Linux 发行版
│   ├── ubuntu/
│   │   ├── packages.sh           # Ubuntu 包名映射
│   │   ├── sources.sh            # APT 源适配
│   │   └── services.sh           # GDM3 / systemd 差异
│   ├── debian/
│   │   ├── packages.sh
│   │   ├── sources.sh
│   │   └── services.sh
│   ├── fedora/
│   │   ├── packages.sh
│   │   ├── sources.sh
│   │   └── services.sh
│   └── rhel/
│       ├── packages.sh
│       ├── sources.sh
│       └── services.sh
│
├── modules/                      # 业务功能模块
│   ├── display/                  # 对应菜单 1、2
│   │   ├── install.sh
│   │   ├── update.sh
│   │   ├── detect.sh
│   │   ├── resolution.sh
│   │   ├── test.sh
│   │   ├── xorg-dummy/
│   │   │   ├── install.sh
│   │   │   ├── configure.sh
│   │   │   ├── verify.sh
│   │   │   └── uninstall.sh
│   │   ├── xvfb/
│   │   │   ├── install.sh
│   │   │   ├── configure.sh
│   │   │   ├── verify.sh
│   │   │   └── uninstall.sh
│   │   └── vkms/
│   │       ├── install.sh
│   │       ├── configure.sh
│   │       ├── verify.sh
│   │       └── uninstall.sh
│   │
│   ├── desktop/                  # 对应菜单 3、4
│   │   ├── install.sh
│   │   ├── update.sh
│   │   ├── detect.sh
│   │   ├── switch.sh
│   │   ├── session.sh
│   │   ├── login-manager.sh
│   │   ├── gnome/
│   │   │   ├── install.sh
│   │   │   ├── configure.sh
│   │   │   ├── verify.sh
│   │   │   └── uninstall.sh
│   │   ├── xfce/
│   │   │   ├── install.sh
│   │   │   ├── configure.sh
│   │   │   ├── verify.sh
│   │   │   └── uninstall.sh
│   │   └── mate/
│   │       ├── install.sh
│   │       ├── configure.sh
│   │       ├── verify.sh
│   │       └── uninstall.sh
│   │
│   ├── rustdesk/                 # 对应菜单 5、6、7
│   │   ├── install.sh
│   │   ├── update.sh
│   │   ├── detect.sh
│   │   ├── download.sh
│   │   ├── server-config.sh
│   │   ├── security.sh
│   │   ├── service.sh
│   │   ├── verify.sh
│   │   ├── rollback.sh
│   │   └── uninstall.sh
│   │
│   ├── updater/                  # 对应菜单 8
│   │   ├── check.sh
│   │   ├── update.sh
│   │   ├── verify.sh
│   │   └── rollback.sh
│   │
│   ├── quick-install/            # 对应菜单 9
│   │   ├── plan.sh
│   │   ├── install.sh
│   │   └── verify.sh
│   │
│   └── diagnostics/              # 对应菜单 10
│       ├── run-all.sh
│       ├── display-check.sh
│       ├── desktop-check.sh
│       ├── rustdesk-check.sh
│       ├── network-check.sh
│       ├── service-check.sh
│       ├── logs.sh
│       └── repair.sh
│
├── ui/                           # 终端 UI 与菜单渲染
│   ├── main-menu.sh
│   ├── display-menu.sh
│   ├── desktop-menu.sh
│   ├── rustdesk-menu.sh
│   ├── update-menu.sh
│   ├── source-menu.sh
│   ├── dialogs.sh
│   ├── progress.sh
│   └── colors.sh
│
├── config/                       # 默认配置/兼容数据
│   ├── defaults.conf
│   ├── github-endpoints.conf         # 已确定的官方 GitHub / API / Release 常量
│   ├── compatibility.tsv
│   ├── packages.tsv
│   ├── sources.tsv
│   ├── versions.tsv
│   └── presets/
│       ├── gnome.conf
│       ├── xfce.conf
│       └── mate.conf
│
├── templates/                    # 系统配置模板
│   ├── xorg/
│   │   ├── dummy.conf.template
│   │   └── resolutions.conf
│   ├── systemd/
│   │   ├── xvfb.service.template
│   │   └── desktop-session.service.template
│   ├── gdm/
│   │   └── custom.conf.template
│   ├── lightdm/
│   │   └── lightdm.conf.template
│   └── rustdesk/
│       └── server-config.template
│
├── packages/                     # 备用包清单/元数据，非大二进制仓库
│   ├── README.md
│   ├── manifests/
│   │   ├── ubuntu-24.04-amd64.tsv
│   │   ├── ubuntu-24.04-arm64.tsv
│   │   ├── debian-amd64.tsv
│   │   └── fedora-x86_64.tsv
│   ├── checksums/
│   │   └── SHA256SUMS
│   └── metadata/
│       ├── upstream-urls.tsv
│       ├── licenses.tsv
│       └── release-mapping.tsv
│
├── scripts/                      # 开发和发布工具
│   ├── build-release.sh
│   ├── sync-upstream.sh
│   ├── generate-checksums.sh
│   ├── validate-assets.sh
│   └── package-release.sh
│
├── tests/
│   ├── unit/
│   │   ├── test-system.sh
│   │   ├── test-sources.sh
│   │   ├── test-versions.sh
│   │   └── test-config.sh
│   ├── integration/
│   │   ├── test-display.sh
│   │   ├── test-desktop.sh
│   │   └── test-rustdesk.sh
│   └── fixtures/
│       ├── ubuntu-os-release
│       └── sample-manifest.tsv
│
├── .github/
│   ├── workflows/
│   │   ├── shellcheck.yml
│   │   ├── tests.yml
│   │   ├── release.yml
│   │   └── sync-packages.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   └── feature_request.yml
│   └── pull_request_template.md
│
└── docs/
    ├── installation.md
    ├── menu-guide.md
    ├── gnome-guide.md
    ├── display-guide.md
    ├── rustdesk-guide.md
    ├── mirror-policy.md
    ├── troubleshooting.md
    ├── architecture.md
    ├── development.md
    ├── repository-endpoints.md      # 开发与发布下载/更新地址约定
    ├── AI_DEVELOPMENT_SPEC.md      # 本规格书在仓库内的推荐位置（新增）
    └── decisions/                # 重要技术决策记录（新增）
        └── README.md
```

### 3.1 核心代码归属约定

- `ui/*.sh`：只负责渲染和输入验证，不直接写系统配置。
- `modules/*`：业务能力的 `detect/install/configure/verify/update/rollback/uninstall`；能从菜单和一键安装两种入口调用。
- `core/package-manager.sh`：包管理器抽象，封装 `query`, `install`, `upgrade`, `reinstall`, `remove`，不让每个业务模块重复写 `apt` 命令。
- `core/downloader.sh` + `core/mirror-manager.sh`：处理网络下载、来源可信度、超时和失败切换；**不得混淆包管理器安装和 GitHub 下载模式**。
- `core/state.sh`：状态读取应以真实系统检测为准；事务记录用于断点恢复，不能作为“已安装”唯一证据。
- `core/backup.sh` + `core/rollback.sh`：系统文件备份、事务变更集、恢复路径；不能声称包管理器能自动恢复系统所有依赖。
- `adapters/`：不同发行版的包名、服务名、目录差异；暂未实现的发行版明确拒绝，不能冒险套用 Ubuntu 逻辑。
- `config/compatibility.tsv`：显式记录**OS + 版本 + 架构 + 驱动 + 桌面 + RustDesk** 组合的 `verified/experimental/unsupported/untested`，且须带测试证据。
- `.github/workflows/sync-packages.yml`：仅自动**发现/校验/草拟**上游备份，不能在未经测试后直接把新版本推为推荐稳定版。
- `config/github-endpoints.conf`：HDM 正式仓库、GitHub API、Raw、Release 下载基址的唯一配置来源；**详细规范见 §4.6**。
- `docs/repository-endpoints.md`：面向维护者的地址/发布约定（可从 §4.6 同步），避免以后换 AI 接手时还写 `OWNER/REPO`。

### 3.2 安装到用户系统后的目录树

```text
/usr/local/bin/
└── hdm                       # 调用 /opt/hdm/current/hdm.sh

/opt/hdm/
├── current -> releases/vX.Y.Z
└── releases/
    ├── vX.Y.Z/
    │   ├── hdm.sh
    │   ├── core/
    │   ├── modules/
    │   ├── adapters/
    │   ├── ui/
    │   ├── config/
    │   └── templates/
    └── vX.Y.(Z-1)/

/etc/hdm/
├── config.conf
├── sources.conf
└── install.conf

/var/lib/hdm/
├── state/
├── backups/
├── releases/
└── transactions/

/var/cache/hdm/
├── downloads/
└── packages/

/var/log/hdm/
└── hdm.log
```

- 安装脚本应保证符合 Linux 文件系统习惯，并将敏感设置及备份设置为最低必要权限（如仅 root 可读）；日志不包含密码。
- `current` 软链接切换须确认目标已完整解压并校验，更新后保留前一个可启动版本。
- 使用系统目录前检查是否有用户自有文件，**只管理 HDM 创建或明确得到授权修改的文件**。
- 路径为建议，最终落地的变更通过架构决策记录并同步本文件。

---

## 4. 软件源、包管理器与 GitHub 备用包详细规范

### 4.1 安装优先级（分类而不是无脑递归尝试）

**系统组件（GNOME/GDM3/Xorg Dummy/Xvfb）**：

1. 使用检测到的发行版**原有** APT/DNF/YUM 软件源安装指定系统包。
2. 仅在确实属于网络/镜像故障的情况下，查找**经验证且保留发行版签名校验的官方或可信镜像**，优先临时使用而非永久覆盖用户源。
3. 对**少量明确列入备份清单、依赖已满足且版本/架构完全匹配**的驱动包，可尝试 HDM GitHub Releases 中的备用文件。
4. **完整 GNOME** 不能靠散装 `.deb` 脱离系统依赖解析安装；没有可信仓库时应停止并说明解决方法，除非未来实现经过完整签名和测试的离线 APT 仓库快照（P2）。

**RustDesk**：

1. 如果系统当前配置了**可信且版本满足要求**的 RustDesk 软件仓库，优先使用包管理器；如果系统仓库没有包，这不算“源故障”。
2. 无系统仓库包时，使用 RustDesk 官方 GitHub Releases 的受支持构建文件。
3. 官方下载失败，使用 HDM GitHub Releases 同版本、同发行版/架构、经过哈希/来源校验的备用 `.deb` 或 `.rpm`。
4. 支持已验证的本地缓存；严格禁止安装与运行架构不匹配的软件包。

**HDM 自身**：使用 HDM 的**固定版本 GitHub Release** 安装；用已验证、与本地受信任公钥相匹配的签名及校验清单，不可信更新拒绝执行。首次 bootstrap 需要明确设计信任锚，不可只下载“新脚本+新哈希”自说自话。

### 4.2 包管理器适配规则

| 系统 | 推荐包管理器 | 第一阶段 | 必须注意 |
|---|---|---|---|
| Ubuntu 24.04 amd64 | `apt`/`apt-get` | P0 支持 | `ubuntu.sources` deb822 格式，现有源不可盲目覆盖 |
| Ubuntu 24.04 arm64 | `apt` | P2 | 包的架构/URL/图形驱动需单独验证 |
| Debian | `apt` | P2 | 包名/桌面元包/服务默认配置可能不同 |
| Fedora | `dnf` | P2 | 包名、GNOME、SELinux 及视频驱动差异 |
| RHEL 系 | `dnf`，只有旧系统才可能使用 `yum` | P2 | 订阅仓库/额外源/策略与权限差异 |

- 包管理器要保留发行版 GPG 签名验证；**任何签名错误都不允许通过 `--allow-unauthenticated`、`--nogpgcheck` 等选项绕过**。
- `apt update` / 元数据更新必须限制超时和报错分类；对 apt/dpkg 锁占用应提示等待/重新尝试，不强行删除锁文件。
- 不默认执行全系统 `upgrade`/`dist-upgrade`/`autoremove`；影响无关服务的依赖变更应向用户展示。
- 安装时能正确处理非交互式环境，必要的 `DEBIAN_FRONTEND=noninteractive` 必须谨慎；涉及 GDM3/LightDM 选择、服务重启仍要在 HDM 界面先获得选择及确认。

### 4.3 错误分类与允许回退方式

| 错误 | 是否自动换源 | 对用户显示 |
|---|---:|---|
| DNS/网络超时、502/503、镜像临时不可用 | 是（受信任范围内） | 已尝试来源、下一备用、重试次数 |
| 特定镜像文件缺失且官方镜像可用 | 可 | 包版本和镜像同步差异 |
| 目标包根本不存在 | 否（转对应产品官方下载逻辑） | “当前系统仓库未提供该包” |
| 哈希不符/签名校验失败 | **否，停止** | 安全错误，删除不可信缓存 |
| 依赖冲突、包不兼容、架构不匹配 | **否，停止** | 依赖信息与可行解决方法 |
| 磁盘不足 / 权限不足 / 损坏的包数据库 | **否，停止** | 明确的故障分类 |
| GitHub API 速率限制 | 可使用已验证本地缓存 | 不要无限重试 |

### 4.4 备用包清单必须记录的字段

`packages/manifests/*.tsv` 每项至少包含：`component, component_version, distribution, release, architecture, package_format, filename, upstream_url, mirror_release_tag, mirror_asset_name, sha256, signer_or_attestation, license, published_at, verified_at, compatibility_status`。

- 每份镜像保留合法再分发所需的许可证/版权信息，尤其不能忽略开源许可证及源代码提供义务。
- 二进制放在 **GitHub Releases** 资产，不要把大量二进制直接提交进 Git 历史；源码仓库保留 manifest、来源、哈希与许可数据。
- 同一备用包应有**原始来源追踪和受信任的清单签名**。SHA-256 只说明下载内容和清单一致，不能代替对清单发布者的身份验证。
- 资产不存在或清单过期时，菜单如实标注“没有可用的 GitHub 备用包”，不能临时改用陌生第三方仓库。
- 创建 GitHub Release 前，校验授权、资产与 manifest；检查 GitHub 发行包体积和 API/下载约束，避免假定平台永远免费、无任何上限。

### 4.5 镜像配置与回滚

1. 保留系统原始源完整备份，连同权限与路径。
2. 如果可以，使用工具层的**临时镜像策略**而不是直接永久替换 `/etc/apt`。
3. 必须修改系统源时先展示原始/目标差异，并让用户确认；Ubuntu 24.04 使用 deb822 `ubuntu.sources` 要保留 `Signed-By` 等签名配置。
4. 切换失败立即恢复原配置；恢复后验证包管理器仍能读取原源。
5. 显示最近来源切换历史，以便定位故障。

## 4.6 正式 GitHub 仓库地址、下载接口与更新地址（已确定，P0）

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

## 5. 核心模块契约与 Bash 编码规范

### 5.1 模块接口约定（拟定）

```bash
# 统一调用语义（示意接口，不代表已实现）
hdm_detect_system                    # 输出标准化 OS/arch/manager 信息
hdm_pkg_query   <package>
hdm_pkg_install <package>            # 软件源策略由 core 接管
hdm_download_verified <asset-id>     # manifest + hash + origin 验证
hdm_display_detect
hdm_display_install <provider> <resolution>
hdm_display_verify  <provider>
hdm_desktop_detect
hdm_desktop_install <gnome|xfce|mate>
hdm_desktop_verify  <desktop>
hdm_rustdesk_detect
hdm_rustdesk_install <channel-or-version>
hdm_rustdesk_verify
hdm_rustdesk_config_server <validated-config-path>
hdm_tx_begin <operation>              # 生成事务 ID 与备份清单
hdm_tx_checkpoint <step>
hdm_tx_commit
hdm_tx_rollback <transaction-id>
hdm_diag_run <all|display|desktop|rustdesk|network>
```

- 返回码：`0=完成且验证通过`；其他码在 `error-handler.sh` 统一映射为 `unsupported`, `network`, `trust`, `dependency`, `permission`, `not-ready`, `verification-failed`, `rollback-failed`, `cancelled` 等类型；单独保留机器可读错误代码。
- stdout 用于有约定格式的结果，stderr 用于诊断；必要时使用配置/状态文件传递复杂数据，不能用 `eval` 解析不可信内容。
- 输入应限制长度、格式和特殊字符；尤其是主机、端口、配置文件路径、用户口令和组件版本。
- 所有运行系统命令的参数采用 Bash 数组并正确引用；禁止拼接 shell 字符串后 `eval`；不得执行从外部 JSON/TOML 直接来的命令。
- 使用 `set -Eeuo pipefail` 时要正确处理 `grep` 无匹配、命令替换及 trap；不能因普通探测命令返回非零直接销毁用户环境。
- `trap` 负责临时文件清理、锁释放、事务中断状态，不在不安全时机自动重启服务。

### 5.2 系统检测与安装状态模型

每个组件独立记录：

```text
ABSENT                 未安装
INSTALLED_UNCONFIGURED 已安装、尚未配置
CONFIGURED_STOPPED     已配置但未运行
RUNNING_UNVERIFIED     服务在运行、功能尚未验证
HEALTHY                完成相应健康检查
DEGRADED               部分能力异常
FAILED                 明确故障
UNSUPPORTED            当前 OS/架构不支持
UNKNOWN                不能判断；停止危险操作
```

`HEALTHY` 的含义因组件不同：

- **Dummy**：包/配置存在且 X server 暴露正确可用的虚拟屏幕，不能只查包安装。
- **GNOME**：GDM3 或对应显示管理器正常，实际 GNOME Shell、会话、X11 与 D-Bus 能正常运行；只查 `dpkg -l ubuntu-desktop` 不足以判定健康。
- **RustDesk**：程序/服务正常，ID 可获取，预期配置有效；“远程可以看到画面”属于独立端到端测试。

### 5.3 事务与幂等性（所有危险操作适用）

```text
PRECHECK → PLAN → CONFIRM → BACKUP → EXECUTE → VERIFY
                                               │
                         通过 ───────────────────┤
                         ↓                     失败
                       COMMIT                   ↓
                         ↓               ROLLBACK / SAFE-STOP
                        DONE                   ↓
                                         REPORT + RECOVERY
```

每一步产生日志和 checkpoint；重复执行应只安装缺失项或明确说明操作可复用。事务记录必须含：事务 ID、用户、时间、OS、目标组件、原/目标版本、各步骤状态、配置备份、软件来源、变更文件列表、验证结果、回滚状态；**不包含明文密码**。

恢复约束：
- 配置回滚优先恢复原文件内容、权限、属主及必要的 systemd 状态。
- 软件包更新回滚只有确认旧包及依赖可用时才能承诺，遇到复杂跨版本依赖变更应停止并提示需要系统快照。
- GNOME/Xorg/GDM3 的危险切换，要预先安排**不依赖 GUI 的恢复方式**，如使用独立的系统级恢复计时器，等用户确认成功后取消。计时器自身需在重启和 SSH 中断场景下能正确处理。
- 卸载时禁止把 GNOME 元包依赖中可能被其他应用使用的包盲目 `autoremove`。

### 5.4 日志、安全与机密信息

- 主要日志 `/var/log/hdm/hdm.log`，必要时按事务建文件，保留合理的轮转策略。
- 日志打印命令要脱敏：密码、RustDesk 公钥之外的机密字段、授权 token、内部私钥、环境变量里的凭证不能写明文。**RustDesk 服务器公钥是公开验证信息，但诊断导出仍应征得用户同意。**
- 终端临时输入与敏感备份必须 root-only 权限；使用安全临时目录 `mktemp -d`，清理后不假称可物理安全擦除。
- 不以修改 `chmod 444` 作为程序防止 RustDesk 改配置的方法；不要粗暴递归 `chown` 用户家目录。
- 不因远控需要就自动关闭屏幕锁或开启自动登录。若特定场景必须选择，菜单注明物理/远程访问风险及替代方案。
- RustDesk 客户端配置切勿假定始终在 `/home/ubuntu/.config/rustdesk`；检查 systemd 及用户配置作用域；优先使用客户端实际支持的 CLI/导入方式。
- `sudo hdm` 运行时不要无条件将所有图形应用以 root 用户身份启动；执行配置与图形会话的身份/`XDG_RUNTIME_DIR` 必须区分。

---
## 6. GNOME + 无显示器显示服务 + RustDesk 的技术实施基线

### 6.1 默认支持矩阵

| OS / 架构 | 桌面 | 显示方案 | 远控 | 期望支持状态 | 说明 |
|---|---|---|---|---|---|
| Ubuntu 24.04 amd64 | GNOME（完整） | Xorg Dummy | RustDesk 官方正式版/HDM 已验证版 | **P0：必须实测才能标 Verified** | 首发推荐路径 |
| Ubuntu 24.04 amd64 | GNOME | Xvfb | RustDesk | P2：实验 | 会话总线、软件渲染、捕获兼容性需验证 |
| Ubuntu 24.04 amd64 | GNOME | VKMS | RustDesk | P2：实验 | 内核、DRM、Xorg、GDM3 协作依赖 |
| Ubuntu 24.04 amd64 | XFCE | Dummy / Xvfb | RustDesk | P2：待验证 | 供其他用户选择 |
| Ubuntu 24.04 amd64 | MATE | Dummy | RustDesk | P2：待验证 | 供其他用户选择 |
| Ubuntu 24.04 arm64 | GNOME | Dummy | RustDesk | P2：待验证 | RustDesk 资产、软件渲染、驱动需单测 |
| Debian/Fedora/RHEL | GNOME/其他 | 多方案 | RustDesk | P2：待验证 | 不接受仅换包管理命令的假适配 |

`Verified` 必须记录：测试日期、OS/内核/架构、具体包版本、云平台/虚拟化类型、步骤、启动/重启/联网/远控截图或日志、失败限制。任何新 RustDesk 版本不可自动继承旧版本的 Verified 标记。

### 6.2 GNOME 主路径设计原则

1. 安装 `ubuntu-desktop`（或系统对应的 GNOME 元包）、GDM3、Xorg 和 Dummy 驱动等已识别依赖，检测是否已有其他图形会话或显示管理器。
2. 针对 RustDesk 已验证的 Linux 远控环境，优先支持 X11；对 Wayland 的处理必须**基于当前版本及具体操作条件验证**，不能含糊地宣称全部不支持。修改 GDM3 配置要先备份并确保修改范围精确。
3. **GDM3/登录管理器负责 GNOME 会话**；不要默认用 `ExecStart=/bin/bash -c 'gnome-session & /usr/bin/rustdesk'` 取代真正的图形登录管理。
4. 判断“安装”“配置”“Xorg 运行”“GNOME Shell 运行”“RustDesk 能抓屏”“外部操控成功”这 6 个独立条件，不能把一个成功冒充整个方案成功。
5. 在无 GPU 云服务器上，GNOME Shell 可能依赖 Mesa 软件渲染；需要检查软件渲染能力、CPU/RAM、日志以及对实际云平台的兼容性。
6. 不得依赖旧版 `allow-linux-headless` 专用 RustDesk 选项实现主流程；旧 Wiki 的相关机制曾被弃用。当前参考以官方维护的《Headless Linux》页面与版本测试为准。
7. Xvfb 或 VKMS 是明确可选的方案，但不以它们能安装/能加载推断 GNOME 与 RustDesk 一定可正常工作。

### 6.3 关键健康检查矩阵

| 阶段 | 检查项 | 通过标准 | 失败动作 |
|---|---|---|---|
| A | 软件包 | 对应包/架构真实存在 | 软件源分类诊断 |
| B | 图形显示 | X server 可接受连接，存在可用屏幕/输出 | 输出 Xorg 日志/恢复配置 |
| C | GDM3 | 登录管理器正常，当前策略明确 | 恢复旧配置 |
| D | GNOME | 用户会话、GNOME Shell、D-Bus 等实际启动 | 提供桌面专项诊断 |
| E | RustDesk | 客户端服务运行、ID 可查询、配置可读取 | 诊断 service/权限/配置路径 |
| F | 联机 | ID/Relay 连接条件满足，实际注册状态明确 | 网络/公钥诊断 |
| G | 端到端 | 外部设备能看见 GNOME 桌面、输入有效 | 不标记“完整成功” |
| H | 冷启动 | 重启后重复通过 B～G | 支持恢复并收集启动日志 |

### 6.4 人工确认点

- 重启、重启 GDM3、切换 DISPLAY、关停 RustDesk 服务时提前提示“当前远程会话可能断开”。
- 在 SSH/云控制台没有应急恢复条件时，**禁止自动修改有断连风险的显示/登录配置**；可允许仅下载/只安装不启用。
- 服务器登录策略（自动登录、屏幕锁、身份验证）必须由用户明确配置；不以“无人值守”为由直接取消身份验证。

---

## 7. 一键安装、菜单状态流与异常恢复的精确定义

### 7.1 一键安装状态机

```text
NEW
  ↓
PRECHECKING ──失败──> BLOCKED（报告原因，不变更）
  ↓
PLANNED（用户可预览）
  ↓ 确认
BACKED_UP
  ↓
DISPLAY_INSTALLING → DISPLAY_VERIFYING
  ↓
DESKTOP_INSTALLING → DESKTOP_VERIFYING
  ↓
RUSTDESK_INSTALLING → RUSTDESK_VERIFYING
  ↓
SERVER_CONFIG_PENDING / SERVER_CONFIGURED
  ↓
REBOOT_REQUIRED（如需要） → POST_REBOOT_VERIFYING
  ↓
REMOTE_USER_CONFIRMATION_PENDING
  ↓ 用户从外部连接确认
SUCCEEDED
```

任意阶段失败转入 `FAILED_ACTION_REQUIRED`（展示错误、日志、重试、恢复）；有可靠快照且满足条件时可进入 `ROLLING_BACK`；恢复失败标记 `RECOVERY_NEEDED`，提供 SSH/云控制台步骤。**不得无限自动重试**；取消后保存安全 checkpoint。

### 7.2 典型错误弹窗模板

```text
操作未完成：安装 GNOME
事务 ID：20261107-...        阶段：下载依赖
诊断：当前 APT 镜像响应超时
已更改文件：无            已安装组件：Xorg Dummy

1. 重试当前步骤
2. 使用可信备用镜像重试
3. 查看具体错误与日志
4. 恢复本次配置（有快照时启用）
5. 保存进度并返回主菜单
0. 返回
```

### 7.3 引导关系

- 菜单 3 发现尚无虚拟显示器时，可将用户带到菜单 1；完成后返回原来的 GNOME 安装步骤。
- 菜单 5 发现 GNOME/显示器未就绪时，**允许只安装客户端**但明确标记“图形远控未配置”；用户可跳转菜单 9 或 10。
- 菜单 7 发现 RustDesk 未安装时，提供跳转菜单 5，不能修改不存在的配置文件。
- 菜单 2/4/6 的更新入口遇到组件不存在，应引导到 1/3/5 安装，不应误操作整机。
- 菜单 9 使用统一安装事务引擎；退出时提示保存进度或回滚，而不是直接静默中止。
- 菜单 10 的诊断不应有副作用，**只有“修复/恢复”动作**在确认后可修改系统。

### 7.4 版本与来源缓存

- “当前 RustDesk 版本”“官方最新正式版本”“HDM 经验证推荐版本”须分别存储显示。
- 版本号遵循可解析版本规则，并区分 `nightly` / `beta` / `stable`；无法比较时明确标识“未知”。
- 缓存资产建立 manifest 与哈希索引。下载必须先到临时文件、验证后原子重命名进入缓存。旧的失败下载不得伪装完整包。
- GitHub API 异常/限流时，可使用本地已验证清单，但必须显示数据日期，不声称“最新”。

---

## 8. 分阶段开发路线图与 AI 交付顺序

> 所有阶段均要产出**真实可运行代码 + 自动化测试 + 变更说明**。不要先写一堆空菜单再宣称已经完成产品。

### 8.1 Milestone M0：初始化和核心框架（P0）

- 初始化完整仓库基线、LICENSE（待维护者选择）、README、VERSION、代码质量工具。
- `install.sh` 可下载、校验并安装版本固定的 HDM 包；`sudo hdm` 启动菜单。
- `ui/` 的 10 项菜单及全部子菜单导航可显示，暂不实现的动作明确“实验/未支持”。
- OS/arch 检测仅对 Ubuntu 24.04 amd64 显示正式支持，其他平台报告兼容计划。
- 支持无颜色 TTY、中文字符、错误输入、返回上一级、退出、Ctrl+C、失败日志。
- 建立 `core` 的下载、包管理器、日志、事务、状态接口及测试替身。

**M0 验收**：在干净 Ubuntu 24.04 amd64 VM 中能完成 HDM 自身安装，并通过主菜单逐层抵达本文全部二/三级菜单，返回逻辑正确；不修改 GNOME/系统显示服务。

### 8.2 Milestone M1：真实 GNOME 推荐组合（最优先 P0）

- 完成 Xorg Dummy 安装、配置/分辨率、状态检查、回滚。
- 完成 `ubuntu-desktop` / GDM3 / X11 会话配置，检测 GNOME Shell、会话及软件渲染。
- 完成 RustDesk 官方稳定版的识别、安装、原生服务健康检查、获取 ID。
- 完成菜单 7 的 ID/中继/公钥配置和永久密码安全设定（对版本进行兼容测试）。
- 完成菜单 9.1 一键安装及菜单 10.1/10.2/10.3/10.4 的最低可用诊断。
- 完成初次重启与至少一次真实外部 RustDesk 操作验证。

**M1 验收**：在**真实无显示器的 Ubuntu 24.04 amd64 云服务器**上从干净系统完成 GNOME + Dummy + RustDesk 安装，重启后从外部客户端能看见 GNOME 图形界面并操作输入，发生错误时有日志和恢复路径。测试失败则不标记为已验证。

### 8.3 Milestone M2：管理、更新与备份包（P1）

- 完成菜单 2/4/6 的版本更新、配置管理、恢复、卸载流程。
- 实现菜单 8 的签名校验、原子更新、上一版本回滚。
- 实现菜单 10.6 的可信镜像源切换、GitHub RustDesk 备用包与适合的 Dummy 包备份、清单验证。
- 增加已安装/部分安装/失败安装场景的幂等性与断点恢复。
- 增强菜单 10 的日志、脱敏诊断包和修复计划。

**M2 验收**：模拟官方源断网但 GitHub 备用包可用，能从真实备份包安装受支持的 RustDesk；模拟哈希不匹配必须拒绝安装；升级/回滚不破坏既有 GNOME 配置。

### 8.4 Milestone M3：其他显示和桌面方案（P2）

- Xvfb：可安装、配置、独立运行验证，与 GNOME 完整联动在实际证明前仍为实验。
- VKMS：内核能力、模块、DRM 检测与恢复；与 Xorg/GNOME/RustDesk 组合需逐项测试。
- XFCE、MATE 安装/管理/切换，在兼容矩阵中记录测试结果。
- UI 增加帮助和简洁的组合对比。

### 8.5 Milestone M4：多架构 / 多发行版（P2）

- Ubuntu 24.04 arm64；随后 Debian、Fedora、RHEL；每个系统独立包映射/服务适配。
- 通过各自的本地 VM/云实例安装和重启测试。
- 兼容矩阵中未通过的组合不能加入“推荐”。

---

## 9. 测试方案和不可妥协的验收标准

### 9.1 自动化测试层级

1. **静态检查**：ShellCheck、shfmt、配置文件格式、URL 白名单和敏感字段检测。
2. **单元测试**：系统识别、包名映射、版本比较、错误分类、来源优先级、哈希不符、菜单输入/返回、事务序列化。
3. **集成测试**：APT 适配、模拟损坏镜像、下载中断、缓存损坏、软件源恢复、HDM 更新/回滚、会话配置模板渲染。
4. **端到端测试**：VM 内完整 GNOME 安装、重复执行、重启；真实云服务器上 RustDesk 外部连接、鼠标键盘、冷启动恢复。
5. **安全测试**：命令注入、路径穿越、不可信 URL、错误架构、SHA 不符、日志泄漏、同一时间重复执行、异常信号中断。

### 9.2 关键验收清单（可复制进 GitHub Issue）

- [ ] 用户只执行下载入口 + 安装器（或一条经校验快捷命令），之后可运行 `sudo hdm`。
- [ ] 下载器、更新器与备用镜像只引用 `nljie1103/headless-desktop-manager`；不存在占位仓库 URL；未发布 Release 时明确显示“未发布”。
- [ ] 10 个一级菜单和第 2 章列出的子菜单均可逐层访问、返回，无死链/空白动作。
- [ ] Ubuntu 24.04 amd64 中，未安装 GNOME 的服务器能完整安装 GNOME，不被静默改为 XFCE。
- [ ] 默认推荐为 Xorg Dummy；Xvfb/VKMS 的实验状态和支持条件明确。
- [ ] APT 优先，只有可信镜像故障时才切换；系统包不存在、签名错误、依赖冲突不会误触发 GitHub。
- [ ] RustDesk 官方源失败时，能从已发布且哈希验证过的**实际 GitHub 备用二进制**安装，不依赖不存在的占位地址。
- [ ] 软件源切换前可预览，失败可恢复原配置；Ubuntu 24.04 的 `ubuntu.sources` 未被无意损坏。
- [ ] 已安装组件的重复安装不重建或破坏健康的会话；中断可恢复。
- [ ] GNOME 安装成功与 GNOME 实际图形会话健康分开检查。
- [ ] RustDesk 的 ID 查询、服务器配置、密码设置有独立验证且保密；日志和诊断包不包含密码。
- [ ] 重启后 RustDesk 能连接到真实 GNOME 图形会话，画面与输入均通过外部测试。
- [ ] 远程中断风险动作要明确确认和可靠恢复路径，不默认停止 SSH/防火墙。
- [ ] 管理器更新签名验证、原子切换、旧版本回滚至少通过一次故障注入测试。
- [ ] 卸载操作不误删用户原有配置、不调用高风险的无差别 `autoremove`。
- [ ] 未支持系统会清楚拒绝并显示原因，绝不尝试盲目使用 Ubuntu 适配。

### 9.3 重要故障注入用例

| 用例 | 期望行为 |
|---|---|
| APT 主镜像超时 | 符合策略则换可信镜像，记录来源与错误 |
| APT GPG 签名失效 | 安全停止，不自动关闭校验 |
| RustDesk 上游 Release 无法下载 | 查 HDM 备份清单，验证后使用真实镜像文件 |
| GitHub 备份 SHA 错误 | 删除无效缓存，拒绝安装 |
| 机器只有 SSH，没有 DISPLAY | 仍能进入菜单并在前置检查后安装显示/桌面 |
| GNOME 安装但 Shell 崩溃 | 返回 `DEGRADED`，不能报一键安装成功 |
| GDM3 重启使 SSH 终端仍在线但 RustDesk 断开 | 日志提示，必要时恢复显示配置 |
| 重复执行一键安装 | 检测健康项，不对系统重复做破坏性配置 |
| 更新 HDM 解压中断 | 老版本仍可通过 `sudo hdm` 运行 |
| 修改分辨率后新显示无法工作 | 提供不依赖图形通道的恢复 |
| 配置密码时用户按 Ctrl+C | 不保留明文临时口令；旧配置不被半写坏 |
| 传入恶意主机名或版本字符串 | 被参数校验拒绝，不执行 shell 代码 |

### 9.4 CI 与人工验收分离

GitHub Actions 的容器环境一般**不能证明**真实无 GPU 云服务器 GNOME + Xorg Dummy + RustDesk 的图形/远程连接可用。CI 可覆盖静态、单元、部分集成；真实的远程端到端验收必须独立记录。发布说明要展示**真实支持矩阵**和测试证据，而不是推测的“适用于所有 Linux”。

---

## 10. 代码与文档交付规范（给 AI 实施）

### 10.1 每次实施的输出模板

每完成一个小阶段，AI 必须给维护者：

1. 本次实现的菜单编号（例如 `1.1.1`、`3.1.1`、`9.1`）及具体能力。
2. 新增/修改的仓库文件列表，以及涉及的系统配置文件。
3. 真实运行的静态检查、单元/集成/实机测试命令和结果，未执行的测试要明确标注。
4. 仍存在的兼容性限制或高风险问题。
5. 更新后的 `config/compatibility.tsv`（已验证的才标为 Verified）、版本清单及 ChangeLog。
6. 下一阶段推荐实施顺序，避免临时扩功能扰乱 GNOME 主线。

### 10.2 变更管理

- 以本文件为高优先级需求基线，重要架构变更在 `docs/decisions/` 记录动机、替代方案、测试及风险，并同步规格书版本。
- 新增菜单号不复用现有菜单含义；不要让同一子菜单编号在同一父菜单下出现重复。
- “已验证”“推荐”“最新”这些词只能对应**真实的版本与测试日期**。更新 Release 时重新核实，不能将 2026-11-07 的资料当永久最新。
- 不要把 `.github/workflows/sync-packages.yml` 变成自动发布未经人工审查的备份包的途径。
- 所有第三方二进制的再分发许可证、哈希、来源均须可追溯。

### 10.3 建议的 AI 开发工作提示词（可直接复制）

> 你是 Headless Desktop Manager (HDM) 项目的资深 Linux 系统工程师与 Bash 开发者。请**完整阅读 `docs/AI_DEVELOPMENT_SPEC.md`**。正式仓库是 `https://github.com/nljie1103/headless-desktop-manager`；所有下载、更新、GitHub 备用包地址必须根据 `config/github-endpoints.conf` 与本文 §4.6 统一配置，不能再使用 `OWNER/REPO` 占位符，也不能假定当前空仓库已有 Release。必须保留文档定义的 GitHub 目录结构与 1～10 级交互菜单及全部子菜单。默认部署目标为 Ubuntu 24.04 amd64 + 完整 GNOME(X11) + Xorg Dummy + RustDesk。APT 优先；只有符合故障分类时才使用可信发行版镜像，RustDesk 等适用软件可使用 HDM GitHub Releases 的真实已校验备份包。所有安装/更新/修复遵循检测、预览、确认、备份、执行、验证和记录流程，必须保留 SSH 恢复能力。优先按 M0 → M1 → M2 → M3 → M4 分阶段交付。每次只实现一个可测试的纵向功能切片，不要声称未实测的功能可用；输出文件改动、代码、测试结果、剩余风险及下一步。不得跳过签名校验、明文保存密码、静默切换桌面环境，也不得用空壳菜单冒充已实现功能。

### 10.4 技术决策待验证清单（需记录实验数据）

| 问题 | 初始建议 | 最终决策依据 |
|---|---|---|
| Ubuntu 24.04 GNOME 的最佳 GDM3/Xorg Dummy 接入方式 | 以 GDM3 管理 X11 会话，采用受限配置变更 | 无 GPU 实机登录/重启/抓屏测试 |
| 是否需要自动登录才能稳定远控 | **默认不启用** | 分别测试登录界面捕获、登录后会话与认证安全 |
| RustDesk 永久密码的安全自动配置方法 | 使用当前支持的客户端设置接口 | 具体版本 CLI 行为、参数暴露风险与验证 |
| RustDesk 与不同用户会话的配置作用域 | 检测并使用真实有效上下文 | systemd、RustDesk CLI、配置读写观察 |
| Xvfb + GNOME 是否适合作为稳定备选 | 暂标“实验性” | GNOME Shell / D-Bus / RustDesk 捕获实测 |
| VKMS + GDM3 + GNOME 是否可用 | 暂标“实验性” | 内核/DRM/Xorg/GDM3 整链路测试 |
| Xorg Dummy 安装包是否需要在 HDM Releases 备份 | 允许精确匹配包和依赖已满足时使用 | 包版本、ABI、许可证和实际下载失败测试 |
| 是否采用 `whiptail` 默认界面 | 优先纯 Bash，whiptail 可选 | 最小云镜像及 SSH 环境兼容性 |
| HDM 首次 bootstrap 的可信签名密钥如何分发 | 必须具有本地受信任的初始信任锚 | 安装器和发布链设计评审 |

---

## 11. 风险清单与禁止做法

| 风险 | 等级 | 必须采取的保护 |
|---|---|---|
| GDM3/Xorg 修改导致远程 GUI 消失 | 高 | 预检、快照、SSH/控制台、延迟恢复 |
| GNOME 虚拟显示可安装但不能启动 Shell | 高 | 多阶段健康检查、实机验证 |
| RustDesk 升级使无人值守失效 | 高 | 保存版本/配置、发布兼容矩阵、回滚 |
| 使用伪造/被替换的 GitHub 备份包 | 严重 | 可信清单签名、哈希和来源追踪 |
| 软件源签名错误被盲目绕过 | 严重 | 立即停止，不禁用 GPG 校验 |
| 永久密码通过 shell history/日志/进程泄漏 | 高 | 不回显/不记录，版本相关安全评估 |
| 错误包架构/依赖导致系统损坏 | 高 | OS/arch/ABI 精确匹配，失败安全停止 |
| 新功能过多、跨发行版维护难以控制 | 中 | Ubuntu 24.04 amd64 首发，分阶段扩展 |
| 脚本自更新到不完整版本 | 高 | Release 固定版本、原子更新及恢复 |

**明令禁止**：

- 直接以 root 启动不可信网络脚本而不做来源与完整性校验；
- 安装失败时自动关闭 GPG 或签名验证；
- 用 `chmod 444` 作为 RustDesk 配置的长期正确管理手段；
- 向 RustDesk TOML 中直接写明文密码并声称已配置永久密码；
- 随意执行 `apt upgrade -y`、`apt autoremove -y` 或更换系统发行版；
- 假设 GNOME 仅启动 `gnome-session` 进程就算远程桌面已成功；
- 随意禁用 RustDesk 原生服务、SSH、防火墙、登录认证；
- 未经验证将 GNOME 切换为 XFCE/MATE 或将 Dummy 切换为 Xvfb/VKMS；
- 在 `README` 中宣传未经实机证实的“100% 成功”“所有 Linux 通用”。

---

## 12. 主要官方技术参考（2026-11-07 核查）

以下为实施时需要继续核查的原始资料；具体功能/参数可能随软件版本变化，不作为永久兼容性保证。

1. [RustDesk — Headless Linux 官方 Wiki](https://github.com/rustdesk/rustdesk/wiki/Headless-Linux) — 虚拟显示建议、Dummy、VKMS 等方案。
2. [RustDesk — Client 官方文档](https://rustdesk.com/docs/en/client/) — `--get-id`、`--password`、`--set-id`、配置导入等 CLI/GUI 功能。
3. [RustDesk — GitHub 官方 Releases](https://github.com/rustdesk/rustdesk/releases) — 实时检查 RustDesk 稳定版本和可用 Linux 安装资产。
4. [Ubuntu Server — Install and manage packages](https://ubuntu.com/server/docs/package-management/) — APT 原生软件包操作及 Ubuntu 24.04 `ubuntu.sources`。
5. [Ubuntu 24.04 Release Notes](https://documentation.ubuntu.com/release-notes/24.04/) — 24.04 的 deb822 软件源格式变化。
6. [Linux Kernel — VKMS](https://docs.kernel.org/gpu/vkms.html) — VKMS 是内核软件 DRM/KMS 虚拟显示驱动。
7. [GitHub Docs — About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) — GitHub Release 作为版本化安装资产的分发机制。
8. [原讨论教程](https://blog.jiuliu.org/168.html) — 作为问题背景，不把其中未经验证的 GNOME/Xvfb/systemd 配置作为默认实现。

---

## 13. 完成标准（项目级 Definition of Done）

HDM 的核心价值不是“安装命令聚合”，而是**让用户在没有物理显示器的云服务器上，通过一个终端管理工具可靠地部署和维护 GNOME + RustDesk**。只有同时满足以下条件，才能对外宣布“Ubuntu 24.04 amd64 默认组合正式可用”：

1. 保留第 2 章的完整终端菜单、动作入口和信息引导；实现状态如实标注。
2. 源码按第 3 章模块化，安装后一条 `sudo hdm` 打开菜单。
3. 首次安装、更新、切换、修复对用户是可预览、可检测、可审计、可恢复的流程。
4. APT 首选、镜像切换与 GitHub **真实备用包**按第 4 章的规则运行，校验失败不绕过。
5. Ubuntu 24.04 amd64 GNOME + Xorg Dummy + RustDesk 在至少一种目标无显示器云环境中经过实际安装、重启和外部远程操作验收，测试报告可复现。
6. 代码具有静态、单元、集成以及关键的人工端到端测试记录，所有尚未验证的环境在文档中明确说明。

**规格书维护原则：用户已经明确表达的需求应保留；新的实现建议须标注级别与验证状态；以后接替开发的 AI 必须以本文件作为项目交接和需求判断的第一参考。**

## 附录：Git Commit 提交规范（2026-11-07 补充，必须遵守）

- 每次提交必须以版本号开头：`vX.Y.Z 实际更改内容`。版本号必须来自当前 `VERSION`。
- 先核查 Git diff，再撰写具体、真实的提交内容；严禁空泛或未实现的描述。
- 每次发布同步 `VERSION`、`CHANGELOG.md`；所有提交必须通过 `scripts/check-commit-messages.py` 与 GitHub Actions 的校验。
- Windows 上传脚本打印暂存更改清单，要求人工确认后才创建 commit。
- 详见 `docs/COMMIT_POLICY.md`，以该文件为具体实施规则。


### 2026-11-07 兼容性补充：Ubuntu 26 ARM64

测试阶段取消 Linux 发行版/架构硬性白名单；不要取消来源校验、依赖验证、配置备份和 GDM 启动保护。GNOME 49+ 仅 Wayland；Ubuntu 26 ARM64 一键安装须避开旧版 GNOME X11 强制步骤，显示方案与远程画面分别验收。详见 docs/ubuntu26-arm64.md。
