# mooncampaign —— 类型安全的系列内容编排引擎

> 申报书 · MoonBit 黑客松 · 2026-10
> 替换占位：`[参赛者]`、`https://github.com/mw1696803-hub/mooncampaign`、`[联系方式]`

## 一、项目价值与生态定位

**解决什么问题。** 邮件营销（D2C 品牌 Newsletter）的产出不是「写一封邮件」，而是运营一个多期系列：从 Campaign Brief 到系列策划、单期模块编排、事实核验、链接编排、发布前检查、发布后复盘，每期反馈回流成下一期规则。现有工具只有两类：模板引擎（渲染单个文档）和通用 Agent 工作流（编排步骤），中间缺一层「内容领域的确定性编排」——结构合法性、事实门禁、链接/UTM 一致性、发布 QA、复盘回流，都没有类型化建模。我们在一家 D2C 品牌的实际邮件项目里跑了 7 个月（5 封系列邮件、每期 4–6 模块），沉淀出这套规则，现在把它变成可复用的引擎。

**为什么用 MoonBit。** 这套引擎的差异化价值是「确定性」：类型系统把 Campaign 模型和门禁状态机编译期固定下来；`pub`/`pub(all)` 可见性控制让外部只能按规则构造；`wasm` 首选目标让引擎可以打包成 WASM 命令发布到 skills.mooncakes.io，Agent 和浏览器都能直接调用——这是 MoonBit 相对其他语言最匹配的定位。

**与现有项目的差异（mooncakes.io 检索，2026-10）。**

| 项目 | 覆盖 | 差异 |
|---|---|---|
| moontemplate | 单文档模板渲染（HTML/邮件/Markdown） | 我们不写模板语法，渲染层可复用它的适配器 |
| moonflow | 通用 Agent DAG 工作流 | 它管「步骤」，我们管「内容结构 + 门禁」 |
| MoonSEO | 品牌 brief → SEO 单页 + 规则审计 | 单页、单向；我们做多期系列 + 门禁状态机 + 反馈回流 |

## 二、交付范围与工程边界

**做**（7 个包，36 个测试已通过）：

1. `core`：类型安全领域模型（Brief / Series / Issue / Block / Claim / Fact / Link / 状态机）
2. `dsl`：模块序列编排规则（相邻信息类型不得重复、主行动存在与位置）
3. `gates`：事实/声明门禁 + 验收状态机（Draft → Gated/Ready → Approved → Published）
4. `links`：链接编排 + UTM 生成 + 主行动唯一性
5. `render`：HTML email（ESP 兼容 table 布局）/ Markdown / JSON
6. `qa`：发布前检查（主题长度、协议安全、图片 alt、正文重复）
7. `retro`：复盘记录 + 规则提炼 + 回流下一期 Brief
8. CLI 演示 + 虚构品牌可运行示例

**不做**：模板语法引擎、ESP 发送/API 集成、SMTP、通用 workflow 平台、LLM 生成本身（LLM 是我们的上游输入）。

## 三、实现路径与技术理解

**技术路线。** 纯逻辑库优先：领域模型 + 校验函数 + 状态机，无外部服务依赖，天然适合 MoonBit 开发与 WASM 分发。渲染层当前自包含（约 200 行），后续替换为 moontemplate 适配器。示例使用虚构品牌（Harbour & Salt 固体护手霜）完整跑通「门禁失败 → 核验 → 验收 → UTM → 渲染 → QA → 复盘」闭环。

**验收标准。** `moon check` 零错误、`moon test` 全绿（当前 36/36）、两个可运行入口（`moon run cmd/main`、`moon run examples/fictional-brand-demo`）、CI 工作流通过。

**真实经验来源（非虚构）。** 产品对象写错被人工驳回（→ Brief 事实锁定）；「8 小时保湿」未经核验不得直接写（→ Claim 门禁）；价格未确认就写值（→ Fact 强制占位）；每期一个主行动但链接按前/中/后角色分工（→ LinkRole）；每期发布后数据回流成下一期规则（→ Retro）。

## 四、团队分工与时间规划

| 阶段 | 内容 | 时间 |
|---|---|---|
| 1 | 领域模型 + 门禁状态机（core/gates） | 第 1 周 |
| 2 | 编排规则 + 链接/UTM + QA（dsl/links/qa） | 第 1–2 周 |
| 3 | 渲染 + 复盘（render/retro） | 第 2 周 |
| 4 | CLI + 示例 + 文档 + CI | 第 2–3 周 |
| 5 | 接入 moontemplate + WASM skill 发布 | 第 3 周（冲刺） |

团队：`[参赛者]`（1–2 人，核心逻辑 + 示例）。GitHub：`https://github.com/mw1696803-hub/mooncampaign`。
