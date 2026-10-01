test "主题过长被检出" {
  assert_eq(check_subject_length("x".repeat(61)).length(), 1)
  assert_eq(check_subject_length("x".repeat(60)).length(), 0)
}

test "预览过长被检出" {
  assert_eq(check_preview_length("y".repeat(86)).length(), 1)
  assert_eq(check_preview_length("y".repeat(85)).length(), 0)
}

test "非法链接协议被检出" {
  let issue = @core.Issue::new("i1", "x")
  let b = @core.Block::new(@core.BlockKind::Resource, "r", "b")
  b.links.push(@core.Link::new(@core.LinkRole::Resource, "bad", "javascript:alert(1)"))
  issue.blocks.push(b)
  assert_eq(check_url_protocol(issue).length(), 1)
}

test "图片缺 alt 被检出" {
  let issue = @core.Issue::new("i1", "x")
  issue.blocks.push(@core.Block::new(@core.BlockKind::Story, "s", "b"))
  assert_eq(check_image_alt(issue).length(), 1)
}

test "相邻正文重复被检出" {
  let issue = @core.Issue::new("i1", "x")
  issue.blocks.push(@core.Block::new(@core.BlockKind::Story, "s1", "same"))
  issue.blocks.push(@core.Block::new(@core.BlockKind::Pain, "p1", "same"))
  assert_eq(check_repeated_bodies(issue).length(), 1)
}

test "run_qa 聚合全部问题" {
  let issue = @core.Issue::new("i1", "x")
  let b = @core.Block::new(@core.BlockKind::Resource, "r", "b")
  b.links.push(@core.Link::new(@core.LinkRole::Resource, "bad", "ftp://x"))
  issue.blocks.push(b)
  let problems = run_qa("s".repeat(70), "p".repeat(90), issue)
  // 主题 1 + 预览 1 + 协议 1 + 缺 alt 1
  assert_eq(problems.length(), 4)
}
