///|
/// campaign-jsonio 测试：完整序列化、往返一致性、\u 转义、非法输入拒绝

fn sample_issue() -> @core.Issue {
  let b1 = @core.Block::new(
    @core.BlockKind::Story,
    "第一次开箱",
    "我们拆开包裹的那个下午",
  )
  let b2 = @core.Block::new(
    @core.BlockKind::Cta,
    "领取 8 折优惠",
    "点击下方按钮领取首单折扣",
  )
  let l1 = @core.Link::new(
    @core.LinkRole::PrimaryCta,
    "领取优惠",
    "https://example.com/discount",
  )
  let l2 = @core.Link::new(
    @core.LinkRole::Resource,
    "使用指南",
    "https://example.com/guide",
  )
  let issue = { ..@core.Issue::new("issue-001", "欢迎来到 Harbour & Salt"), blocks: [b1, b2], claims: [], status: @core.IssueStatus::Draft }
  { ..issue, blocks: [{ ..b1, links: [l1], image_alt: Some("开箱照片") }, { ..b2, links: [l2], image_alt: None }], claims: [{ ..@core.Claim::new("8 小时保湿"), status: @core.ClaimStatus::Pending, evidence: None }] }
}

test "issue json 完整字段" {
  let issue = sample_issue()
  let s = @render.issue_to_json(issue)
  assert_true(s.contains("\"status\": \"Draft\"") == true)
  assert_true(s.contains("\"kind\": \"Story\"") == true)
  assert_true(s.contains("\"utm\": null") == true)
  assert_true(s.contains("\"image_alt\": \"开箱照片\"") == true)
  assert_true(s.contains("\"role\": \"PrimaryCta\"") == true)
  assert_true(s.contains("\"evidence\": null") == true)
}

test "issue json 往返一致" {
  let issue = sample_issue()
  let json = @render.issue_to_json(issue)
  match @render.json_to_issue(json) {
    Some(parsed) => {
      assert_true(parsed.id == issue.id)
      assert_true(parsed.title == issue.title)
      assert_true(parsed.status == @core.IssueStatus::Draft)
      assert_true(parsed.blocks.length() == 2)
      assert_true(parsed.blocks[0].kind == @core.BlockKind::Story)
      assert_true(parsed.blocks[0].body == issue.blocks[0].body)
      assert_true(parsed.blocks[0].links.length() == 1)
      assert_true(parsed.blocks[0].links[0].role == @core.LinkRole::PrimaryCta)
      assert_true(parsed.blocks[0].links[0].utm is None)
      assert_true(parsed.blocks[0].image_alt == Some("开箱照片"))
      assert_true(parsed.claims.length() == 1)
      assert_true(parsed.claims[0].status == @core.ClaimStatus::Pending)
    }
    None => assert_true(false)
  }
}

test "json 转义解析（\\uXXXX 与代理对）" {
  let s = "{ \"id\": \"a\", \"title\": \"\\u4e2d\\u6587\", \"status\": \"Draft\", \"blocks\": [], \"claims\": [] }"
  match @render.json_to_issue(s) {
    Some(issue) => assert_true(issue.title == "中文")
    None => assert_true(false)
  }
  let s2 = "{ \"id\": \"a\", \"title\": \"\\uD83D\\uDE00\", \"status\": \"Draft\", \"blocks\": [], \"claims\": [] }"
  match @render.json_to_issue(s2) {
    Some(issue) => assert_true(issue.title == "😀")
    None => assert_true(false)
  }
}

test "json 非法输入返回 None" {
  assert_true(@render.json_to_issue("")  is None)
  assert_true(@render.json_to_issue("{bad") is None)
  assert_true(@render.json_to_issue("{\"id\": 1}") is None)
  assert_true(@render.json_to_issue("{\"id\": \"a\", \"status\": \"Nope\", \"blocks\": [], \"claims\": []}") is None)
  assert_true(@render.json_to_issue("[1, 2]") is None)
}

test "brief json 往返一致" {
  let brief = { ..@core.Brief::new("Harbour & Salt", "订阅用户"), goals: ["首单转化", "复购"], facts: [@core.Fact::confirmed("客单价", "268 元"), @core.Fact::pending("复购率")] }
  let json = @render.brief_to_json(brief)
  match @render.json_to_brief(json) {
    Some(parsed) => {
      assert_true(parsed.product == "Harbour & Salt")
      assert_true(parsed.goals.length() == 2)
      assert_true(parsed.facts.length() == 2)
      assert_true(parsed.facts[0].confirmed)
      assert_true(parsed.facts[1].value is None)
    }
    None => assert_true(false)
  }
}

test "campaign json 往返一致" {
  let brief = @core.Brief::new("Harbour & Salt", "订阅用户")
  let series = { ..@core.Series::new("s1", "欢迎系列"), issues: [sample_issue()] }
  let campaign = @core.Campaign::new(brief, series)
  let json = @render.campaign_to_json(campaign)
  match @render.json_to_campaign(json) {
    Some(parsed) => {
      assert_true(parsed.series.id == "s1")
      assert_true(parsed.series.issues.length() == 1)
      assert_true(parsed.series.issues[0].title == "欢迎来到 Harbour & Salt")
    }
    None => assert_true(false)
  }
}
