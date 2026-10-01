///|
/// mooncampaign CLI 演示入口
///
/// 运行：moon run cmd/main
/// 演示一个虚构品牌 Campaign 从 Brief 到复盘反馈的完整闭环：
///   编排检查 → 门禁（先失败后通过）→ UTM 补全 → 渲染 → QA → 复盘
fn main {
  println("=== mooncampaign 系列内容编排引擎 · 演示 ===")

  // 1. Campaign Brief：事实冻结的入口
  let brief = build_brief()
  println("\n[1] Campaign Brief")
  println("    产品: " + brief.product)
  println("    受众: " + brief.audience)
  println("    事实数: " + brief.facts.length().to_string() + "（其中 1 条未确认，门禁将强制占位）")

  // 2. 系列与单期：五个模块按信息类型交替编排
  let issue = build_issue()
  println("\n[2] 单期模块编排（" + issue.blocks.length().to_string() + " 个模块）")
  for b in issue.blocks {
    println("    - [" + b.kind.label() + "] " + b.title)
  }

  // 3. 编排规则检查
  let seq_problems = @dsl.check_sequence(issue.blocks)
  println("\n[3] 编排规则检查: " + (if seq_problems.is_empty() {
    "通过"
  } else {
    seq_problems.join(" | ")
  }))

  // 4. 门禁：故意保留一条待核验声明 → 失败；核验后重跑 → 通过
  println("\n[4] 事实/声明门禁")
  let (gated1, gate_problems) = @gates.gate(issue, brief)
  println("    首次门禁 -> " + gated1.status.label() + "，问题数: " +
    gate_problems.length().to_string())
  for p in gate_problems {
    println("      ! " + p)
  }
  let fixed_claims : Array[@core.Claim] = []
  for c in issue.claims {
    let updated = if c.status == @core.ClaimStatus::Pending {
      { ..c, status: @core.ClaimStatus::Approved, evidence: Some("R&D doc v2（已核验）") }
    } else {
      c
    }
    fixed_claims.push(updated)
  }
  let fixed_issue = { ..issue, claims: fixed_claims }
  // 同步核验 Brief 中的事实：未确认事实转为已确认
  let fixed_facts : Array[@core.Fact] = []
  for f in brief.facts {
    let updated = if f.confirmed {
      f
    } else {
      @core.Fact::confirmed(f.key, "8 hours（已核验）")
    }
    fixed_facts.push(updated)
  }
  let fixed_brief = { ..brief, facts: fixed_facts }
  let (ready, _) = @gates.gate(fixed_issue, fixed_brief)
  println("    核验后门禁 -> " + ready.status.label())
  let approved = @gates.approve(ready)
  println("    人工验收 -> " + approved.status.label())

  // 5. UTM 补全
  let tracked = @links.attach_utms(approved, "ttw-01")
  println("\n[5] UTM 补全: 缺失数 " + @links.check_utms_attached(tracked).length().to_string())
  let mut cta_link : @core.Link? = None
  for b in tracked.blocks {
    for l in b.links {
      if l.role == @core.LinkRole::PrimaryCta && cta_link.is_none() {
        cta_link = Some(l)
      }
    }
  }
  match cta_link {
    Some(l) => {
      match l.utm {
        Some(u) => println("    示例 UTM: " + u)
        None => println("    示例 UTM: (无)")
      }
    }
    None => println("    示例 UTM: (未找到主行动链接)")
  }

  // 6. 渲染
  println("\n[6] 渲染")
  println("    HTML 长度: " + @render.render_html(tracked).length().to_string() + " 字符")
  println("    Markdown 长度: " + @render.render_markdown(tracked).length().to_string() + " 字符")
  println("    JSON 片段: " + take(@render.render_json(tracked), 60) + " ...")

  // 7. QA
  let qa_problems = @qa.run_qa(
    "The one hand cream to carry everywhere",
    "Real people, real tests, one honest review",
    tracked,
  )
  println("\n[7] 发布前 QA: " + (if qa_problems.is_empty() { "通过" } else { qa_problems.join(" | ") }))

  // 8. 复盘反馈闭环
  println("\n[8] 复盘反馈")
  let feedback = "本期产品写错了对象，价格未确认就用了占位"
  let rules = @retro.suggest_rules(feedback)
  for r in rules {
    println("    - 规则: " + r)
  }
  let entry = @retro.record("ttw-01", feedback, rules)
  let next_brief = @retro.apply_rules(brief, entry)
  println("    下一期 Brief 规则数: " + next_brief.goals.length().to_string())

  println("\n=== 闭环完成：下一期继续 ===")
}

/// 构造虚构品牌 Campaign Brief
fn build_brief() -> @core.Brief {
  let brief = @core.Brief::new("Harbour & Salt 固体护手霜", "30-60 岁女性，英国市场")
  brief.goals.push("launch")
  brief.goals.push("collect replies")
  brief.facts.push(@core.Fact::confirmed("price", "£12"))
  brief.facts.push(@core.Fact::confirmed("size", "50g"))
  // 未确认事实：门禁将强制占位
  brief.facts.push(@core.Fact::pending("claim_8h"))
  brief
}

/// 构造单期内容：五个模块按 故事→痛点→证据→产品→主行动 交替
fn build_issue() -> @core.Issue {
  let issue = @core.Issue::new("ttw-01", "Tiny Travel Wins #1")
  let story = @core.Block::new(
    @core.BlockKind::Story,
    "One hand cream, three airports",
    "我在三个机场之间只带了一支 50g 的固体护手霜。",
  )
  let pain = @core.Block::new(
    @core.BlockKind::Pain,
    "Liquid in a cabin bag is a lie",
    "超过 100ml 的液体永远会在安检被拦下来。",
  )
  let evidence = @core.Block::new(
    @core.BlockKind::Evidence,
    "What testers said",
    "“I stopped reapplying every hour” —— 3 位测试者的原话。",
  )
  let product = @core.Block::new(
    @core.BlockKind::Product,
    "Harbour & Salt, solid",
    "固体配方，无需托运，直接放口袋。",
  )
  product.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "Get it", "https://shop.example/hs"))
  let cta = @core.Block::new(
    @core.BlockKind::Cta,
    "Try it this weekend",
    "前 50 名回复的读者获赠试用装。",
  )
  cta.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "Shop now", "https://shop.example/hs"))
  cta.links.push(@core.Link::new(@core.LinkRole::Reply, "Reply", "mailto:hello@example.com"))
  issue.blocks.push(story)
  issue.blocks.push(pain)
  issue.blocks.push(evidence)
  issue.blocks.push(product)
  issue.blocks.push(cta)
  // 一条待核验声明：门禁会拦截
  issue.claims.push(@core.Claim::new("8 hour hydration"))
  issue
}


/// 取字符串前 n 个字符（UTF-16 安全近似）
fn take(s : String, n : Int) -> String {
  if s.length() <= n {
    s
  } else {
    let mut out = ""
    let mut i = 0
    for ch in s {
      if i >= n {
        break
      }
      out = out + ch.to_string()
      i = i + 1
    }
    out
  }
}