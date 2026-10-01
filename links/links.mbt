///|
/// campaign-links：链接编排 + UTM
///
/// 来自真实项目的规则：
///   - 一封邮件只有一个主行动（PrimaryCta），其余链接按前/中/后位置
///     承担不同职责，主链接可以重复出现但角色必须一致；
///   - 所有外链必须携带 UTM，用于归因复盘。

/// 从 base url 生成带 UTM 的链接
/// campaign 与 content 会被 URL 编码后拼入 query
pub fn make_utm(url : String, campaign : String, content : String) -> String {
  let sep = if url.contains("?") { "&" } else { "?" }
  url + sep + "utm_source=newsletter&utm_medium=email&utm_campaign=" +
    encode(campaign) + "&utm_content=" + encode(content)
}

/// 全期主行动唯一性：主行动 URL 至多一个（可多次出现，但指向同一目标）
pub fn check_primary_cta_uniqueness(issue : @core.Issue) -> Array[String] {
  let urls : Array[String] = []
  for b in issue.blocks {
    for l in b.links {
      if l.role == @core.LinkRole::PrimaryCta && !urls.contains(l.url) {
        urls.push(l.url)
      }
    }
  }
  if urls.length() > 1 {
    ["主行动链接超过一个：" + urls.join(", ")]
  } else {
    []
  }
}

/// 为一期所有链接补全 UTM（返回新 Issue，不修改原对象）
pub fn attach_utms(issue : @core.Issue, campaign : String) -> @core.Issue {
  let blocks : Array[@core.Block] = []
  for b in issue.blocks {
    let links : Array[@core.Link] = []
    for l in b.links {
      let content = l.role.label() + "@" + b.kind.label()
      links.push({ ..l, utm: Some(make_utm(l.url, campaign, content)) })
    }
    blocks.push({ ..b, links })
  }
  { ..issue, blocks }
}

/// 检查一期所有链接是否都已生成 UTM
pub fn check_utms_attached(issue : @core.Issue) -> Array[String] {
  let problems : Array[String] = []
  for b in issue.blocks {
    for l in b.links {
      if l.utm == None {
        problems.push("链接缺少 UTM：" + l.label + " -> " + l.url)
      }
    }
  }
  problems
}

/// 简易 URL 编码（仅覆盖常见字符，足够 UTM 场景使用）
fn encode(s : String) -> String {
  let mut out = ""
  for ch in s {
    out = out + encode_char(ch)
  }
  out
}

fn encode_char(ch : Char) -> String {
  match ch {
    ' ' => "%20"
    '&' => "%26"
    '=' => "%3D"
    '?' => "%3F"
    '#' => "%23"
    ',' => "%2C"
    _ => ch.to_string()
  }
}
