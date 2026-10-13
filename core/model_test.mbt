test "新一期默认 Draft 状态" {
  let issue = Issue::new("i1", "Issue One")
  assert_eq(issue.status, @core.IssueStatus::Draft)
}

test "新系列默认无期数" {
  let series = Series::new("ttw", "Tiny Travel Wins")
  assert_eq(series.issues.length(), 0)
}

test "已确认事实与非确认事实" {
  let f1 = Fact::confirmed("price", "£12")
  let f2 = Fact::pending("launch_date")
  assert_true(f1.confirmed)
  assert_false(f2.confirmed)
  assert_eq(f2.value, None)
}

test "Campaign 组合 Brief 与 Series" {
  let brief = Brief::new("Solid Hand Cream", "30-60 岁女性，英国")
  brief.goals.push("launch")
  brief.goals.push("collect replies")
  brief.facts.push(Fact::pending("claim_8h"))
  let series = Series::new("ttw", "Tiny Travel Wins")
  let campaign = Campaign::new(brief, series)
  assert_eq(campaign.brief.product, "Solid Hand Cream")
  assert_eq(campaign.series.id, "ttw")
}

test "阅读时长估算：空期最少 1 分钟" {
  let issue = Issue::new("i1", "Title")
  assert_eq(issue.estimated_reading_minutes(), 1)
}

test "阅读时长估算：按字数换算" {
  let issue = Issue::new("i1", "Title")
  // 900 字符正文 ≈ 3 分钟
  let body = repeat_str("a", 900)
  issue.blocks.push(Block::new(BlockKind::Story, "Story", body))
  let mins = issue.estimated_reading_minutes()
  assert_true(mins >= 2 && mins <= 4)
  assert_true(issue.total_chars() > 900)
}

fn repeat_str(s : String, n : Int) -> String {
  let mut out = ""
  for i = 0; i < n; i = i + 1 {
    out = out + s
  }
  out
}