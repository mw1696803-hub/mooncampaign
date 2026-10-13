# mooncampaign —— 多期内容编排与校验引擎（申报书）

## 1. 基本信息

* 项目名称：mooncampaign：多期内容编排与校验引擎（Multi-issue Content Orchestration & Validation Engine）

* 参赛者：张思仪

* 联系方式：17188804556

* GitHub 仓库链接：[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)

* 项目方向：新生态项目建设（原创可复用库）

* 是否为原创项目：是（方法论来自真实邮件运营实践，代码全部原创）

## 2. 项目简介

**项目定位：一个可 `moon add` 复用的纯逻辑库/引擎，不是某个具体产品。**

把「多期系列内容」（邮件 Newsletter、社媒系列、课程章节、播客节目、落地页系列）的结构编排、事实门禁、链接一致性、发布前 QA、复盘反馈，抽象成类型安全的领域模型与校验函数。任何需要做多期内容、且要保证「结构合法、事实核验、链接一致、QA 通过」再发布的项目，都可以 import 它。

**对标其他语言生态：**
- TypeScript 的 Zod / Valibot：类型安全的运行时校验，但它们是通用 schema；mooncampaign 是**面向多期内容**的垂直领域模型，内置了系列编排规则、门禁状态机、UTM、发布前 QA。
- Python 的 Pydantic：通用数据校验；mooncampaign 在此之上封装了内容领域逻辑。
- 内容管理领域（Contentful content model validator、Mailchimp template validator）：它们是 SaaS 后端的一部分；mooncampaign 是**纯本地、类型安全、WASM 可分发**的开源库。

**生态缺口（mooncakes.io 2026-10 检索，26,296 包）：**
MoonBit 的 Agent 工具栈（`mizchi/llm`、`proton_cdp`、`mcpconftest`）、工作流引擎（`bitflow`、`jeeflow`）、渲染层（`moontemplate`、`mold`、`moon_epub`）都已存在，但缺「多期内容结构编排与校验」这一层。上游生成裸文本/JSON，下游只负责单文档排版——中间没有类型化的领域模型与门禁。mooncampaign 补的就是这一层。

**对 MoonBit 生态的贡献：**
① 提供生态首个「多期内容编排与校验」基础库，渲染层可复用其结构，Agent 工作流可调用其门禁；② WASM 首选目标，可打包成 WASM 命令/MCP tool 被 Agent 直接调用；③ 验证「类型系统 + WASM 用于非计算领域（内容运营）」的可行路径；④ 方法论来自 7 个月真实 D2C 品牌邮件项目（5 封系列），规则沉淀经工程验证。

**通用性**：模型（Campaign/Series/Issue/Block/Claim）不绑定邮件，可映射任何多期内容形态。

## 3. 预期使用场景（3 个）

1. **任何做多期内容的开发者**：用 `moon add` 引入引擎，快速获得类型安全的领域模型、门禁状态机、UTM 生成、发布前 QA，不用每个项目自己造轮子。

2. **Agent 批量内容生产的质量闸门**：LLM 批量生成各期内容 → Agent 以 Campaign JSON 导入引擎 → 事实/声明门禁、链接 UTM 校验、QA 逐项拦截 → 通过的结构化结果才进渲染。JSON 互操作层就是为这个场景设计的。

3. **多平台系列内容编排**：同一引擎模型产出邮件、社媒、课程章节多端版本，门禁与 QA 规则全复用；发布后复盘反馈经可配置规则表提炼成下一期规则，形成闭环。

## 4. 拟实现的核心功能（已完成）

1. `core`：类型安全领域模型（Brief/Series/Issue/Block/Claim/Fact/Link/门禁状态机/阅读时长估算）
2. `dsl`：模块序列编排规则（相邻信息类型不得重复、主行动存在性与位置）
3. `gates`：事实/声明门禁 + 验收状态机（Draft → Gated/Ready → Approved → Published）+ 审计记录（ApprovalRecord）
4. `links`：链接编排 + UTM 五参数 builder + 主行动唯一性 + Google Analytics medium 合法值校验
5. `render`：HTML/Markdown/text-plain/JSON 渲染 + Campaign/Issue/Brief 完整 JSON 序列化与反序列化（自包含解析器）
6. `qa`：发布前检查（主题长度、协议安全、图片 alt、正文重复）+ 系列级多样性 + checklist 分级（Blocker/Warning/Info）
7. `retro`：复盘记录 + 可配置规则表（RuleTemplate）+ 回流下一期 Brief
8. `cmd` CLI（引擎能力的命令行入口）+ 虚构品牌演示示例

**明确不做**：模板语法引擎、ESP 发送/SMTP 集成、通用 workflow 平台、LLM 生成本身（LLM 是上游输入）。

## 5. 原创性说明

原创可复用库。参考检索：
- mooncakes.io 现有包中，`moontemplate`/`mold` 是单文档渲染，`bitflow`/`jeeflow` 是通用 DAG 工作流，`mizchi/llm` 是 LLM 客户端——均不覆盖「多期内容结构编排与校验」这一层。
- 其他语言生态中，Zod/Pydantic 是通用 schema 校验，不是面向多期内容的垂直领域模型；Contentful/Mailchimp 的校验逻辑是 SaaS 后端私有实现，不是开源可复用库。
- 本项目定位为可 `moon add` 的独立引擎库，与现有生态包互补，不构成功能重合。

## 6. 移植说明

不适用（无移植/参考外部开源实现，方法论来源于自身真实项目）。

## 7. GitHub 仓库

[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)

* 19 个 commits，其中 11 个为实质功能开发提交（全部为纯逻辑库代码，非产品应用）；
* CI（GitHub Actions：moon check + moon test + moon build）已在 main 分支真实运行通过；
* 测试 63/63 通过；Apache-2.0 许可证；preferred_target=wasm（为 skills.mooncakes.io 打包预留）。

## 实现路径与技术理解

纯逻辑库优先：领域模型 + 校验函数 + 状态机，无外部服务依赖，天然适合 MoonBit 与 WASM 分发。门禁状态机用类型固定非法状态转移（未 Approved 不可 Published）；JSON 解析器自包含实现避免 @json 可见性限制；规则提炼采用可配置规则表（顺序即优先级），为后续 LLM 提炼 + 人工确认留接口。示例用虚构品牌（Harbour & Salt）仅作引擎能力演示，不是产品。
