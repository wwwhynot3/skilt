# gstack skills 介绍与禁用建议

本文基于当前机器上的 gstack 安装目录整理：

- gstack 源目录：`/home/wwwhynot3/gstack/.agents/skills`
- Codex skills 入口：`/home/wwwhynot3/.codex/skills`
- 当前 Codex 侧大多是 `gstack-* -> /home/wwwhynot3/gstack/.agents/skills/gstack-*` 的符号链接

## 先说结论

如果你的目标是减少上下文占用，不建议一开始保留全套 gstack skills。对 Codex 来说，skills 的名称和描述会进入可用能力清单；数量越多，基础上下文越臃肿。更稳的策略是：

1. 先保留一组日常开发核心 skills。
2. 把低频、大型、角色专用 skills 从 Codex skills 入口移走。
3. 真需要时再恢复对应 symlink 或重新安装。

我不确定你的具体角色，所以先给一个“多数全栈/后端/日常 coding agent 用户”的默认建议。

默认建议保留：

- `gstack`
- `gstack-investigate`
- `gstack-review`
- `gstack-health`
- `gstack-context-save`
- `gstack-context-restore`
- `gstack-careful`
- `gstack-freeze`
- `gstack-guard`
- `gstack-unfreeze`
- `gstack-browse`
- `gstack-qa-only`
- `gstack-ship`（如果你经常让 agent 开 PR 或发版）
- `gstack-document-generate`（如果你经常让 agent 写文档）

默认建议优先禁用：

- 全部 iOS：`gstack-ios-clean`、`gstack-ios-design-review`、`gstack-ios-fix`、`gstack-ios-qa`、`gstack-ios-sync`
- 设计探索/落地：`gstack-design-consultation`、`gstack-design-html`、`gstack-design-review`、`gstack-design-shotgun`
- 产品/计划重型 review：`gstack-autoplan`、`gstack-office-hours`、`gstack-plan-ceo-review`、`gstack-plan-design-review`、`gstack-plan-devex-review`
- 低频平台能力：`gstack-benchmark-models`、`gstack-claude`、`gstack-open-gstack-browser`、`gstack-pair-agent`
- gbrain：`gstack-setup-gbrain`、`gstack-sync-gbrain`
- 低频输出/流程：`gstack-make-pdf`、`gstack-retro`、`gstack-skillify`
- 部署/生产流如果你不用：`gstack-land-and-deploy`、`gstack-canary`、`gstack-setup-deploy`

如果你主要不做 Web UI，`gstack-browse`、`gstack-qa-only`、`gstack-qa`、`gstack-benchmark` 也可以禁用。

## 软禁用与硬禁用

gstack 自带的配置更偏向行为控制，不是完整的“每个 skill 开关”。

软禁用：

- `gstack-config set proactive false`
- 作用：减少 gstack 主动建议或自动触发 skill。
- 局限：不会减少 Codex 启动时看到的 skills 元数据，因此对上下文占用帮助有限。

硬禁用：

- 从 `/home/wwwhynot3/.codex/skills` 移走不需要的 `gstack-*` symlink。
- 作用：Codex 不再把这些 skill 当作可用能力加载。
- 局限：重新运行 gstack setup 或升级后，symlink 可能被恢复。

更安全的做法是只移动 symlink，不动源目录：

```bash
mkdir -p ~/.codex/skills.disabled/gstack
mv ~/.codex/skills/gstack-ios-* ~/.codex/skills.disabled/gstack/
mv ~/.codex/skills/gstack-design-* ~/.codex/skills.disabled/gstack/
```

恢复时再移回：

```bash
mv ~/.codex/skills.disabled/gstack/gstack-ios-* ~/.codex/skills/
```

不要直接删除 `/home/wwwhynot3/gstack/.agents/skills` 下的源目录，除非你明确要改 gstack 安装本体。

## 跨 Codex / Claude Code / OpenCode 的配置化管理脚本

我已经把“移动 skill 入口软链/目录”的方案做成短命令：

- 主命令：`./skilt`
- 测试：`scripts/test-skilt.sh`
- 配置目录：`gstack-skill-config/`
- README：`gstack-skill-config/README.md`

`skilt` 是 skill toggle 的缩写。它只移动 agent 的 skill 入口，不跟随软链，不修改 gstack 源目录。

配置文件：

- `gstack-skill-config/agents.tsv`：agent 的 enabled/disabled 目录和命名规则。
- `gstack-skill-config/skills.tsv`：全量 skill 清单。
- `gstack-skill-config/modules.tsv`：功能模块到 skill 的绑定。
- `gstack-skill-config/profiles.tsv`：角色/阶段画像到模块的绑定。

当前支持三类 agent：

- Codex：管理 `~/.codex/skills/gstack-*`
- Claude Code：管理 `~/.claude/skills/<skill>`
- OpenCode：管理 `~/.config/opencode/skills/gstack-*`

被禁用的入口会移动到对应 disabled 目录：

- Codex：`~/.codex/skills.disabled/gstack`
- Claude Code：`~/.claude/skills.disabled/gstack`
- OpenCode：`~/.config/opencode/skills.disabled/gstack`

常用命令：

```bash
# 查看状态
./skilt status

# 查看总数和差异
./skilt count
./skilt diff

# 预览，不实际改文件
./skilt use backend-indie -n

# 应用后端开发 + 独立产品探索画像
./skilt use backend-indie

# 按功能模块启用/禁用
./skilt on design
./skilt off ios
./skilt on web-qa

# 单独启用/禁用某个 skill；每个 skill 都隐式拥有同名模块
./skilt on design-html
./skilt off benchmark-models

# 全量重置
./skilt all-on
./skilt all-off
./skilt reset

# 校验配置和安装状态
./skilt doctor
```

如果你想核对“总共有多少 skill”以及“为什么 all-on 的 move 条数和总数对不上”，直接看下面三个命令：

```bash
./skilt count
./skilt diff
./skilt diff -a codex
```

- `count`：输出配置 skill 数、已安装条目数（包含根目录 `gstack`）、已安装非根 skill 数，以及每个 agent 当前启用/禁用数量。
- `diff`：输出配置和安装的差异项，以及每个 agent 当前启用/禁用的 skill 名单。

限定某一个 agent：

```bash
./skilt use backend-indie -a codex
./skilt off design -a claude
./skilt on web-qa -a opencode
```

查看配置实体：

```bash
./skilt list agents
./skilt list modules
./skilt list profiles
./skilt list skills
```

`doctor` 会检查：

- `skills.tsv` 是否有重复。
- `modules.tsv` 是否引用了不存在的 skill。
- `profiles.tsv` 是否引用了不存在的 module。
- 真实安装里的 gstack skill 是否漏写到 `skills.tsv`。
- 每个 skill 是否只有隐式同名模块、缺少功能模块绑定。
- 同一个 agent 下 enabled 和 disabled 是否同时存在同名入口。

注意：Claude Code 的实际目录名通常没有 `gstack-` 前缀，例如 `gstack-investigate` 在 Claude Code 下对应 `~/.claude/skills/investigate`。脚本内部已经做了映射。

## skills 全量速览

| Skill | 作用 | 禁用判断 |
| --- | --- | --- |
| `gstack` | gstack 的基础浏览器/QA 能力入口，支持页面导航、点击、截图、表单测试和部署验证。 | 建议保留，除非完全不用浏览器测试。 |
| `gstack-autoplan` | 自动串联 CEO、设计、工程、DX review，替你做计划审查。 | 低频且上下文重，默认禁用。 |
| `gstack-benchmark` | Web 性能回归检测，关注 Core Web Vitals、资源体积、加载时间。 | 做前端性能时保留；后端/非 Web 默认禁用。 |
| `gstack-benchmark-models` | 对比 Claude、GPT、Gemini 在某个 skill 上的延迟、成本、质量。 | 模型评测专用，默认禁用。 |
| `gstack-browse` | Headless browser QA，页面交互、截图、响应式检查、bug 证据。 | Web 开发建议保留；非 Web 可禁用。 |
| `gstack-canary` | 部署后监控，检查控制台错误、性能回退、页面异常。 | 有生产部署流保留；否则禁用。 |
| `gstack-careful` | 对破坏性命令加安全警告，如 `rm -rf`、force push、删库。 | 建议保留，成本低且安全价值高。 |
| `gstack-claude` | 在非 Claude host 中调用 Claude 做 review、challenge 或咨询。 | Codex 用户低频，默认禁用；需要跨模型复核再启用。 |
| `gstack-context-restore` | 恢复之前保存的工作上下文。 | 建议保留。 |
| `gstack-context-save` | 保存 git 状态、决策和剩余工作，方便后续恢复。 | 建议保留。 |
| `gstack-cso` | 安全审计，覆盖 secrets、依赖供应链、CI/CD、OWASP、STRIDE 等。 | 安全/上线前保留；日常轻量编码可按需启用。 |
| `gstack-design-consultation` | 生成设计系统、品牌规范、`DESIGN.md`。 | 设计/前端新项目保留；后端默认禁用。 |
| `gstack-design-html` | 把设计或 mockup 转成生产级 HTML/CSS。 | 前端页面实现保留；非 UI 默认禁用。 |
| `gstack-design-review` | 对 live site 做视觉 QA 并修复，含截图前后对比。 | 前端/设计 polish 保留；其他默认禁用。 |
| `gstack-design-shotgun` | 生成多个设计方案，开比较面板并迭代。 | 视觉探索专用，默认禁用。 |
| `gstack-devex-review` | 实测开发者体验，跑 onboarding、看 docs、测 TTHW。 | SDK/API/CLI 产品保留；普通业务项目禁用。 |
| `gstack-document-generate` | 从代码或 feature 生成 Diataxis 风格文档。 | 经常补文档则保留，否则按需启用。 |
| `gstack-document-release` | 发版后同步 README、架构文档、CHANGELOG 等。 | 重视发布文档保留；小项目可禁用。 |
| `gstack-freeze` | 限制本会话只能编辑某个目录。 | 建议保留，调试共享仓库时有用。 |
| `gstack-guard` | `careful` + `freeze`，完整安全模式。 | 建议保留。 |
| `gstack-health` | 跑类型检查、lint、测试、死代码等并给代码健康分。 | 建议保留。 |
| `gstack-investigate` | 系统化调试，先找根因再修复。 | 强烈建议保留。 |
| `gstack-ios-clean` | 清理 iOS DebugBridge 和调试接入代码。 | 只有 iOS 项目需要，默认禁用。 |
| `gstack-ios-design-review` | 在真机上做 iOS 视觉设计审查。 | 只有 iOS 项目需要，默认禁用。 |
| `gstack-ios-fix` | 对 `/ios-qa` 发现的问题做自动修复、重建、真机验证。 | 只有 iOS 项目需要，默认禁用。 |
| `gstack-ios-qa` | 通过真机、Swift 源码、StateServer 做 iOS QA。 | 只有 iOS 项目需要，默认禁用。 |
| `gstack-ios-sync` | 重新生成 iOS debug bridge 和 Swift accessor。 | 只有 iOS 项目需要，默认禁用。 |
| `gstack-land-and-deploy` | 合并 PR、等待 CI/部署、做生产验证。 | 有成熟部署流保留；否则禁用。 |
| `gstack-landing-report` | 只读查看 workspace/PR/version 排队情况。 | 多 worktree 多人协作保留；个人项目禁用。 |
| `gstack-learn` | 查看、搜索、修剪 gstack 记录的项目经验。 | 使用 gstack 记忆功能时保留；否则禁用。 |
| `gstack-make-pdf` | 把 Markdown 做成排版好的 PDF。 | 文档输出专用，默认禁用。 |
| `gstack-office-hours` | YC office hours 风格的产品/项目早期思考。 | Founder/PM 保留；纯编码默认禁用。 |
| `gstack-open-gstack-browser` | 打开可见的 GStack Browser，带侧栏和实时活动流。 | 需要可视化浏览器控制时保留；默认禁用。 |
| `gstack-pair-agent` | 把远程 agent 连接到你的浏览器。 | 多 agent 协作专用，默认禁用。 |
| `gstack-plan-ceo-review` | Founder/CEO 视角审查计划，挑战范围和产品方向。 | 产品负责人保留；纯工程默认禁用。 |
| `gstack-plan-design-review` | 计划阶段的设计审查，评分并修计划。 | UI 项目保留；后端默认禁用。 |
| `gstack-plan-devex-review` | 计划阶段的开发者体验审查。 | API/SDK/CLI 平台保留；普通项目禁用。 |
| `gstack-plan-eng-review` | 工程经理视角审查架构、数据流、边界、测试。 | 大改动/架构工作建议保留；轻量个人项目可按需启用。 |
| `gstack-plan-tune` | 调整 gstack 提问频率和问题偏好。 | 如果经常被问烦了保留；否则可禁用。 |
| `gstack-qa` | Web QA + 自动修 bug + 复验。 | Web 项目可保留；怕自动改代码则用 `qa-only` 替代。 |
| `gstack-qa-only` | 只做 QA 报告，不修代码。 | Web 项目建议保留。 |
| `gstack-retro` | 周报/迭代复盘，分析提交、质量和团队工作模式。 | 团队管理保留；个人日常默认禁用。 |
| `gstack-review` | PR 落地前 review，找 CI 不一定能发现的结构性问题。 | 强烈建议保留。 |
| `gstack-scrape` | 从网页提取数据，读页面并返回 JSON。 | 经常抓网页数据则保留；否则禁用。 |
| `gstack-setup-browser-cookies` | 把真实浏览器 cookies 导入 headless browse session。 | 测认证页面时保留；否则禁用。 |
| `gstack-setup-deploy` | 配置 `/land-and-deploy` 所需的部署平台和健康检查。 | 只在搭建部署流时启用。 |
| `gstack-setup-gbrain` | 安装并配置 gbrain 记忆/搜索能力。 | 不用 gbrain 就禁用。 |
| `gstack-ship` | 同步基线、跑测试、review、改版本、更新 changelog、提交、推送、开 PR。 | 经常让 agent 走 PR 流程则保留；否则禁用。 |
| `gstack-skillify` | 把成功的 `/scrape` 流程固化成可复用 browser-skill。 | 高频抓取自动化才保留；默认禁用。 |
| `gstack-spec` | 把模糊需求转成可执行 spec 或 GitHub issue。 | PM/工程负责人保留；只接明确任务可禁用。 |
| `gstack-sync-gbrain` | 刷新 gbrain 索引和搜索指导。 | 不用 gbrain 就禁用。 |
| `gstack-unfreeze` | 解除 `freeze` 的编辑限制。 | 如果保留 `freeze`，就保留它。 |
| `gstack-upgrade` | 升级 gstack。 | 可以保留；如果你手动管理版本也可禁用。 |

## 按角色禁用建议

### 1. 日常后端/全栈工程师

建议保留：

- `gstack`
- `gstack-investigate`
- `gstack-review`
- `gstack-health`
- `gstack-context-save`
- `gstack-context-restore`
- `gstack-careful`
- `gstack-freeze`
- `gstack-guard`
- `gstack-unfreeze`
- `gstack-plan-eng-review`
- `gstack-document-generate`
- `gstack-ship`（如果经常开 PR）

按需保留：

- Web 项目：`gstack-browse`、`gstack-qa-only`、`gstack-qa`、`gstack-benchmark`
- 安全敏感：`gstack-cso`
- 生产发布：`gstack-canary`、`gstack-land-and-deploy`、`gstack-setup-deploy`

优先禁用：

- `gstack-ios-*`
- `gstack-design-*`
- `gstack-autoplan`
- `gstack-office-hours`
- `gstack-plan-ceo-review`
- `gstack-plan-design-review`
- `gstack-plan-devex-review`
- `gstack-devex-review`
- `gstack-benchmark-models`
- `gstack-open-gstack-browser`
- `gstack-pair-agent`
- `gstack-setup-gbrain`
- `gstack-sync-gbrain`
- `gstack-retro`
- `gstack-make-pdf`
- `gstack-scrape`
- `gstack-skillify`

### 2. 纯后端/基础设施工程师

建议保留：

- `gstack-investigate`
- `gstack-review`
- `gstack-health`
- `gstack-cso`
- `gstack-careful`
- `gstack-freeze`
- `gstack-guard`
- `gstack-unfreeze`
- `gstack-context-save`
- `gstack-context-restore`
- `gstack-plan-eng-review`
- `gstack-ship`

优先禁用：

- 所有设计类：`gstack-design-*`、`gstack-plan-design-review`
- 所有 iOS：`gstack-ios-*`
- 大多数浏览器类：`gstack-browse`、`gstack-qa`、`gstack-qa-only`、`gstack-benchmark`（除非你维护 Web 服务前台）
- 产品 brainstorm：`gstack-office-hours`、`gstack-plan-ceo-review`
- gbrain/多 agent：`gstack-setup-gbrain`、`gstack-sync-gbrain`、`gstack-pair-agent`

### 3. 前端/产品工程师

建议保留：

- `gstack-browse`
- `gstack-qa-only`
- `gstack-qa`
- `gstack-design-review`
- `gstack-design-html`
- `gstack-plan-design-review`
- `gstack-plan-eng-review`
- `gstack-benchmark`
- `gstack-investigate`
- `gstack-review`
- `gstack-health`
- `gstack-context-save`
- `gstack-context-restore`

按需保留：

- 新项目视觉探索：`gstack-design-consultation`、`gstack-design-shotgun`
- 发布：`gstack-ship`、`gstack-canary`、`gstack-land-and-deploy`
- 认证页面测试：`gstack-setup-browser-cookies`

优先禁用：

- `gstack-ios-*`（除非同时做 iOS）
- `gstack-cso`（按需）
- `gstack-benchmark-models`
- `gstack-claude`
- `gstack-pair-agent`
- `gstack-setup-gbrain`
- `gstack-sync-gbrain`
- `gstack-retro`
- `gstack-make-pdf`

### 4. Founder / PM / 产品负责人

建议保留：

- `gstack-office-hours`
- `gstack-spec`
- `gstack-plan-ceo-review`
- `gstack-plan-design-review`
- `gstack-plan-eng-review`
- `gstack-autoplan`
- `gstack-design-consultation`
- `gstack-design-shotgun`
- `gstack-document-generate`
- `gstack-document-release`
- `gstack-context-save`
- `gstack-context-restore`

按需保留：

- 看真实产品效果：`gstack-browse`、`gstack-qa-only`
- 发版管理：`gstack-ship`、`gstack-landing-report`
- 团队复盘：`gstack-retro`

优先禁用：

- `gstack-ios-*`（除非产品是 iOS）
- `gstack-cso`（上线或安全审计时启用）
- `gstack-benchmark-models`
- `gstack-setup-gbrain`
- `gstack-sync-gbrain`
- `gstack-pair-agent`
- `gstack-scrape`
- `gstack-skillify`

### 5. QA / SRE / Release 角色

建议保留：

- `gstack-browse`
- `gstack-qa-only`
- `gstack-qa`
- `gstack-benchmark`
- `gstack-canary`
- `gstack-ship`
- `gstack-land-and-deploy`
- `gstack-landing-report`
- `gstack-setup-browser-cookies`
- `gstack-setup-deploy`
- `gstack-careful`
- `gstack-guard`
- `gstack-health`
- `gstack-investigate`

优先禁用：

- `gstack-office-hours`
- `gstack-plan-ceo-review`
- `gstack-design-consultation`
- `gstack-design-shotgun`
- `gstack-design-html`
- `gstack-devex-review`
- `gstack-plan-devex-review`
- `gstack-benchmark-models`
- `gstack-make-pdf`
- `gstack-ios-*`（除非测试 iOS）

### 6. 安全工程师

建议保留：

- `gstack-cso`
- `gstack-review`
- `gstack-investigate`
- `gstack-health`
- `gstack-careful`
- `gstack-freeze`
- `gstack-guard`
- `gstack-unfreeze`
- `gstack-context-save`
- `gstack-context-restore`

按需保留：

- Web 安全复现：`gstack-browse`、`gstack-qa-only`
- 发布前卡点：`gstack-ship`

优先禁用：

- `gstack-design-*`
- `gstack-plan-design-review`
- `gstack-office-hours`
- `gstack-plan-ceo-review`
- `gstack-ios-*`（除非审 iOS）
- `gstack-benchmark-models`
- `gstack-make-pdf`
- `gstack-retro`

### 7. 技术写作 / DX / SDK 负责人

建议保留：

- `gstack-document-generate`
- `gstack-document-release`
- `gstack-devex-review`
- `gstack-plan-devex-review`
- `gstack-make-pdf`
- `gstack-browse`
- `gstack-scrape`
- `gstack-context-save`
- `gstack-context-restore`
- `gstack-review`

按需保留：

- SDK/API 计划审查：`gstack-plan-eng-review`
- 认证文档流测试：`gstack-setup-browser-cookies`
- 发版：`gstack-ship`

优先禁用：

- `gstack-ios-*`
- `gstack-design-shotgun`
- `gstack-design-html`
- `gstack-cso`
- `gstack-benchmark-models`
- `gstack-pair-agent`
- `gstack-setup-gbrain`
- `gstack-sync-gbrain`

### 8. iOS 工程师

建议保留：

- `gstack-ios-qa`
- `gstack-ios-fix`
- `gstack-ios-design-review`
- `gstack-ios-sync`
- `gstack-ios-clean`
- `gstack-investigate`
- `gstack-review`
- `gstack-health`
- `gstack-context-save`
- `gstack-context-restore`
- `gstack-careful`

按需保留：

- 产品/设计计划：`gstack-plan-design-review`、`gstack-plan-eng-review`
- 文档：`gstack-document-generate`

优先禁用：

- Web 专用：`gstack-browse`、`gstack-qa`、`gstack-qa-only`、`gstack-benchmark`（除非也维护 Web）
- `gstack-design-html`
- `gstack-scrape`
- `gstack-skillify`
- `gstack-setup-browser-cookies`
- `gstack-open-gstack-browser`
- `gstack-benchmark-models`

### 9. AI tooling / 多模型评测角色

建议保留：

- `gstack-benchmark-models`
- `gstack-claude`
- `gstack-pair-agent`
- `gstack-setup-gbrain`
- `gstack-sync-gbrain`
- `gstack-learn`
- `gstack-context-save`
- `gstack-context-restore`
- `gstack-review`
- `gstack-health`

按需保留：

- 浏览器自动化：`gstack-browse`、`gstack-scrape`、`gstack-skillify`

优先禁用：

- `gstack-ios-*`
- `gstack-design-*`
- `gstack-office-hours`
- `gstack-plan-ceo-review`
- `gstack-plan-design-review`
- `gstack-canary`
- `gstack-land-and-deploy`
- `gstack-make-pdf`

## 汇总禁用建议

如果只想快速减负，我建议分三档处理。

### A 档：几乎所有人都可以先禁用

```text
gstack-ios-clean
gstack-ios-design-review
gstack-ios-fix
gstack-ios-qa
gstack-ios-sync
gstack-benchmark-models
gstack-claude
gstack-open-gstack-browser
gstack-pair-agent
gstack-setup-gbrain
gstack-sync-gbrain
gstack-skillify
gstack-make-pdf
gstack-retro
```

### B 档：非产品/非设计/非前端可以禁用

```text
gstack-autoplan
gstack-office-hours
gstack-plan-ceo-review
gstack-plan-design-review
gstack-plan-devex-review
gstack-design-consultation
gstack-design-html
gstack-design-review
gstack-design-shotgun
gstack-devex-review
```

### C 档：不用 Web/部署流可以禁用

```text
gstack-browse
gstack-qa
gstack-qa-only
gstack-benchmark
gstack-canary
gstack-land-and-deploy
gstack-landing-report
gstack-setup-browser-cookies
gstack-setup-deploy
gstack-scrape
```

### 建议最终保留集

如果你是偏后端/全栈的日常 coding 用户，我建议最终只保留：

```text
gstack
gstack-investigate
gstack-review
gstack-health
gstack-context-save
gstack-context-restore
gstack-careful
gstack-freeze
gstack-guard
gstack-unfreeze
gstack-plan-eng-review
gstack-document-generate
gstack-ship
```

如果你主要做 Web，再额外保留：

```text
gstack-browse
gstack-qa-only
gstack-qa
gstack-benchmark
```

如果你经常走生产发布，再额外保留：

```text
gstack-canary
gstack-land-and-deploy
gstack-landing-report
gstack-setup-deploy
```

如果你告诉我你的主要角色和技术栈，我会把这份清单收敛成一份更激进的个人版保留/禁用列表。
