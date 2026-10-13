///|
/// 系列级 QA 测试：标题多样性、CTA 差异化

test "系列内标题重复被检出" {
  let i1 = @core.Issue::new("1", "同样的标题")
  let i2 = @core.Issue::new("2", "同样的标题")
  let series = { ..@core.Series::new("s", "系列"), issues: [i1, i2] }
  let problems = @qa.check_series_title_diversity(series)
  assert_true(problems.length() == 1)
  assert_true(problems[0].contains("标题重复"))
}

test "主行动目标多期重复被检出" {
  let b1 = @core.Block::new(@core.BlockKind::Cta, "买 A", "第一期的行动")
  b1.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "买 A", "https://shop.example/a"))
  let b2 = @core.Block::new(@core.BlockKind::Cta, "买 A 复购", "第二期的行动")
  b2.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "买 A", "https://shop.example/a"))
  let i1 = { ..@core.Issue::new("1", "第一期"), blocks: [b1], claims: [], status: @core.IssueStatus::Draft }
  let i2 = { ..@core.Issue::new("2", "第二期"), blocks: [b2], claims: [], status: @core.IssueStatus::Draft }
  let series = { ..@core.Series::new("s", "系列"), issues: [i1, i2] }
  let problems = @qa.check_cta_diversity(series)
  assert_true(problems.length() == 1)
  assert_true(problems[0].contains("多期重复"))
}

test "多样化系列通过检查" {
  let b1 = @core.Block::new(@core.BlockKind::Cta, "试用", "第一期的行动")
  b1.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "试用", "https://shop.example/trial"))
  let b2 = @core.Block::new(@core.BlockKind::Cta, "订阅", "第二期的行动")
  b2.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "订阅", "https://shop.example/sub"))
  let i1 = { ..@core.Issue::new("1", "第一期"), blocks: [b1], claims: [], status: @core.IssueStatus::Draft }
  let i2 = { ..@core.Issue::new("2", "第二期"), blocks: [b2], claims: [], status: @core.IssueStatus::Draft }
  let series = { ..@core.Series::new("s", "系列"), issues: [i1, i2] }
  let problems = @qa.run_series_qa(series)
  assert_true(problems.is_empty())
}

test "严重等级分类" {
  match @qa.classify("链接协议非法：x -> y") {
    Blocker => ()
    _ => assert_true(false)
  }
  match @qa.classify("图片模块缺少 alt 文本：「x」") {
    Warning => ()
    _ => assert_true(false)
  }
  match @qa.classify("邮件主题过长（80 字符，建议 ≤ 60）") {
    Info => ()
    _ => assert_true(false)
  }
}

test "render_checklist 空问题输出通过" {
  let s = @qa.render_checklist([])
  assert_true(s.contains("全部通过"))
}

test "render_checklist 分级输出" {
  let problems : Array[String] = []
  problems.push("链接协议非法：x -> y")
  problems.push("图片模块缺少 alt 文本：「x」")
  problems.push("邮件主题过长（80 字符，建议 ≤ 60）")
  let s = @qa.render_checklist(problems)
  assert_true(s.contains("阻断"))
  assert_true(s.contains("警告"))
  assert_true(s.contains("提示"))
}
