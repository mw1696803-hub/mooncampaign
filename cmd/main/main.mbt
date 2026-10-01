///|
/// mooncampaign CLI
///
/// 用法（参数经 `--` 传入）：
///   moon run cmd/main -- demo                完整闭环演示（默认）
///   moon run cmd/main -- gate                事实/声明门禁演示
///   moon run cmd/main -- json '<JSON>'       解析 Campaign/Issue JSON 并诊断
///   moon run cmd/main -- retro '<反馈>'      复盘反馈 → 规则提炼
///   moon run cmd/main -- help                用法说明
fn main {
  let args = @env.args()
  // args[0] 为可执行文件路径，args[1] 起为子命令与参数
  let cmd = if args.length() > 1 { args[1] } else { "demo" }
  match cmd {
    "demo" => run_demo()
    "gate" => run_gate()
    "json" => run_json(args)
    "retro" => run_retro(args)
    "help" => print_help()
    _ => {
      println("未知命令: " + cmd)
      print_help()
    }
  }
}

fn print_help() -> Unit {
  println("mooncampaign · 类型安全的系列内容编排引擎")
  println("用法: moon run cmd/main -- <command> [args]")
  println("  demo             完整闭环演示（默认）")
  println("  gate             事实/声明门禁演示")
  println("  json '<JSON>'    解析 Campaign/Issue JSON 并诊断")
  println("  retro '<反馈>'   复盘反馈 → 规则提炼")
  println("  help             显示本说明")
}

/// 提取子命令之后的参数（跳过程序路径与命令名）
fn cmd_args(args : Array[String]) -> Array[String] {
  let rest : Array[String] = []
  let mut i = 2
  while i < args.length() {
    rest.push(args[i])
    i = i + 1
  }
  rest
}

/// demo：完整闭环演示（编排 → 门禁 → UTM → 渲染 → QA → 复盘）
fn run_demo() -> Unit {
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
      if l.role == @core.LinkRole::PrimaryCta && cta_link is None {
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

/// gate：事实/声明门禁演示
fn run_gate() -> Unit {
  let brief = build_brief()
  let issue = build_issue()
  println("=== 门禁演示 ===")
  println("Brief 事实数: " + brief.facts.length().to_string())
  println("Issue 声明数: " + issue.claims.length().to_string())
  let (gated, problems) = @gates.gate(issue, brief)
  println("门禁结果 -> " + gated.status.label())
  for p in problems {
    println("  ! " + p)
  }
  let approved = @gates.approve(gated)
  let published = @gates.publish(approved)
  println("门禁状态机: " + gated.status.label() + " → approve → " +
    approved.status.label() + " → publish → " + published.status.label())
}

/// json：解析 Campaign/Issue JSON 并诊断
/// 参数来源优先级：命令行参数（引号正常的环境）> 环境变量 MOONCAMPAIGN_JSON
/// > 内置示例（Windows 下开箱即用）
fn run_json(args : Array[String]) -> Unit {
  let rest = cmd_args(args)
  let s = if rest.is_empty() {
    match @env.get_env_var("MOONCAMPAIGN_JSON") {
      Some(v) => v
      None => sample_campaign_json()
    }
  } else {
    rest[0]
  }
  match @render.json_to_campaign(s) {
    Some(campaign) => {
      println("=== Campaign 诊断 ===")
      println("产品: " + campaign.brief.product)
      println("受众: " + campaign.brief.audience)
      println("系列: " + campaign.series.name + "（" + campaign.series.issues.length().to_string() + " 期）")
      for i in campaign.series.issues {
        print_issue_diag(i)
      }
    }
    None => {
      match @render.json_to_issue(s) {
        Some(issue) => {
          println("=== Issue 诊断 ===")
          print_issue_diag(issue)
        }
        None => {
          println("JSON 解析失败：既不是 Campaign 也不是 Issue 格式")
          println("提示: Windows 下命令行传参会剥离引号，请用环境变量方式：")
          println("  $env:MOONCAMPAIGN_JSON='<JSON>'; moon run cmd/main -- json")
        }
      }
    }
  }
}

fn print_issue_diag(issue : @core.Issue) -> Unit {
  println("\n  - " + issue.title + " [" + issue.status.label() + "]")
  println("    模块数: " + issue.blocks.length().to_string())
  for b in issue.blocks {
    println("      * [" + b.kind.label() + "] " + b.title)
  }
  println("    声明数: " + issue.claims.length().to_string())
  for c in issue.claims {
    println("      ! [" + c.status.code() + "] " + c.text)
  }
  let qa_problems = @qa.run_qa(
    "diagnostic",
    "diagnostic",
    issue,
  )
  if qa_problems.is_empty() {
    println("    QA: 通过")
  } else {
    println("    QA: " + qa_problems.join(" | "))
  }
}

/// retro：复盘反馈 → 规则提炼
fn run_retro(args : Array[String]) -> Unit {
  let rest = cmd_args(args)
  if rest.is_empty() {
    println("用法: moon run cmd/main -- retro '<复盘反馈文本>'")
    return
  }
  let feedback = rest[0]
  let rules = @retro.suggest_rules(feedback)
  println("=== 复盘反馈 → 规则提炼 ===")
  println("反馈: " + feedback)
  println("提炼规则 " + rules.length().to_string() + " 条：")
  for r in rules {
    println("  - " + r)
  }
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

/// 内置示例 Campaign JSON（与 demo 数据一致，Windows 下无参演示用）
fn sample_campaign_json() -> String {
  "{\n" +
    "  \"brief\": {\n" +
    "    \"product\": \"Harbour & Salt 固体护手霜\",\n" +
    "    \"audience\": \"30-60 岁女性，英国市场\",\n" +
    "    \"goals\": [\"launch\", \"collect replies\"],\n" +
    "    \"facts\": [\n" +
    "      { \"key\": \"price\", \"value\": \"£12\", \"confirmed\": true },\n" +
    "      { \"key\": \"claim_8h\", \"value\": null, \"confirmed\": false }\n" +
    "    ]\n" +
    "  },\n" +
    "  \"series\": {\n" +
    "    \"id\": \"ttw\",\n" +
    "    \"name\": \"Tiny Travel Wins\",\n" +
    "    \"issues\": [\n" +
    "      {\n" +
    "        \"id\": \"ttw-01\",\n" +
    "        \"title\": \"Tiny Travel Wins #1\",\n" +
    "        \"status\": \"Draft\",\n" +
    "        \"blocks\": [\n" +
    "          { \"kind\": \"Story\", \"title\": \"One hand cream, three airports\", \"body\": \"我在三个机场之间只带了一支 50g 的固体护手霜。\", \"links\": [], \"image_alt\": null },\n" +
    "          { \"kind\": \"Cta\", \"title\": \"Try it this weekend\", \"body\": \"前 50 名回复的读者获赠试用装。\", \"links\": [ { \"role\": \"PrimaryCta\", \"label\": \"Shop now\", \"url\": \"https://shop.example/hs\", \"utm\": null } ], \"image_alt\": null }\n" +
    "        ],\n" +
    "        \"claims\": [\n" +
    "          { \"text\": \"8 hour hydration\", \"status\": \"Pending\", \"evidence\": null }\n" +
    "        ]\n" +
    "      }\n" +
    "    ]\n" +
    "  }\n" +
    "}"
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
