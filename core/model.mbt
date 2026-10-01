///|
/// mooncampaign 核心领域模型（campaign-core）
///
/// 面向「多期系列内容（邮件 Campaign / Newsletter）」的类型安全建模。
/// 模型抽象自真实 D2C 邮件营销工作流沉淀：
///   系列策划（Series → Issue）→ 单期模块编排（Block 序列）
///   → 事实/声明门禁（Fact / Claim）→ 链接编排（Link 角色）
///   → 渲染 → QA → 复盘反馈（Retro）
///
/// 设计原则：LLM 负责「生成内容」，本引擎负责「结构是否合法、
/// 事实是否核验、能否进入发布」——确定性部分交给类型系统。

/// 信息类型：相邻模块不得连续使用同一种信息类型
pub(all) enum BlockKind {
  /// 共同经历 / 场景
  Story
  /// 具体问题 / 痛点
  Pain
  /// 真实人物 / 证据 / 评价
  Evidence
  /// 可带走的发现 / 技巧
  Tip
  /// 产品自然出现
  Product
  /// 主行动
  Cta
  /// 教育 / 资源链接
  Resource
  /// 回复型互动（投票 / 回信）
  Interaction
} derive(Debug, Eq)

/// 链接角色：一封邮件只有一个主行动（PrimaryCta），
/// 其余链接按出现位置承担不同职责，主链接可重复出现但角色一致。
pub(all) enum LinkRole {
  /// 主行动（全期唯一目标）
  PrimaryCta
  /// 前段承接
  Opening
  /// 中段承接
  Middle
  /// 后段承接
  Closing
  /// 教育 / 资源
  Resource
  /// 回复型互动
  Reply
} derive(Debug, Eq)

/// 声明状态：未经核验的产品声明（如「8 小时保湿」）不得进入发布稿
pub(all) enum ClaimStatus {
  /// 已核验，可对外发布
  Approved
  /// 待核验：可进入草稿，但必须占位或附证据，不得直接发布
  Pending
  /// 被阻断：不得出现在任何发布稿
  Blocked
} derive(Debug, Eq)

/// 业务事实：未确认的事实必须强制占位
pub(all) struct Fact {
  key : String
  value : String?
  confirmed : Bool
}

/// 一条链接：角色 + 目标 + UTM
pub(all) struct Link {
  role : LinkRole
  label : String
  url : String
  utm : String?
}

/// 一个内容模块：一种信息类型 + 正文 + 链接 + 图片 alt
pub(all) struct Block {
  kind : BlockKind
  title : String
  body : String
  links : Array[Link]
  image_alt : String?
}

/// 一条产品声明：文本 + 状态 + 证据来源
pub(all) struct Claim {
  text : String
  status : ClaimStatus
  evidence : String?
}

/// 单期状态机：Draft →(gate) Ready/Gated →(approve) Approved →(publish) Published
pub(all) enum IssueStatus {
  Draft
  Gated
  Ready
  Approved
  Published
} derive(Debug, Eq)

/// 单期内容
pub(all) struct Issue {
  id : String
  title : String
  blocks : Array[Block]
  claims : Array[Claim]
  status : IssueStatus
}

/// 一个系列（Season）：若干期组成一个有固定人格与栏目的叙事单元
pub(all) struct Series {
  id : String
  name : String
  issues : Array[Issue]
}

/// Campaign Brief：事实冻结的入口，一切生成的上游约束
pub(all) struct Brief {
  product : String
  audience : String
  goals : Array[String]
  facts : Array[Fact]
}

/// 一个 Campaign = Brief + Series
pub(all) struct Campaign {
  brief : Brief
  series : Series
}

/// 便捷构造
pub fn Campaign::new(brief : Brief, series : Series) -> Campaign {
  { brief, series }
}

/// 便捷构造：新一期默认 Draft 状态
pub fn Issue::new(id : String, title : String) -> Issue {
  { id, title, blocks: [], claims: [], status: Draft }
}

/// 便捷构造：新系列
pub fn Series::new(id : String, name : String) -> Series {
  { id, name, issues: [] }
}

/// 便捷构造：一条已确认的事实
pub fn Fact::confirmed(key : String, value : String) -> Fact {
  { key, value: Some(value), confirmed: true }
}

/// 便捷构造：一条未确认的事实（门禁将强制占位）
pub fn Fact::pending(key : String) -> Fact {
  { key, value: None, confirmed: false }
}

/// 便捷构造：一条链接（UTM 默认未生成）
pub fn Link::new(role : LinkRole, label : String, url : String) -> Link {
  { role, label, url, utm: None }
}

/// 便捷构造：一个内容模块（图片 alt 可选，QA 会检查缺失）
pub fn Block::new(kind : BlockKind, title : String, body : String) -> Block {
  { kind, title, body, links: [], image_alt: None }
}

/// 便捷构造：一条声明（默认待核验）
pub fn Claim::new(text : String) -> Claim {
  { text, status: Pending, evidence: None }
}

/// 便捷构造：Campaign Brief
pub fn Brief::new(product : String, audience : String) -> Brief {
  { product, audience, goals: [], facts: [] }
}

/// 链接角色的中文标签（用于 UTM content 与诊断）
pub fn LinkRole::label(self : LinkRole) -> String {
  match self {
    PrimaryCta => "primary-cta"
    Opening => "opening"
    Middle => "middle"
    Closing => "closing"
    Resource => "resource"
    Reply => "reply"
  }
}

/// 单期状态的中文标签（用于渲染与诊断）
pub fn IssueStatus::label(self : IssueStatus) -> String {
  match self {
    Draft => "Draft"
    Gated => "Gated"
    Ready => "Ready"
    Approved => "Approved"
    Published => "Published"
  }
}

/// 信息类型的中文标签（用于诊断信息输出）
pub fn BlockKind::label(self : BlockKind) -> String {
  match self {
    Story => "故事/场景"
    Pain => "痛点"
    Evidence => "证据/评价"
    Tip => "技巧"
    Product => "产品"
    Cta => "主行动"
    Resource => "资源"
    Interaction => "互动"
  }
}
