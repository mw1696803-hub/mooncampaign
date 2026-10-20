///|
/// retro 规则引擎升级测试：可配置规则表

test "默认规则表保持兼容" {
  let rules = @retro.suggest_rules("价格未确认就用了占位")
  assert_true(rules.length() >= 1)
  assert_true(rules[0].contains("占位"))
}

test "require_all 约束生效" {
  // 产品 + 错/写错 同时出现才命中
  let rules = @retro.suggest_rules("本期产品写错了对象")
  assert_true(rules.contains("产品对象必须与 Campaign Brief 锁定一致，写前核对"))
  // 只有产品没有错 → 不命中
  let rules2 = @retro.suggest_rules("产品很好用")
  assert_true(rules2.contains("（未命中规则模板，需人工提炼）"))
}

test "自定义规则表驱动提炼" {
  let templates : Array[@retro.RuleTemplate] = []
  templates.push(@retro.RuleTemplate::new("stock", ["发货"], "发货前必须核对库存"))
  templates.push(@retro.RuleTemplate::new("refund", ["退款"], "退款文案需注明时效"))
  let rules = @retro.suggest_rules_with(templates, "这次发货慢了")
  assert_true(rules.length() == 1)
  assert_true(rules[0].contains("库存"))
  let rules2 = @retro.suggest_rules_with(templates, "有人要退款")
  assert_true(rules2.length() == 1)
  assert_true(rules2[0].contains("时效"))
}

test "兜底模板仅在无命中时生效" {
  let templates : Array[@retro.RuleTemplate] = []
  templates.push(@retro.RuleTemplate::new("a", ["命中"], "命中的规则"))
  templates.push(@retro.RuleTemplate::new("fallback", [], "兜底：需人工提炼"))
  let rules = @retro.suggest_rules_with(templates, "这条命中")
  assert_true(rules.length() == 1)
  assert_true(rules[0].contains("命中"))
  let rules2 = @retro.suggest_rules_with(templates, "什么都没提")
  assert_true(rules2.length() == 1)
  assert_true(rules2[0].contains("兜底"))
}

test "match_templates 返回结构化命中" {
  let templates = @retro.default_rule_templates()
  let hits = @retro.match_templates(templates, "链接没带 UTM")
  assert_true(hits.length() >= 1)
  // 命中的模板 id 应为 utm
  let mut found = false
  for t in hits {
    if t.id == "utm" {
      found = true
    }
  }
  assert_true(found)
}
