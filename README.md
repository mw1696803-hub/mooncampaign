# mooncampaign

**LLM 出草稿，mooncampaign 出可发布的成品。**

生成是自由的，发布必须过门禁。

一个类型安全的纯逻辑库：把「多期系列内容」（邮件 Newsletter、社媒系列、课程章节、播客节目、落地页系列）的结构编排、事实门禁、链接一致性、发布前 QA、复盘反馈，抽象成可 `moon add` 复用的领域模型与校验函数。

> 这是一个**引擎/轮子**，不是某个具体产品。任何需要做多期内容、且要保证「结构合法、事实核验、链接一致、QA 通过」再发布的项目，都可以 import 它。

## 对标：其他语言生态里我们是什么

| 生态 | 类似角色 | 说明 |
|---|---|---|
| TypeScript | Zod / Valibot + 自定义内容 schema | 类型安全的运行时校验，但 Zod 是通用 schema，我们是**面向多期内容**的垂直领域模型 |
| Python | Pydantic + content model | 同上，Pydantic 通用，我们内置了系列编排规则、门禁状态机、UTM、QA |
| 内容管理领域 | Contentful content model validator、Mailchimp template validator | 它们是 SaaS 后端的一部分，我们是**纯本地、类型安全、WASM 可分发**的库 |

mooncampaign 在 MoonBit 生态里补的就是这一层：把「多期内容结构校验」从每个项目自己造轮子，变成一个可复用的引擎库。

## 为什么存在：MoonBit 生态缺口（mooncakes.io 2026-10 检索，26,296 包）

Agent 工具栈与渲染层已基本就位，但缺内容结构引擎这一层：

| 层 | 已有包 | 解决什么 |
|---|---|---|
| LLM 客户端 | `mizchi/llm` | 怎么调 LLM |
| 浏览器/工具 | `proton_cdp`、`mcpconftest` | 怎么控制浏览器、MCP 协议 |
| 工作流 | `bitflow`、`jeeflow-core` | DAG 步骤怎么跑 |
| 渲染/输出 | `moontemplate`、`mold`、`moon_epub` | 单个文档怎么渲染 |
| **多期内容引擎** | **mooncampaign** | **多期内容的结构怎么编排、怎么校验、能不能发** |

上游生成裸文本/JSON，下游只负责单文档排版——中间缺「多期内容的领域模型 + 门禁状态机 + 一致性校验」这一层。

## 安装与使用

```
$ moon run cmd/main -- demo
═══ Campaign 完整闭环演示 ═══
[1/6] 加载 Campaign：Solid Hand Cream Launch (5 issues)
[2/6] 门禁检查：Issue 1 / 5
  ✗ Blocker: Claim "8-hour hydration" has no verified fact
[3/6] 事实核验后重新门禁…
  ✓ All gates passed for Issue 1
[4/6] 链接编排：5 links, 1 primary CTA, UTM complete
[5/6] QA checklist:
  ✓ Subject length 42 chars
  ✓ All links https
  ⚠ Warning: Image missing alt text (3 images)
  ✓ No duplicate body text
[6/6] 渲染输出：HTML email / text/plain / JSON
═══ 完成：1 issue approved, ready to publish ═══
```

```bash
moon add mw1696803-hub/mooncampaign
```

```
# 运行虚构品牌完整示例（仅作引擎能力演示，不是产品）
moon run examples/fictional-brand-demo

# CLI 子命令（引擎能力的命令行入口）
moon run cmd/main -- demo               # 完整闭环演示
moon run cmd/main -- gate               # 事实/声明门禁演示
moon run cmd/main -- json               # 诊断 Campaign JSON
moon run cmd/main -- retro '<反馈>'     # 复盘反馈 → 规则提炼
moon run cmd/main -- render text        # 渲染 Issue（html/text/markdown/json）
moon run cmd/main -- help

# 自定义 JSON 诊断（Windows 推荐环境变量方式）
$env:MOONCAMPAIGN_JSON='{"id":"i1","title":"...","status":"Draft","blocks":[],"claims":[]}'
moon run cmd/main -- json

# 运行测试
moon test
moon check
```

## 核心概念（引擎领域模型）

| 概念 | 说明 |
|---|---|
| `Brief` | 内容事实冻结入口：产品、受众、目标、事实清单 |
| `Series` / `Issue` | 系列 → 单期：有固定人格与栏目的叙事单元 |
| `BlockKind` | 信息类型：故事/痛点/证据/技巧/产品/主行动/资源/互动 |
| `Claim` / `Fact` | 声明与事实：未经核验不得发布，未确认必须占位 |
| `IssueStatus` | 门禁状态机：Draft → Gated/Ready → Approved → Published |
| `LinkRole` | 链接角色：一个主行动，其余按前/中/后位置分工 |
| `RuleTemplate` | 可配置规则表：关键词 + 辅助约束 → 下一期规则 |
| `ApprovalRecord` | 验收/发布审计记录：谁验的、发到哪个渠道 |

## 包结构（全部纯逻辑，无外部服务依赖）

```
core      类型安全领域模型 + 阅读时长估算
dsl       模块序列编排规则（信息类型交替、主行动存在性与位置）
gates     事实/声明门禁 + 验收状态机 + 审计记录
links     链接编排 + UTM 五参数 builder + medium 合法值校验
render    HTML/Markdown/text-plain/JSON 渲染 + 自包含 JSON 序列化/反序列化
qa        发布前检查 + 系列多样性 + checklist 分级（Blocker/Warning/Info）
retro     复盘记录 + 可配置规则表 + 回流下一期 Brief
cmd       CLI（引擎能力的命令行入口）
examples  虚构品牌示例（演示用，不是产品）
```

## JSON 互操作（Agent/工具接入点）

`render` 包内置自包含 JSON 序列化/反序列化，供 Agent 与外部工具链导入导出：

* `issue_to_json` / `brief_to_json` / `series_to_json` / `campaign_to_json`
* `json_to_issue` / `json_to_brief` / `json_to_campaign`（递归下降解析器，支持 `\uXXXX` 转义）

LLM 产出 JSON → Agent 调 `json_to_campaign` → 跑 `gate` + `qa` → 通过才进渲染。

## 生态边界（不重复造轮子）

| 已有项目 | 我们 | 关系 |
|---|---|---|
| `mizchi/llm` | LLM 客户端 | 它生成，我校验 |
| `bitflow` / `jeeflow` | DAG 工作流 | 它管步骤，我管内容结构合不合法 |
| `moontemplate` / `mold` | 单文档渲染 | 它管排版，我管发不发得了 |
| `moon_epub` | EPUB 电子书生成 | 同模式不同场景，互补 |

## 路线图

* [x] Campaign JSON 导入/导出
* [x] 规则引擎可配置化（RuleTemplate）
* [x] CLI 参数化子命令（含 render 四格式）
* [x] 发布前 checklist 分级输出
* [ ] 发布到 mooncakes.io
* [ ] MCP tool 适配：核心校验函数包成 MCP 工具
* [ ] WASM 打包（Agent 可直接调用）
* [ ] 扩展领域：社媒系列、课程章节、播客节目（同一引擎，不同领域模型）

## 许可证

Apache-2.0
