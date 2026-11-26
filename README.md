# AgentDot

AgentDot 是一个 macOS 置顶悬浮球，聚合 Claude Code CLI 会话状态：

- 运行中显示绿色跑马灯；
- 需要你介入时圆点和进度条红色脉冲：权限提示、Claude 提问（AskUserQuestion / 计划批准）、MCP elicitation；工具超过 7 秒未返回时提示需要授权；Stop 时检测纯文本提问；
- 点击会话行跳转到 iTerm2 / Terminal / Kaku / Ghostty 对应标签页或面板；
- 精确到标签页/面板的消警：只有该会话所在标签页成为活动标签才停止脉冲（外部等待和纯文本提问需手动忽略）；
- 收起态 ≤N 显示彩色小点，>N 显示数字（N 默认 5，范围 1–9）；
- 退出入口：右键悬浮球、设置 → 维护 → 退出 AgentDot，或菜单栏 AgentDot 图标菜单。

当前只接入 Claude Code CLI；DSH、WorkBuddy 未接入。

## 环境要求

- macOS 13+
- Claude Code CLI 2.1.x
- Swift 6 / Xcode 或 Command Line Tools（SwiftPM 构建）

## 构建与测试

```bash
swift build --product AgentDot
swift build --product dot-hook
bash scripts/test.sh          # 全部核心测试
bash scripts/test.sh StateReducer
bash scripts/dev-run.sh --demo
```

> 测试通过 `Tests/AgentDotCoreTests` 里的 `AgentDotTests` 可执行 target 运行（不依赖 XCTest），
> 而不是 `swift test`；`bash scripts/test.sh` 是统一入口。以后可以迁移到 XCTest，核心代码不用改。

## 从 GitHub Releases 安装（推荐）

1. 打开 https://github.com/qiuzhaokun/agent-dot/releases ，下载最新的 `AgentDot-<version>.dmg`。
2. 双击 DMG，打开 `AgentDot.app`；应用提示时点“安装到 ~/Applications”。
3. ad-hoc 签名首次打开会被 Gatekeeper 拦截一次：右键点击 → 打开（或系统设置 → 隐私与安全性 → 仍要打开）。
4. 面板会自动展开，点“修复 Hooks”（会备份 `~/.claude/settings.json`，保留现有 cc-status）。
5. 需要开机自启：设置里打开；需要跳转权限：首次点击会话行时允许自动化。

自动更新要求 app 位于 `~/Applications`；放在 `/Applications` 可能因权限无法自动替换，会提示移动。

**只保留一份安装**：自动更新只管理 `~/Applications/AgentDot.app`。如果又手动把 DMG 拖到 `/Applications`，Launchpad/Spotlight 会显示两个相同图标；保留 `~/Applications` 那份，删除另一个即可。应用启动时会自动把历史遗留的 `.previous-*.app` 备份迁移到 `~/Library/Application Support/AgentDot/Backups` 并改名为 `.app.backup`，不会再出现在应用列表。

## 自动更新

- 启动时 + 每 24h + 菜单/设置“检查更新”。
- 发现新版本：面板横幅“新版本 X 可用”；点“升级”后：
  1. 下载 `AgentDot-<version>.zip`；
  2. 校验 SHA256 + Ed25519（公钥内置 app）；
  3. 解压、校验 bundle id/version；
  4. app 自替换：备份旧版到 `~/Library/Application Support/AgentDot/Backups`（`.app.backup`，不会被识别成第二个 App）→ 替换 → 去 quarantine → 重启（`UpdaterEngine`，避免 App Management 拦截；`AgentDotUpdater` 保留为备用/手动）；
  5. 失败自动回滚。
- 不做静默更新；每次由用户点“升级”。
- 更新清单：`https://github.com/qiuzhaokun/agent-dot/releases/latest/download/latest.json`。
- `prerelease` 只用于手动 DMG 测试；app 读 `releases/latest`，不会自动更新到 prerelease；自动更新版本必须是纯三段 semver。

### 升级后自动化权限

ad-hoc 签名每次构建的 cdhash 不同，升级后 macOS 可能要求重新授予 Automation 权限。应用会显示“已更新”提醒；若点击会话行跳转失败，请到 **系统设置 → 隐私与安全性 → 自动化** 重新允许 AgentDot。Kaku 走 CLI，不受影响。想彻底避免这个问题，后续可以改用自签名代码签名证书（不需要 Apple Developer）。

## 安装（脚本，开发/备用）

```bash
bash scripts/install.sh
```

安装脚本会：

1. 构建 `dist/AgentDot.app` 并 ad-hoc 签名；
2. 复制到 `~/Applications/AgentDot.app`；
3. 复制 helper 到 `~/.agent-dot/bin/dot-hook`；
4. 合并 hooks 到 `~/.claude/settings.json`（先备份，保留现有 `cc-status` hooks）；
5. 写入 `~/Library/LaunchAgents/dev.agentdot.app.plist` 并启动。

卸载：

```bash
bash scripts/uninstall.sh          # 保留状态目录和 helper
bash scripts/uninstall.sh --purge  # 同时删除状态目录和 helper
```

## 首次使用权限

点击会话行跳转时，macOS 会弹出自动化权限请求：

- iTerm2 / Terminal / Ghostty：在“系统设置 → 隐私与安全性 → 自动化”中允许 AgentDot；
- Kaku：走 `kaku cli activate-pane`，不需要 Apple Events 权限。

如果拒绝权限，行内会提示；可在系统设置里重新允许。

## 数据与隐私

- 除更新检查/下载外不联网；更新检查只 GET GitHub 静态清单，下载只访问 GitHub Releases，无用户数据/遥测；
- 不保存 prompt、tool_input、tool_response、notification message、最后回复内容；
- 只保存工具名、项目路径、状态、终端标识到 `~/Library/Application Support/AgentDot/sessions/`；
- helper 日志：`~/Library/Application Support/AgentDot/logs/hook.log`（不含 prompt 内容）；
- AgentDot 只观察授权，不会代答或自动批准。

## 路径

| 内容 | 路径 |
|---|---|
| App | `~/Applications/AgentDot.app` |
| helper | `~/.agent-dot/bin/dot-hook` |
| 状态 | `~/Library/Application Support/AgentDot/` |
| Claude 配置 | `~/.claude/settings.json` |
| 登录项 | `~/Library/LaunchAgents/dev.agentdot.app.plist` |

调试时可用 `AGENTDOT_STATE_DIR` 指向临时状态目录，用 `AGENTDOT_SETTINGS_PATH` 指向临时 settings 文件（不会碰真实配置）：

```bash
TMP=$(mktemp -d)
AGENTDOT_STATE_DIR="$TMP" .build/debug/dot-hook emit < Tests/Fixtures/session_start.json
AGENTDOT_SETTINGS_PATH="$TMP/settings.json" .build/debug/dot-hook install-hooks
```

## 发布（维护者）

1. Ed25519 密钥：
   - 私钥只放 GitHub Actions secret：repo → Settings → Secrets and variables → Actions → `AGENTDOT_UPDATE_PRIVATE_KEY`（内容为 `dist/update-private-key.base64` 的文件内容）。
   - 公钥在 `Resources/Info.plist` 的 `AgentDotUpdatePublicKey`；不要提交私钥。
   - 私钥丢失后无法自动更新；需要换公钥并让用户手动装一次新版。
   - **当前仓库里的公钥/本地私钥是为 dry-run 生成的**。正式发布前建议你本机重新生成一对：删除/改名 `dist/update-private-key.base64`，运行 `swift scripts/generate-update-key.swift <新路径>`，把输出的公钥替换 `Resources/Info.plist` 的 `AgentDotUpdatePublicKey`；私钥只放 GitHub secret 并离线备份。
2. 用 GitHub Desktop 把代码 push 到默认分支（`workflow_dispatch` 只显示在默认分支）；GitHub → Actions → Release → Run workflow，输入版本号（如 `0.1.1`）。
3. workflow 会构建/测试/打包 DMG+ZIP/签名 ZIP/生成 `latest.json`/创建 Release。
4. 本地 dry-run：
   ```bash
   AGENTDOT_UPDATE_PRIVATE_KEY="$(cat dist/update-private-key.base64)" \
     AGENTDOT_RELEASE_NOTES="..." bash scripts/package-release.sh 0.1.1
   ```
   产物在 `dist/`；`latest.json` 签名可用 `swift scripts/verify-update.swift ...` 校验。

## 未来支持（Roadmap，尚未实现）

- [ ] Apple Watch 提醒
- [ ] 系统通知提醒

## 已知限制

- **Ghostty 精确跳转/消警**：依赖 `GHOSTTY_SURFACE_ID` 与 AppleScript terminal `id` 一致；不一致时跳转退回按工作目录匹配，自动消警关闭（保留右键“忽略本次提醒”）。
- **Kaku 活动面板**：依赖 `kaku cli list --format json` 的 `is_active` / `pane_id` 字段；字段不可用时不自动消警。
- **unknown / headless 会话**（如 `claude -p` 无 TTY）：列表显示、允许提醒，但点击不跳转。
- **tmux**：只跳到外层终端标签页；tmux pane 切换未实现。
- 系统通知、历史统计、云端同步尚未实现；提示音已支持，可在「设置 → 提醒」中开启。
- **外部授权只能推测**：磁盘 TCC 弹窗、IDEA/数据库授权等发生在 Claude Code 之外，AgentDot 只能通过「工具执行超过 7 秒未返回」提示需要授权；长时间编译/查询也会触发。纯文本提问通过 transcript 末尾启发式判断，可能误报。要做到 100% 精确需要 IDE 插件或辅助功能监听。
- 授权提示后没有“已批准”事件，红闪的停止依赖“精确活动标签 + 消警”；状态本身仍是等待授权，直到 Claude 的后续 hook 事件证明已处理。
- **ad-hoc 签名**：首次从 DMG 打开需要右键一次；没有 notarization，Gatekeeper 会提示。
- **自动更新位置**：只保证 `~/Applications` 内可替换；`/Applications` 会提示移动，不自动更新。
- **不静默更新**：必须用户点“升级”；私钥丢失后自动更新失效。
- **ad-hoc + Automation**：升级后可能需要重新授予终端自动化权限；应用会提醒。
- **App Management**：自替换优先；如果 macOS 仍拦截，应用会提示手动下载 DMG。
- **prerelease**：不会进入自动更新，只用于手动 DMG 测试。

## 验证

核心逻辑有 128 个自动测试（状态机、待介入检测、transcript 提问检测、锁、终端上下文、settings 合并、可见性/隐藏状态机、消警策略、Kaku active pane 解析、会话名称解析、声音提醒调度、配置、语义版本/更新清单/Ed25519/替换回滚）。UI、四终端跳转、自动化权限需要在本机手工验证，步骤见技术方案 §12.3。
