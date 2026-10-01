test "复盘记录与规则提炼" {
  let entry = record("i1", "价格未确认就写了 12 英镑，被驳回", ["价格必须核验后填写"])
  assert_eq(entry.issue_id, "i1")
  assert_eq(entry.rule_changes.length(), 1)
}

test "规则提炼：占位与产品错误" {
  let rules = suggest_rules("产品写错了，价格未确认用了占位")
  assert_true(rules.length() >= 2)
}

test "规则提炼：命中退回反馈" {
  let rules = suggest_rules("本期退订率上升，回复减少")
  assert_true(rules.length() >= 1)
}

test "apply_rules 将规则写入下一期 Brief" {
  let brief = @core.Brief::new("x", "y")
  let entry = record("i1", "f", ["产品对象必须核对"])
  let next = apply_rules(brief, entry)
  assert_eq(next.goals.length(), 1)
  assert_true(next.goals[0].contains("产品对象必须核对"))
}
