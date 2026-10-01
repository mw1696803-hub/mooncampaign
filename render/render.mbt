///|
/// campaign-render：HTML / Markdown / JSON 渲染
///
/// 渲染层刻意保持自包含（不依赖模板引擎），
/// 后续可替换为 moontemplate 等模板库作为适配器。

/// HTML 转义（防注入，QA 输出也使用）
pub fn escape_html(s : String) -> String {
  let mut out = ""
  for ch in s {
    out = out + escape_char(ch)
  }
  out
}

fn escape_char(ch : Char) -> String {
  match ch {
    '&' => "&amp;"
    '<' => "&lt;"
    '>' => "&gt;"
    '"' => "&quot;"
    _ => ch.to_string()
  }
}

/// 渲染为 ESP 兼容的 HTML email（table 布局，无外部依赖）
pub fn render_html(issue : @core.Issue) -> String {
  let mut html = "<!DOCTYPE html>\n<html>\n<body style=\"margin:0;padding:0;background-color:#f6f6f6;\">\n"
  html = html + "  <table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background-color:#f6f6f6;\">\n"
  html = html + "    <tr><td align=\"center\" style=\"padding:24px 12px;\">\n"
  html = html + "      <table role=\"presentation\" width=\"600\" cellpadding=\"0\" cellspacing=\"0\" style=\"background-color:#ffffff;border-radius:8px;\">\n"
  html = html + "        <tr><td style=\"padding:24px;\">\n"
  html = html + "          <h1 style=\"font-size:20px;margin:0 0 16px;\">" + escape_html(issue.title) + "</h1>\n"
  for b in issue.blocks {
    html = html + "          <h2 style=\"font-size:15px;margin:20px 0 6px;\">" +
      escape_html(b.title) + "</h2>\n"
    html = html + "          <p style=\"font-size:14px;line-height:1.6;margin:0 0 10px;\">" +
      escape_html(b.body) + "</p>\n"
    match b.image_alt {
      Some(alt) => {
        html = html + "          <img src=\"https://cdn.example/placeholder.png\" alt=\"" +
          escape_html(alt) + "\" style=\"max-width:100%;border-radius:6px;\" />\n"
      }
      None => ()
    }
    for l in b.links {
      html = html + "          <p><a href=\"" + escape_html(l.url) + "\" style=\"color:#1a73e8;\">" +
        escape_html(l.label) + "</a></p>\n"
    }
  }
  html = html + "        </td></tr>\n      </table>\n    </td></tr>\n  </table>\n</body>\n</html>"
  html
}

/// 渲染为 Markdown（便于人工审阅 / LLM 回流）
pub fn render_markdown(issue : @core.Issue) -> String {
  let mut md = "# " + issue.title + "\n\n"
  for b in issue.blocks {
    md = md + "## [" + b.kind.label() + "] " + b.title + "\n\n"
    md = md + b.body + "\n\n"
    for l in b.links {
      md = md + "- [" + l.label + "](" + l.url + ")\n"
    }
    md = md + "\n"
  }
  md
}

/// 渲染为 JSON（自包含序列化，供 Agent / 工具链消费）
pub fn render_json(issue : @core.Issue) -> String {
  let mut s = "{\n  \"id\": " + json_str(issue.id) + ",\n"
  s = s + "  \"title\": " + json_str(issue.title) + ",\n"
  s = s + "  \"status\": " + json_str(issue.status.label()) + ",\n"
  s = s + "  \"blocks\": [\n"
  let mut first = true
  for b in issue.blocks {
    if !first {
      s = s + ",\n"
    }
    first = false
    s = s + "    { \"kind\": " + json_str(b.kind.label()) + ", \"title\": " +
      json_str(b.title) + " }"
  }
  s = s + "\n  ]\n}"
  s
}

/// JSON 字符串转义
fn json_str(s : String) -> String {
  let mut out = "\""
  for ch in s {
    out = out + json_escape_char(ch)
  }
  out = out + "\""
  out
}

fn json_escape_char(ch : Char) -> String {
  match ch {
    '"' => "\\\""
    '\\' => "\\\\"
    '\n' => "\\n"
    _ => ch.to_string()
  }
}
