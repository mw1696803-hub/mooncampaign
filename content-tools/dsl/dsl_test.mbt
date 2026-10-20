test "相邻同类型模块被检出" {
  let block = @core.Block::new(@core.BlockKind::Product, "P", "b")
  let problems = check_no_adjacent_same_kind([block, block])
  assert_eq(problems.length(), 1)
}

test "不同信息类型交替通过" {
  let a = @core.Block::new(@core.BlockKind::Story, "S", "b")
  let b = @core.Block::new(@core.BlockKind::Pain, "P", "b")
  assert_eq(check_no_adjacent_same_kind([a, b, a]).length(), 0)
}

test "缺少主行动被检出" {
  let a = @core.Block::new(@core.BlockKind::Story, "S", "b")
  assert_eq(check_has_primary_cta([a]).length(), 1)
}

test "存在主行动则通过" {
  let link = @core.Link::new(@core.LinkRole::PrimaryCta, "Get it", "https://shop.example")
  let cta = @core.Block::new(@core.BlockKind::Cta, "C", "b")
  cta.links.push(link)
  assert_eq(check_has_primary_cta([cta]).length(), 0)
}

test "主行动放错模块被检出" {
  let link = @core.Link::new(@core.LinkRole::PrimaryCta, "Get it", "https://shop.example")
  let story = @core.Block::new(@core.BlockKind::Story, "S", "b")
  story.links.push(link)
  assert_eq(check_primary_cta_placement([story]).length(), 1)
}