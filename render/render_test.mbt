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
