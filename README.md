# mooncampaign

**Agent 内容生产的确定性门禁层（Content Gate for LLM Agents）**

LLM 批量生成内容后，怎么保证「结构合法、事实核验、链接一致、QA 通过」再进下游渲染/发送？mooncampaign 把这条流水线建模成类型安全领域模型：模块编排、事实/声明门禁、链接编排与 UTM、发布前 QA、复盘反馈闭环。

> LLM 负责「生成内容」，mooncampaign 负责「结构是否合法、事实是否核验、能否进入发布」——确定性部分交给类型系统与 WASM。

## 为什么存在：MoonBit 生态缺口（mooncakes.io 2026-10 检索）

Agent 工具栈已有，但缺内容门禁这一层：

| 层 | 已有包 | 解决什么 |
|---|---|---|
| LLM 客户端 | `mizchi/llm` | 怎么调 LLM |
| 浏览器/工具 | `proton_cdp`、`mcpconftest` | 怎么控制浏览器、MCP 协议 |
| 工作流 | `bitflow`、`jeeflow-core` | DAG 步骤怎么跑 |
| 渲染/输出 | `moontemplate`、`mold`、`moon_epub` | 单个文档怎么渲染 |
| **内容门禁** | **mooncampaign** | **生成的内容能不能发** |

上游 LLM 产出的是裸文本/JSON，下游渲染器只负责排版——中间缺「这一期内容结构合不合法、事实有没有核验、链接 UTM 齐不齐、能不能进发布」这道确定性闸门。这就是 mooncampaign 的位置。

## 快速开始

```
# 运行虚构品牌完整示例
moon run examples/fictional-brand-demo

# CLI 子命令
moon run cmd/main -- demo               # 完整闭环演示（默认）
moon run cmd/main -- gate               # 事实/声明门禁演示
moon run cmd/main -- json               # 诊断内置 Campaign 示例
moon run cmd/main -- retro '<反馈>'     # 复盘反馈 → 规则提炼
moon run cmd/main -- render text        # 渲染 Issue 到 stdout（html/text/markdown/json）
moon run cmd/main -- help

# 自定义 JSON 诊断（Windows 下命令行传参会剥离引号，推荐环境变量方式）
$env:MOONCAMPAIGN_JSON='{"id":"i1","title":"...","status":"Draft","blocks":[],"claims":[]}'
moon run cmd/main -- json

# 运行测试 / 发布前检查
moon test
moon check
```

## 核心概念

| 概念 | 说明 | 真实来源 |
|---|---|---|
| `Brief` | Campaign 事实冻结入口：产品、受众、目标、事实清单 | 产品对象写错的真实教训 → 事实锁定 |
| `Series` / `Issue` | 系列 → 单期：有固定人格与栏目的叙事单元 | 5 封系列邮件结构 |
| `BlockKind` | 信息类型：故事/痛点/证据/技巧/产品/主行动/资源/互动 | 「每屏换信息类型」规则 |
| `Claim` / `Fact` | 声明与事实：未经核验不得发布，未确认必须占位 | 「8 小时保湿未经核验不得直接写」 |
| `IssueStatus` | 门禁状态机：Draft → Gated/Ready → Approved → Published | 人工验收（Voice Owner）签字 |
| `LinkRole` | 链接角色：一个主行动，其余按前/中/后位置分工 | 链接编排规则 |
| `RuleTemplate` | 可配置规则表：关键词 + 辅助约束 → 下一期规则（含结构化命中 ID） | 复盘链路 |
| `ApprovalRecord` | 验收/发布审计记录：谁验的、发到哪个渠道 | 真实运营审计需求 |

## 包结构

```
core      类型安全领域模型（Brief/Series/Issue/Block/Claim/Fact/Link/状态机/阅读时长估算）
dsl       模块序列编排规则（信息类型交替、主行动存在性与位置）
gates     事实/声明门禁 + 验收状态机 + 审计记录（gate/approve/publish）
links     链接编排 + UTM 五参数 builder + 主行动唯一性 + medium 合法值校验
render    HTML(email)/Markdown/text-plain/JSON 渲染 + Campaign JSON 完整序列化/反序列化
qa        发布前检查（主题长度、协议安全、图片 alt、正文重复、系列多样性、checklist 分级）
retro     复盘记录 + 可配置规则表（RuleTemplate）+ 回流下一期 Brief
cmd       CLI 子命令（demo/gate/json/retro/render/help）
examples  虚构品牌完整示例（moon run examples/fictional-brand-demo）
```

## JSON 互操作（Agent 接入点）

`render` 包内置自包含的 JSON 序列化/反序列化，就是给 Agent/工具链用的：

* `issue_to_json` / `brief_to_json` / `series_to_json` / `campaign_to_json`：完整字段（链接 UTM、声明证据、图片 alt、事实状态）；
* `json_to_issue` / `json_to_brief` / `json_to_campaign`：递归下降解析器，支持 `\uXXXX` 转义（含代理对），非法输入返回 `None`。

LLM 产出 JSON → Agent 调 `json_to_campaign` → 跑 `gate` + `qa` → 通过才进渲染。CLI `json` 子命令可直接消费。

## 生态边界（不重复造轮子）

| 已有项目 | 我们 | 关系 |
|---|---|---|
| `mizchi/llm` | LLM 客户端 | 我们是它的下游：它生成，我们校验 |
| `bitflow` / `jeeflow` | DAG 工作流引擎 | 它管「步骤」，我们管「内容结构能不能发」 |
| `proton_cdp` / `mcpconftest` | 浏览器控制 / MCP 协议 | 未来可把我们包成 MCP tool 接入 |
| `moontemplate` / `mold` | 单文档渲染 | 它管排版，我们管发不发得了 |
| `moon_epub` | EPUB 电子书生成 | 同模式不同场景，互补 |

## 路线图

* [x] Campaign JSON 导入/导出（与 LLM/工具链互操作）
* [x] 规则引擎可配置化（RuleTemplate 规则表 + 结构化命中）
* [x] CLI 参数化子命令（含 render 四格式）
* [x] 发布前 checklist 分级输出（Blocker/Warning/Info）
* [ ] 发布到 mooncakes.io
* [ ] MCP tool 适配：把核心校验函数包成 MCP 工具，接入 Agent 工具栈
* [ ] WASM 打包发布到 skills.mooncakes.io（Agent 可调用）
* [ ] 反馈 → LLM 提炼 + 人工确认
* [ ] 扩展到社媒系列 / 落地页系列 / 通用内容类型

## 许可证

Apache-2.0
