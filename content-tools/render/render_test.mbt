test "HTML 渲染包含标题与模块" {
  let issue = @core.Issue::new("i1", "Hello <World>")
  let b = @core.Block::new(@core.BlockKind::Story, "S", "body text")
  issue.blocks.push(b)
  let html = render_html(issue)
  assert_true(html.contains("Hello &lt;World&gt;"))
  assert_true(html.contains("<table"))
  assert_true(html.contains("body text"))
}

test "Markdown 渲染输出标题与链接" {
  let issue = @core.Issue::new("i1", "Title")
  let b = @core.Block::new(@core.BlockKind::Cta, "C", "body")
  b.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "Get it", "https://a.example"))
  issue.blocks.push(b)
  let md = render_markdown(issue)
  assert_true(md.contains("# Title"))
  assert_true(md.contains("[Get it](https://a.example)"))
}

test "JSON 渲染转义引号" {
  let issue = @core.Issue::new("i1", "say \"hi\"")
  let s = render_json(issue)
  assert_true(s.contains("\\\""))
  assert_true(s.contains("\"status\": \"Draft\""))
}

test "HTML 转义拦截危险字符" {
  assert_eq(escape_html("<script>&\"</script>"), "&lt;script&gt;&amp;&quot;&lt;/script&gt;")
}

test "纯文本渲染无 HTML 标签且链接可读" {
  let issue = @core.Issue::new("i1", "Weekly #1")
  let b = @core.Block::new(@core.BlockKind::Cta, "Buy now", "body")
  b.links.push(@core.Link::new(@core.LinkRole::PrimaryCta, "Shop", "https://shop.example"))
  issue.blocks.push(b)
  let txt = render_text(issue)
  assert_true(txt.contains("Weekly #1"))
  assert_true(txt.contains("[主行动] Buy now"))
  assert_true(txt.contains("Shop <https://shop.example>"))
  // 不能出现 HTML 标签
  assert_true(!txt.contains("<p"))
  assert_true(!txt.contains("<h2"))
}
