# mooncampaign

**类型安全的系列内容编排引擎（Campaign Orchestration Engine）**

把「多期系列内容（邮件 Campaign / Newsletter）从 Brief 到验收发布的全生命周期」建模成类型安全领域模型：模块编排、事实 / 声明 / 验收门禁、链接编排与 UTM、渲染、发布前 QA、复盘反馈闭环。

> LLM 负责「生成内容」，mooncampaign 负责「结构是否合法、事实是否核验、能否进入发布」—— 确定性部分交给类型系统。

## 为什么存在：MoonBit 生态缺口



* **模板 / 渲染层**已有 `moontemplate` / `mold` 等：解决「单文档渲染」，不解决「多期系列怎么编排、怎么约束、怎么验收」；

* **工作流 / Agent 层**已有 `moonflow` / `ClawTeam`：解决「Agent 步骤编排」，不含内容领域模型；

* **单点应用**已有 `MoonSEO`（SEO 单页生成 + 审计）：单页、单向，没有门禁状态机、链接编排与反馈闭环。

mooncampaign 位于两者之间：**系列内容编排层**。渲染层可复用 moontemplate，Agent 层可消费本引擎产出的结构，形成生态协作而非重复。

## 快速开始



```
\# 运行虚构品牌完整示例

moon run examples/fictional-brand-demo

\# 运行 CLI 演示（含门禁失败→核验→验收全流程）

moon run cmd/main

\# 运行测试

moon test

\# 发布前检查

moon check
```

## 核心概念



| 概念                 | 说明                                               | 来源                  |
| ------------------ | ------------------------------------------------ | ------------------- |
| `Brief`            | Campaign 事实冻结入口：产品、受众、目标、事实清单                    | 产品对象写错的真实教训 → 事实锁定  |
| `Series` / `Issue` | 系列 → 单期：有固定人格与栏目的叙事单元                            | 5 封系列结构             |
| `BlockKind`        | 信息类型：故事 / 痛点 / 证据 / 技巧 / 产品 / 主行动 / 资源 / 互动      | 「每屏换信息类型」规则         |
| `Claim` / `Fact`   | 声明与事实：未经核验不得发布，未确认必须占位                           | 「8 小时保湿未经核验不得直接写」   |
| `IssueStatus`      | 门禁状态机：Draft → Gated/Ready → Approved → Published | 人工验收（Voice Owner）签字 |
| `LinkRole`         | 链接角色：一个主行动，其余按前 / 中 / 后位置分工                      | 链接编排规则              |
| `RetroEntry`       | 复盘记录：反馈回流成下一期规则                                  | 复盘链路                |

## 包结构



```
core    类型安全领域模型（Brief/Series/Issue/Block/Claim/Fact/Link/状态机）

dsl     模块序列编排规则（信息类型交替、主行动存在性与位置）

gates   事实/声明门禁 + 验收状态机（gate/approve/publish）

links   链接编排 + UTM 生成 + 主行动唯一性

render  HTML(email)/Markdown/JSON 渲染（自包含，可换 moontemplate 适配器）

qa      发布前检查：主题长度、协议安全、图片 alt、正文重复

retro   复盘记录 + 规则提炼 + 回流下一期 Brief

cmd      CLI 演示（moon run cmd/main）

examples 虚构品牌完整示例（moon run examples/fictional-brand-demo）
```

## 生态边界（不重复造轮子）



| 已有项目         | 我们             | 关系                  |
| ------------ | -------------- | ------------------- |
| moontemplate | 渲染层            | 后续可替换为本引擎的渲染适配器     |
| moonflow     | 编排层            | 互补：它管「步骤」，我们管「内容结构」 |
| MoonSEO      | 系列编排 + 门禁 + 反馈 | 同模式不同场景，且更通用        |

## 路线图



* [ ] 接入 moontemplate 作为 HTML 渲染适配器

* [ ] WASM 打包发布到 skills.mooncakes.io（Agent 可调用）

* [ ] Campaign JSON 导入 / 导出（与 ESP / LLM 工具链互操作）

* [ ] 规则引擎升级：反馈 → LLM 提炼 + 人工确认

* [ ] 扩展到社媒系列 / 落地页系列 / 通用内容类型

## 许可证

Apache-2.0