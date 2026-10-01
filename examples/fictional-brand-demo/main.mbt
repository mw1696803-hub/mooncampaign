///|
/// 虚构品牌完整示例：Harbour & Salt（固体护手霜）
///
/// 运行：moon run examples/fictional-brand-demo
///
/// 展示 mooncampaign 的最小完整闭环：
///   Brief → 系列/单期 → 编排检查 → 门禁 → UTM → 渲染 → QA → 复盘
fn main {
  // 1. Brief：事实冻结
  let brief = @core.Brief::new("Harbour & Salt Solid Hand Cream", "UK, 30-60 women")
  brief.facts.push(@core.Fact::confirmed("price", "£12"))

  // 2. 单期：四个模块（信息类型交替）
  let issue = @core.Issue::new("ttw-01", "Tiny Travel Wins #1")
  let story = @core.Block::new(@core.BlockKind::Story, "One cream, three airports", "story...")
  let pain = @core.Block::new(@core.BlockKind::Pain, "Liquids are a lie", "pain...")
  let product = @core.Block::new(@core.BlockKind::Product, "Solid, pocket-size", "product...")
  product.links.push(
    @core.Link::new(@core.LinkRole::PrimaryCta, "Get it", "https://shop.example/hs"),
  )
  let cta = @core.Block::new(@core.BlockKind::Cta, "Try this weekend", "cta...")
  cta.links.push(
    @core.Link::new(@core.LinkRole::PrimaryCta, "Shop now", "https://shop.example/hs"),
  )
  issue.blocks.push(story)
  issue.blocks.push(pain)
  issue.blocks.push(product)
  issue.blocks.push(cta)

  // 3. 编排检查（相邻信息类型不得重复 + 必须有主行动）
  let dsl_problems = @dsl.check_sequence(issue.blocks)
  if !dsl_problems.is_empty() {
    println("编排问题: " + dsl_problems.join(" | "))
  }

  // 4. 门禁：从 Draft 到 Ready（人工验收后 Approved）
  let (ready, gate_problems) = @gates.gate(issue, brief)
  if !gate_problems.is_empty() {
    println("门禁问题: " + gate_problems.join(" | "))
  }
  let approved = @gates.approve(ready)
  println("状态: " + approved.status.label())

  // 5. UTM 补全 + 渲染 + QA
  let tracked = @links.attach_utms(approved, "ttw-01")
  let html = @render.render_html(tracked)
  println("HTML: " + html.length().to_string() + " chars")
  let qa_problems = @qa.run_qa("Subject here", "Preview here", tracked)
  println("QA: " + (if qa_problems.is_empty() {
    "pass"
  } else {
    qa_problems.join(" | ")
  }))

  // 6. 复盘反馈回流
  let entry = @retro.record("ttw-01", "回复率不错，但价格未确认", @retro.suggest_rules(
    "价格未确认就用了占位",
  ))
  let next = @retro.apply_rules(brief, entry)
  println("下期规则: " + next.goals.length().to_string() + " 条")
}
