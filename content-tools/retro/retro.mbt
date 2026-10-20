///|
/// campaign-retro：复盘反馈闭环
///
/// 真实工作流中，每期发布后的点击/回复/退订数据会回流成下一期规则。
/// 本包把「复盘记录」建模为可追踪的数据结构，规则提炼由
/// 可配置的规则表驱动（默认表沉淀自真实邮件项目方法论）。

/// 一条复盘记录：某期发布后的反馈与规则变更
pub(all) struct RetroEntry {
  issue_id : String
  feedback : String
  rule_changes : Array[String]
} derive(Debug)

/// 一条规则模板：关键词组合 → 规则文本
/// - keywords：任一命中即触发
/// - require_any：辅助约束词，出现任一个即满足（与 keywords 做 AND）；为空则仅看 keywords
/// - keywords 为空：视为兜底模板（仅在其他模板均未命中时生效）
pub(all) struct RuleTemplate {
  id : String
  keywords : Array[String]
  require_any : Array[String]
  rule : String
}

/// 记录一条复盘
pub fn record(issue_id : String, feedback : String, rule_changes : Array[String]) -> RetroEntry {
  { issue_id, feedback, rule_changes }
}

/// 便捷构造：关键词列表 → 规则
pub fn RuleTemplate::new(id : String, keywords : Array[String], rule : String) -> RuleTemplate {
  { id, keywords, require_any: [], rule }
}

/// 便捷构造：关键词 + 辅助约束词 → 规则
pub fn RuleTemplate::with_requires(
  id : String,
  keywords : Array[String],
  require_any : Array[String],
  rule : String,
) -> RuleTemplate {
  { id, keywords, require_any, rule }
}

/// 默认规则表（沉淀自真实邮件项目：占位、对象一致性、链接/UTM、退订、互动）
pub fn default_rule_templates() -> Array[RuleTemplate] {
  let templates : Array[RuleTemplate] = []
  templates.push(
    RuleTemplate::new(
      "placeholder",
      ["占位", "placeholder"],
      "未确认事实必须先占位，禁止编造默认值",
    ),
  )
  templates.push(
    RuleTemplate::with_requires(
      "product-mismatch",
      ["产品"],
      ["错", "写错", "不对"],
      "产品对象必须与 Campaign Brief 锁定一致，写前核对",
    ),
  )
  templates.push(
    RuleTemplate::new(
      "utm",
      ["链接", "UTM", "utm"],
      "所有外链必须携带 UTM，主行动链接角色一致",
    ),
  )
  templates.push(
    RuleTemplate::new(
      "unsub",
      ["退订", "unsub"],
      "重新检查发送频率与内容价值密度，降低退订风险",
    ),
  )
  templates.push(
    RuleTemplate::new(
      "reply",
      ["回复", "reply"],
      "保留互动型模块，延续回复型话题",
    ),
  )
  templates
}

/// 检查单条模板是否命中反馈文本
fn template_matches(t : RuleTemplate, feedback : String) -> Bool {
  let mut kw_hit = false
  for k in t.keywords {
    if feedback.contains(k) {
      kw_hit = true
      break
    }
  }
  if !kw_hit {
    return false
  }
  // 无辅助约束词：仅看 keywords
  if t.require_any.is_empty() {
    return true
  }
  for r in t.require_any {
    if feedback.contains(r) {
      return true
    }
  }
  false
}

/// 用自定义规则表提炼下一期规则
/// 规则表顺序即优先级；兜底模板（keywords 为空）仅在无命中时生效。
pub fn suggest_rules_with(templates : Array[RuleTemplate], feedback : String) -> Array[String] {
  let rules : Array[String] = []
  let mut fallback : String? = None
  for t in templates {
    if t.keywords.is_empty() {
      // 兜底模板：记录首个兜底文本
      match fallback {
        None => fallback = Some(t.rule)
        Some(_) => ()
      }
    } else if template_matches(t, feedback) {
      rules.push(t.rule)
    }
  }
  if rules.is_empty() {
    match fallback {
      Some(r) => rules.push(r)
      None => rules.push("（未命中规则模板，需人工提炼）")
    }
  }
  rules
}

/// 从反馈中提炼下一期规则（默认规则表）
pub fn suggest_rules(feedback : String) -> Array[String] {
  suggest_rules_with(default_rule_templates(), feedback)
}

/// 返回命中的模板（结构化，便于记录规则来源 ID）
pub fn match_templates(templates : Array[RuleTemplate], feedback : String) -> Array[RuleTemplate] {
  let hits : Array[RuleTemplate] = []
  for t in templates {
    if !t.keywords.is_empty() && template_matches(t, feedback) {
      hits.push(t)
    }
  }
  hits
}

/// 将复盘规则追加到 Campaign Brief 的 goals 中（作为下一期的约束备注）
/// 返回新 Brief，不修改原对象
pub fn apply_rules(brief : @core.Brief, entry : RetroEntry) -> @core.Brief {
  let goals : Array[String] = []
  for g in brief.goals {
    goals.push(g)
  }
  for r in entry.rule_changes {
    goals.push("[规则] " + r)
  }
  { ..brief, goals }
}
