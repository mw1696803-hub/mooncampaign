# mooncampaign —— 类型安全的系列内容编排引擎（申报书）

> 基本信息（参赛者、联系方式）随报名问卷填写；GitHub：https://github.com/mw1696803-hub/mooncampaign

## 1. 项目名称

mooncampaign：类型安全的系列内容编排引擎（Campaign Orchestration Engine）

## 2. 项目简介

**生态缺口。** MoonBit 生态目前两个方向已有人占位：渲染层（moontemplate 等模板引擎解决「单个文档怎么渲染」）、编排层（moonflow 等 Agent 工作流解决「步骤怎么编排」）。但内容生产中最常见的形态——「多期系列内容」（Newsletter、社媒系列、活动 Campaign）——缺少领域建模：结构合法性、事实核验门禁、链接/UTM 一致性、发布 QA、复盘回流，都没有类型化表达；单点应用（如 MoonSEO）只覆盖单页单次场景，没有门禁状态机与反馈闭环。这一层不做，上游 LLM 生成与下游模板渲染之间就是「无校验的裸数据搬运」。

**项目定义。** mooncampaign 补齐「系列内容编排层」：把多期 Campaign 从 Brief 到验收发布的全生命周期建模为类型安全领域模型（Campaign/Series/Issue/Block/Claim + 门禁状态机）。LLM 负责生成内容，引擎负责「结构是否合法、事实是否核验、能否进入发布」——确定性部分交给类型系统。

**对 MoonBit 生态的贡献。** ① 提供生态首个「内容领域编排」基础库：渲染层可复用 moontemplate 消费其结构，Agent 工作流可调用其门禁，形成生态协作而非重复造轮子；② WASM 首选目标，可打包成 WASM 命令发布到 skills.mooncakes.io，让 Agent 与浏览器直接调用类型化门禁与 QA；③ 为 MoonBit 验证「类型系统 + WASM 用于非计算领域（内容运营）」的可行路径，扩大生态应用场景面；④ 方法论来自 7 个月真实邮件项目（5 封系列、每期 4–6 模块，D2C 品牌），规则沉淀经工程验证，非虚构需求。

## 3. 项目方向与通用性说明

**方向**：新生态项目建设（原创项目，非移植）。

**竞品差异（mooncakes.io 检索确认，2026-10）**：

| 项目 | 覆盖 | 差异 |
|---|---|---|
| moontemplate | 单文档模板渲染（HTML/邮件/Markdown） | 管「单个文档怎么渲染」，无系列建模与门禁 |
| moonflow / ClawTeam | 通用 Agent 工作流 | 管「步骤怎么编排」，无内容领域模型 |
| MoonSEO | 品牌 brief → SEO 单页 + 规则审计 | 单页、单向，无门禁状态机与反馈闭环 |

**通用性**：模型（Campaign/Series/Issue/Block/Claim）不绑定邮件，可映射社媒系列、落地页系列等任何多期内容形态。

## 4. 预期使用场景（3 个）

1. **D2C 品牌 Newsletter 系列运营**：运营者按 Brief 冻结产品/受众/事实，引擎强制事实核验与声明门禁，通过后才能发布；每期按信息类型交替编排模块，主行动链接唯一且携带 UTM。此为方法论来源（真实 7 个月项目），已被工程验证。
2. **LLM 批量内容生产的质量闸门**：Agent 用 LLM 批量生成各期内容 → 以 Campaign JSON 导入引擎 → 门禁、QA、链接/UTM 校验逐项拦截 → 通过的结构化结果再进 ESP 渲染发送。JSON 互操作层（自包含序列化/反序列化）就是为这个场景设计的。
3. **多平台系列内容编排**：同一 Campaign 模型产出邮件、社媒、落地页多端版本，门禁与 QA 规则全复用；发布后复盘反馈经可配置规则表（RuleTemplate）提炼成下一期规则，回流 Brief 形成闭环。

## 5. 拟实现的核心功能（已完成）

1. `core`：类型安全领域模型（Brief/Series/Issue/Block/Claim/Fact/Link/门禁状态机）
2. `dsl`：模块序列编排规则（相邻信息类型不得重复、主行动存在性与位置）
3. `gates`：事实/声明门禁 + 验收状态机（Draft → Gated/Ready → Approved → Published）
4. `links`：链接编排 + UTM 生成 + 主行动唯一性
5. `render`：HTML email（ESP 兼容）/ Markdown / JSON 渲染 + Campaign/Issue/Brief 完整 JSON 序列化与反序列化（jsonio，自包含解析器，支持 \uXXXX 转义）
6. `qa`：发布前检查（主题长度、协议安全、图片 alt、正文重复）+ 系列级多样性检查（标题去重、CTA 差异化）
7. `retro`：复盘记录 + 可配置规则表（RuleTemplate：关键词+辅助约束+结构化命中 ID）+ 回流下一期 Brief
8. `cmd` CLI（demo/gate/json/retro/help 子命令）+ 虚构品牌可运行示例

**明确不做**：模板语法引擎、ESP 发送/SMTP 集成、通用 workflow 平台、LLM 生成本身（LLM 是上游输入）。

## 6. 原创性说明

原创项目。参考检索（mooncakes.io，2026-10）：moontemplate 覆盖单文档模板渲染，moonflow 覆盖 Agent 步骤编排，MoonSEO 为单页生成+审计——均不覆盖「多期系列的门禁状态机 + 链接编排 + 复盘回流」，不构成功能重合；本引擎定位为与它们互补的编排层。

## 7. 移植说明

不适用（无移植/参考外部开源实现，方法论来源于自身真实项目）。

## 8. GitHub 仓库

https://github.com/mw1696803-hub/mooncampaign
- 10 个有效 commits（骨架/申报书/JSON 互操作/CLI 子命令/规则引擎/系列 QA/文档，无空拆分）；
- CI（GitHub Actions：moon check + moon test + moon build）已在 main 分支真实运行通过；
- 测试 50/50 通过；Apache-2.0 许可证；preferred_target=wasm（为 skills.mooncakes.io 打包预留）。

## 实现路径与技术理解

纯逻辑库优先：领域模型 + 校验函数 + 状态机，无外部服务依赖，天然适合 MoonBit 与 WASM 分发；渲染层自包含（可换 moontemplate 适配器）；示例用虚构品牌（Harbour & Salt）完整跑通「门禁失败 → 核验 → 验收 → UTM → 渲染 → QA → 复盘」闭环。技术要点：门禁状态机用类型固定非法状态转移（未 Approved 不可 Published）；JSON 解析器自包含实现避免 @json 可见性限制；规则提炼采用可配置规则表（顺序即优先级），为后续 LLM 提炼 + 人工确认留接口。
