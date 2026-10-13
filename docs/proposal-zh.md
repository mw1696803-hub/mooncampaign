# mooncampaign —— Agent 内容生产的确定性门禁层（申报书）

## 1. 基本信息

* 项目名称：mooncampaign：Agent 内容生产的确定性门禁层（Content Gate for LLM Agents）

* 参赛者：张思仪

* 联系方式：17188804556

* GitHub 仓库链接：[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)

* 项目方向：新生态项目建设（原创项目）

* 是否为原创项目：是（方法论来自真实邮件运营实践，代码全部原创）

## 2. 项目简介

**生态缺口（mooncakes.io 2026-10 检索，26,296 包）。** MoonBit 的 Agent 工具栈已基本就位：`mizchi/llm` 管 LLM 调用、`proton_cdp` 管浏览器控制、`mcpconftest` 管 MCP 协议、`bitflow`/`jeeflow` 管 DAG 工作流、`moontemplate`/`mold` 管单文档渲染。但中间缺一层——**LLM 生成的内容，结构合不合法、事实有没有核验、链接 UTM 齐不齐、能不能进发布**。上游是裸文本/JSON，下游只负责排版，没有确定性闸门。

**项目定义。** mooncampaign 就是这道闸门：把多期系列内容（邮件/社媒/落地页）从 Brief 到验收发布的全生命周期建模为类型安全领域模型（Campaign/Series/Issue/Block/Claim + 门禁状态机）。LLM 负责生成，引擎负责「结构合法、事实核验、链接一致、QA 通过」——确定性部分交给类型系统与 WASM。

**对 MoonBit 生态的贡献。** ① 补上 Agent 工具栈的最后一环：LLM 客户端 → 工作流 → **内容门禁** → 渲染发送，形成完整闭环；② WASM 首选目标，可打包成 WASM 命令/MCP tool 被 Agent 直接调用；③ 为 MoonBit 验证「类型系统 + WASM 用于非计算领域（内容运营）」的可行路径；④ 方法论来自 7 个月真实 D2C 品牌邮件项目（5 封系列、每期 4–6 模块），规则沉淀经工程验证，非虚构需求。

**通用性**：模型（Campaign/Series/Issue/Block/Claim）不绑定邮件，可映射社媒系列、落地页系列等任何多期内容形态。

## 3. 预期使用场景（3 个）

1. **Agent 批量内容生产的质量闸门**：LLM 批量生成各期内容 → Agent 以 Campaign JSON 导入引擎 → 事实/声明门禁、链接 UTM 校验、QA 逐项拦截 → 通过的结构化结果才进渲染/发送。JSON 互操作层（自包含序列化/反序列化）就是为这个场景设计的。

2. **D2C 品牌 Newsletter 系列运营**：运营者按 Brief 冻结产品/受众/事实，引擎强制事实核验与声明门禁，通过后才能发布；每期按信息类型交替编排模块，主行动链接唯一且携带 UTM。此为方法论来源（真实 7 个月项目），已被工程验证。

3. **多平台系列内容编排**：同一 Campaign 模型产出邮件、社媒、落地页多端版本，门禁与 QA 规则全复用；发布后复盘反馈经可配置规则表（RuleTemplate）提炼成下一期规则，回流 Brief 形成闭环。

## 4. 拟实现的核心功能（已完成）

1. `core`：类型安全领域模型（Brief/Series/Issue/Block/Claim/Fact/Link/门禁状态机/阅读时长估算）
2. `dsl`：模块序列编排规则（相邻信息类型不得重复、主行动存在性与位置）
3. `gates`：事实/声明门禁 + 验收状态机（Draft → Gated/Ready → Approved → Published）+ 审计记录（ApprovalRecord：验收人/渠道）
4. `links`：链接编排 + UTM 五参数 builder + 主行动唯一性 + Google Analytics medium 合法值校验
5. `render`：HTML email（ESP 兼容）/ Markdown / text-plain / JSON 渲染 + Campaign/Issue/Brief 完整 JSON 序列化与反序列化（jsonio，自包含解析器，支持 \uXXXX 转义）
6. `qa`：发布前检查（主题长度、协议安全、图片 alt、正文重复）+ 系列级多样性（标题去重、CTA 差异化）+ checklist 分级输出（Blocker/Warning/Info）
7. `retro`：复盘记录 + 可配置规则表（RuleTemplate：关键词+辅助约束+结构化命中 ID）+ 回流下一期 Brief
8. `cmd` CLI（demo/gate/json/retro/render/help 子命令）+ 虚构品牌可运行示例

**明确不做**：模板语法引擎、ESP 发送/SMTP 集成、通用 workflow 平台、LLM 生成本身（LLM 是上游输入）。

## 5. 原创性说明

原创项目。参考检索（mooncakes.io，2026-10）：`mizchi/llm` 是 LLM 客户端、`bitflow`/`jeeflow` 是通用 DAG 工作流、`moontemplate`/`mold` 是单文档渲染、`MoonSEO` 是单页审计——均不覆盖「内容结构门禁 + 事实核验 + 链接一致性 + 复盘回流」这一层，不构成功能重合；本引擎定位为 Agent 工具栈中的内容门禁层，与现有包互补。

## 6. 移植说明

不适用（无移植/参考外部开源实现，方法论来源于自身真实项目）。

## 7. GitHub 仓库

[https://github.com/mw1696803-hub/mooncampaign](https://github.com/mw1696803-hub/mooncampaign)

* 19 个 commits，其中 11 个为实质功能开发提交（骨架/JSON 互操作/CLI 子命令/规则引擎/系列 QA/text-plain 渲染/UTM 五参数/阅读时长估算/审计记录/render 子命令/checklist 分级）；
* CI（GitHub Actions：moon check + moon test + moon build）已在 main 分支真实运行通过；
* 测试 63/63 通过；Apache-2.0 许可证；preferred_target=wasm（为 skills.mooncakes.io 打包预留）。

## 实现路径与技术理解

纯逻辑库优先：领域模型 + 校验函数 + 状态机，无外部服务依赖，天然适合 MoonBit 与 WASM 分发；渲染层自包含（可换 moontemplate 适配器）；示例用虚构品牌（Harbour & Salt）完整跑通「门禁失败 → 核验 → 验收 → UTM → 渲染 → QA → 复盘」闭环。技术要点：门禁状态机用类型固定非法状态转移（未 Approved 不可 Published）；JSON 解析器自包含实现避免 @json 可见性限制；规则提炼采用可配置规则表（顺序即优先级），为后续 LLM 提炼 + 人工确认留接口；WASM 目标让引擎可打包成 Agent 可直接调用的工具。
