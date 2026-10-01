test "UTM 生成：无 query 时加问号" {
  let url = make_utm("https://shop.example/p", "ttw-01", "primary-cta")
  assert_true(url.starts_with("https://shop.example/p?utm_source=newsletter"))
  assert_true(url.contains("utm_campaign=ttw-01"))
  assert_true(url.contains("utm_content=primary-cta"))
}

test "UTM 生成：已有 query 时用 &" {
  let url = make_utm("https://shop.example/p?x=1", "c", "ct")
  assert_true(url.contains("?x=1&utm_source=newsletter"))
}

test "主行动唯一性：两个不同主行动 URL 被检出" {
  let issue = @core.Issue::new("i1", "x")
  let b1 = @core.Block::new(@core.BlockKind::Cta, "c1", "b")
  b1.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "A", "https://a.example"))
  let b2 = @core.Block::new(@core.BlockKind::Cta, "c2", "b")
  b2.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "B", "https://b.example"))
  issue.blocks.push(b1)
  issue.blocks.push(b2)
  assert_eq(check_primary_cta_uniqueness(issue).length(), 1)
}

test "同一主行动 URL 重复出现不报错" {
  let issue = @core.Issue::new("i1", "x")
  let b1 = @core.Block::new(@core.BlockKind::Cta, "c1", "b")
  b1.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "A", "https://a.example"))
  let b2 = @core.Block::new(@core.BlockKind::Product, "c2", "b")
  b2.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "A again", "https://a.example"))
  issue.blocks.push(b1)
  issue.blocks.push(b2)
  assert_eq(check_primary_cta_uniqueness(issue).length(), 0)
}

test "attach_utms 为所有链接补全 UTM" {
  let issue = @core.Issue::new("i1", "x")
  let b = @core.Block::new(@core.BlockKind::Cta, "c", "b")
  b.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "A", "https://a.example"))
  issue.blocks.push(b)
  let updated = attach_utms(issue, "ttw-01")
  assert_eq(check_utms_attached(updated).length(), 0)
  // 原对象不被修改
  assert_eq(check_utms_attached(issue).length(), 1)
}
