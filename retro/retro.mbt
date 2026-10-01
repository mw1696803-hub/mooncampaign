///|
/// campaign-retro：复盘反馈闭环
///
/// 真实工作流中，每期发布后的点击/回复/退订数据会回流成下一期规则。
/// 本包把「复盘记录」建模为可追踪的数据结构，并提供简单的规则提炼。

/// 一条复盘记录：某期发布后的反馈与规则变更
pub(all) struct RetroEntry {
  issue_id : String
  feedback : String
  rule_changes : Array[String]
} derive(Debug)

/// 记录一条复盘
pub fn record(issue_id : String, feedback : String, rule_changes : Array[String]) -> RetroEntry {
  { issue_id, feedback, rule_changes }
}

/// 从反馈中提炼下一期规则（规则引擎的简化版：关键词 → 规则）
/// 真实实现可接入 LLM + 人工确认；这里提供确定性的最小实现。
pub fn suggest_rules(feedback : String) -> Array[String] {
  let rules : Array[String] = []
  if feedback.contains("占位") || feedback.contains("placeholder") {
    rules.push("未确认事实必须先占位，禁止编造默认值")
  }
  if feedback.contains("产品") && (feedback.contains("错") || feedback.contains("写错")) {
    rules.push("产品对象必须与 Campaign Brief 锁定一致，写前核对")
  }
  if feedback.contains("链接") || feedback.contains("UTM") {
    rules.push("所有外链必须携带 UTM，主行动链接角色一致")
  }
  if feedback.contains("退订") || feedback.contains("unsub") {
    rules.push("重新检查发送频率与内容价值密度，降低退订风险")
  }
  if feedback.contains("回复") || feedback.contains("reply") {
    rules.push("保留互动型模块，延续回复型话题")
  }
  if rules.is_empty() {
    rules.push("（未命中规则模板，需人工提炼）")
  }
  rules
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
