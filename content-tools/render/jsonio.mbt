///|
/// campaign-jsonio：Campaign / Issue / Brief 的完整 JSON 序列化与反序列化
///
/// 自包含实现（不依赖 @json 的可见性限制，输出格式完全可控），
/// 供 Agent / 工具链做 Campaign 的导入导出、迁移与存档。
/// 解析器支持对象/数组/字符串/数字/bool/null，字符串转义含 \uXXXX（含代理对）。

// ---------- 序列化 ----------

/// 序列化单期内容（完整字段：链接 UTM、声明证据、图片 alt）
pub fn issue_to_json(issue : @core.Issue) -> String {
  let mut s = "{\n"
  s = s + "  \"id\": " + js_str(issue.id) + ",\n"
  s = s + "  \"title\": " + js_str(issue.title) + ",\n"
  s = s + "  \"status\": " + js_str(issue.status.code()) + ",\n"
  s = s + "  \"blocks\": [\n"
  let mut first = true
  for b in issue.blocks {
    if !first {
      s = s + ",\n"
    }
    first = false
    s = s + block_to_json(b, "    ")
  }
  s = s + "\n  ],\n"
  s = s + "  \"claims\": [\n"
  first = true
  for c in issue.claims {
    if !first {
      s = s + ",\n"
    }
    first = false
    s = s + claim_to_json(c, "    ")
  }
  s = s + "\n  ]\n}"
  s
}

/// 序列化 Campaign Brief（事实冻结入口）
pub fn brief_to_json(brief : @core.Brief) -> String {
  let mut s = "{\n"
  s = s + "  \"product\": " + js_str(brief.product) + ",\n"
  s = s + "  \"audience\": " + js_str(brief.audience) + ",\n"
  s = s + "  \"goals\": ["
  let mut first = true
  for g in brief.goals {
    if !first {
      s = s + ", "
    }
    first = false
    s = s + js_str(g)
  }
  s = s + "],\n"
  s = s + "  \"facts\": [\n"
  first = true
  for f in brief.facts {
    if !first {
      s = s + ",\n"
    }
    first = false
    s = s + fact_to_json(f, "    ")
  }
  s = s + "\n  ]\n}"
  s
}

/// 序列化一个系列（含全部期数）
pub fn series_to_json(series : @core.Series) -> String {
  let mut s = "{\n"
  s = s + "  \"id\": " + js_str(series.id) + ",\n"
  s = s + "  \"name\": " + js_str(series.name) + ",\n"
  s = s + "  \"issues\": [\n"
  let mut first = true
  for i in series.issues {
    if !first {
      s = s + ",\n"
    }
    first = false
    s = s + indent_lines(issue_to_json(i), "    ")
  }
  s = s + "\n  ]\n}"
  s
}

/// 序列化整个 Campaign（Brief + Series）
pub fn campaign_to_json(campaign : @core.Campaign) -> String {
  let mut s = "{\n"
  s = s + "  \"brief\": " + indent_lines(brief_to_json(campaign.brief), "  ") + ",\n"
  s = s + "  \"series\": " + indent_lines(series_to_json(campaign.series), "  ") + "\n"
  s = s + "}"
  s
}

/// 给多行字符串的每行（除首行）加缩进（嵌套对象对齐用）
fn indent_lines(s : String, pad : String) -> String {
  let mut out = ""
  for ch in s {
    if ch == '\n' {
      out = out + "\n" + pad
    } else {
      out = out + ch.to_string()
    }
  }
  out
}

fn block_to_json(b : @core.Block, indent : String) -> String {
  let mut s = indent + "{ \"kind\": " + js_str(b.kind.code()) + ",\n"
  s = s + indent + "  \"title\": " + js_str(b.title) + ",\n"
  s = s + indent + "  \"body\": " + js_str(b.body) + ",\n"
  s = s + indent + "  \"links\": ["
  let mut first = true
  for l in b.links {
    if !first {
      s = s + ", "
    }
    first = false
    s = s + link_to_json(l)
  }
  s = s + "],\n"
  s = s + indent + "  \"image_alt\": " + js_opt_str(b.image_alt) + "\n"
  s = s + indent + "}"
  s
}

fn link_to_json(l : @core.Link) -> String {
  "{ \"role\": " + js_str(l.role.code()) + ", \"label\": " + js_str(l.label) +
    ", \"url\": " + js_str(l.url) + ", \"utm\": " + js_opt_str(l.utm) + " }"
}

fn claim_to_json(c : @core.Claim, indent : String) -> String {
  indent + "{ \"text\": " + js_str(c.text) + ", \"status\": " + js_str(c.status.code()) +
    ", \"evidence\": " + js_opt_str(c.evidence) + " }"
}

fn fact_to_json(f : @core.Fact, indent : String) -> String {
  indent + "{ \"key\": " + js_str(f.key) + ", \"value\": " + js_opt_str(f.value) +
    ", \"confirmed\": " + (if f.confirmed { "true" } else { "false" }) + " }"
}

/// JSON 字符串转义（含制表符与回车）
fn js_str(s : String) -> String {
  let mut out = "\""
  for ch in s {
    out = out + js_escape_char(ch)
  }
  out = out + "\""
  out
}

fn js_escape_char(ch : Char) -> String {
  match ch {
    '"' => "\\\""
    '\\' => "\\\\"
    '\n' => "\\n"
    '\t' => "\\t"
    '\r' => "\\r"
    _ => ch.to_string()
  }
}

/// Option[String] 序列化为 JSON 字符串或 null
fn js_opt_str(s : String?) -> String {
  match s {
    Some(v) => js_str(v)
    None => "null"
  }
}

// ---------- 反序列化 ----------

/// 极简 JSON 值（对象用有序 KV 数组，保持字段顺序）
enum JVal {
  JNull
  JBool(Bool)
  JNum(Double)
  JStr(String)
  JArr(Array[JVal])
  JObj(Array[(String, JVal)])
}

struct JParser {
  chars : Array[Char]
  mut pos : Int
}

fn jp_new(s : String) -> JParser {
  let cs : Array[Char] = []
  for ch in s {
    cs.push(ch)
  }
  { chars: cs, pos: 0 }
}

fn jp_peek(p : JParser) -> Char? {
  if p.pos < p.chars.length() {
    Some(p.chars[p.pos])
  } else {
    None
  }
}

fn jp_skip_ws(p : JParser) -> Unit {
  while true {
    match jp_peek(p) {
      Some(' ') | Some('\n') | Some('\t') | Some('\r') => p.pos = p.pos + 1
      _ => break
    }
  }
}

fn jp_consume(p : JParser, word : String) -> Bool {
  for ch in word {
    match jp_peek(p) {
      Some(c) if c == ch => p.pos = p.pos + 1
      _ => return false
    }
  }
  true
}

fn jp_parse_value(p : JParser) -> JVal? {
  jp_skip_ws(p)
  match jp_peek(p) {
    Some('{') => jp_parse_object(p)
    Some('[') => jp_parse_array(p)
    Some('"') => jp_parse_string(p)
    Some('t') => {
      if jp_consume(p, "true") {
        Some(JBool(true))
      } else {
        None
      }
    }
    Some('f') => {
      if jp_consume(p, "false") {
        Some(JBool(false))
      } else {
        None
      }
    }
    Some('n') => {
      if jp_consume(p, "null") {
        Some(JNull)
      } else {
        None
      }
    }
    Some(_) => jp_parse_number(p)
    None => None
  }
}

fn jp_parse_number(p : JParser) -> JVal? {
  let mut buf = ""
  while true {
    match jp_peek(p) {
      Some(ch) if ch >= '0' && ch <= '9' || ch == '-' || ch == '+' || ch == '.' ||
        ch == 'e' || ch == 'E' => {
        buf = buf + ch.to_string()
        p.pos = p.pos + 1
      }
      _ => break
    }
  }
  if buf.length() == 0 {
    None
  } else {
    // 领域模型不消费数字字段，仅保证结构合法
    Some(JNum(0.0))
  }
}

fn jp_parse_string(p : JParser) -> JVal? {
  match jp_peek(p) {
    Some('"') => p.pos = p.pos + 1
    _ => return None
  }
  let mut out = ""
  while true {
    match jp_peek(p) {
      None => return None
      Some('"') => {
        p.pos = p.pos + 1
        break
      }
      Some('\\') => {
        p.pos = p.pos + 1
        match jp_peek(p) {
          None => return None
          Some('"') => {
            out = out + "\""
            p.pos = p.pos + 1
          }
          Some('\\') => {
            out = out + "\\"
            p.pos = p.pos + 1
          }
          Some('/') => {
            out = out + "/"
            p.pos = p.pos + 1
          }
          Some('b') => {
            out = out + Char::from_int(8).to_string()
            p.pos = p.pos + 1
          }
          Some('f') => {
            out = out + Char::from_int(12).to_string()
            p.pos = p.pos + 1
          }
          Some('n') => {
            out = out + "\n"
            p.pos = p.pos + 1
          }
          Some('r') => {
            out = out + "\r"
            p.pos = p.pos + 1
          }
          Some('t') => {
            out = out + "\t"
            p.pos = p.pos + 1
          }
          Some('u') => {
            p.pos = p.pos + 1
            match jp_parse_unicode_escape(p) {
              Some(c) => {
                out = out + c.to_string()
                ()
              }
              None => return None
            }
          }
          _ => return None
        }
      }
      Some(ch) => {
        out = out + ch.to_string()
        p.pos = p.pos + 1
      }
    }
  }
  Some(JStr(out))
}

/// \uXXXX 转义：支持 BMP 码点与代理对组合
fn jp_parse_unicode_escape(p : JParser) -> Char? {
  match jp_read_hex4(p) {
    None => None
    Some(hi) => {
      if hi >= 0xD800 && hi <= 0xDBFF {
        // 高代理：必须紧跟 \uDC00-\uDFFF 低代理
        if p.pos + 1 < p.chars.length() && p.chars[p.pos] == '\\' &&
          p.chars[p.pos + 1] == 'u' {
          p.pos = p.pos + 2
          match jp_read_hex4(p) {
            None => None
            Some(lo) => {
              if lo >= 0xDC00 && lo <= 0xDFFF {
                let code = 0x10000 + ((hi - 0xD800) * 0x400) + (lo - 0xDC00)
                Some(Char::from_int(code))
              } else {
                None
              }
            }
          }
        } else {
          None
        }
      } else if hi >= 0xDC00 && hi <= 0xDFFF {
        None // 孤立低代理
      } else {
        Some(Char::from_int(hi))
      }
    }
  }
}

/// 读取 4 位十六进制并转成码点数值
fn jp_read_hex4(p : JParser) -> Int? {
  let mut val = 0
  let mut n = 0
  while n < 4 {
    match jp_peek(p) {
      None => return None
      Some(ch) => {
        match hex_val(ch) {
          None => return None
          Some(d) => {
            val = val * 16 + d
            p.pos = p.pos + 1
            n = n + 1
          }
        }
      }
    }
  }
  Some(val)
}

fn hex_val(ch : Char) -> Int? {
  match ch {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    'a' | 'A' => Some(10)
    'b' | 'B' => Some(11)
    'c' | 'C' => Some(12)
    'd' | 'D' => Some(13)
    'e' | 'E' => Some(14)
    'f' | 'F' => Some(15)
    _ => None
  }
}

fn jp_parse_array(p : JParser) -> JVal? {
  match jp_peek(p) {
    Some('[') => p.pos = p.pos + 1
    _ => return None
  }
  let items : Array[JVal] = []
  jp_skip_ws(p)
  match jp_peek(p) {
    Some(']') => {
      p.pos = p.pos + 1
      return Some(JArr(items))
    }
    _ => ()
  }
  while true {
    match jp_parse_value(p) {
      None => return None
      Some(v) => items.push(v)
    }
    jp_skip_ws(p)
    match jp_peek(p) {
      Some(',') => p.pos = p.pos + 1
      Some(']') => {
        p.pos = p.pos + 1
        break
      }
      _ => return None
    }
  }
  Some(JArr(items))
}

fn jp_parse_object(p : JParser) -> JVal? {
  match jp_peek(p) {
    Some('{') => p.pos = p.pos + 1
    _ => return None
  }
  let kvs : Array[(String, JVal)] = []
  jp_skip_ws(p)
  match jp_peek(p) {
    Some('}') => {
      p.pos = p.pos + 1
      return Some(JObj(kvs))
    }
    _ => ()
  }
  while true {
    jp_skip_ws(p)
    let key = match jp_parse_string(p) {
      None => return None
      Some(JStr(k)) => k
      Some(_) => return None
    }
    jp_skip_ws(p)
    match jp_peek(p) {
      Some(':') => p.pos = p.pos + 1
      _ => return None
    }
    jp_skip_ws(p)
    match jp_parse_value(p) {
      None => return None
      Some(v) => kvs.push((key, v))
    }
    jp_skip_ws(p)
    match jp_peek(p) {
      Some(',') => p.pos = p.pos + 1
      Some('}') => {
        p.pos = p.pos + 1
        break
      }
      _ => return None
    }
  }
  Some(JObj(kvs))
}

/// 从有序 KV 中取键值
fn jp_find(kvs : Array[(String, JVal)], key : String) -> JVal? {
  for kv in kvs {
    if kv.0 == key {
      return Some(kv.1)
    }
  }
  None
}

// ---------- JVal → 领域模型 ----------

fn jval_str(v : JVal) -> String? {
  match v {
    JStr(s) => Some(s)
    _ => None
  }
}

fn jval_arr(v : JVal) -> Array[JVal]? {
  match v {
    JArr(a) => Some(a)
    _ => None
  }
}

/// null → None；字符串 → Some
fn jval_opt_str(v : JVal) -> String? {
  match v {
    JNull => None
    JStr(s) => Some(s)
    _ => None
  }
}

fn jval_obj(v : JVal) -> Array[(String, JVal)]? {
  match v {
    JObj(k) => Some(k)
    _ => None
  }
}

/// 解析单期内容；失败返回 None
pub fn json_to_issue(s : String) -> @core.Issue? {
  let p = jp_new(s)
  match jp_parse_value(p) {
    None => None
    Some(v) => {
      jp_skip_ws(p)
      if p.pos != p.chars.length() {
        None
      } else {
        jval_to_issue(v)
      }
    }
  }
}

fn jval_to_issue(v : JVal) -> @core.Issue? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let id = match jp_find(kvs, "id") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let title = match jp_find(kvs, "title") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let status = match jp_find(kvs, "status") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => match str_to_issue_status(s) {
            None => return None
            Some(st) => st
          }
        }
      }
      let blocks : Array[@core.Block] = []
      match jp_find(kvs, "blocks") {
        None => return None
        Some(x) => match jval_arr(x) {
          None => return None
          Some(arr) => {
            for jv in arr {
              match jval_to_block(jv) {
                None => return None
                Some(b) => blocks.push(b)
              }
            }
          }
        }
      }
      let claims : Array[@core.Claim] = []
      match jp_find(kvs, "claims") {
        None => return None
        Some(x) => match jval_arr(x) {
          None => return None
          Some(arr) => {
            for jv in arr {
              match jval_to_claim(jv) {
                None => return None
                Some(c) => claims.push(c)
              }
            }
          }
        }
      }
      let base = @core.Issue::new(id, title)
      Some({ ..base, blocks: blocks, claims: claims, status: status })
    }
  }
}

fn jval_to_block(v : JVal) -> @core.Block? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let kind = match jp_find(kvs, "kind") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => match str_to_block_kind(s) {
            None => return None
            Some(k) => k
          }
        }
      }
      let title = match jp_find(kvs, "title") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let body = match jp_find(kvs, "body") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let links : Array[@core.Link] = []
      match jp_find(kvs, "links") {
        None => ()
        Some(x) => match jval_arr(x) {
          None => return None
          Some(arr) => {
            for jv in arr {
              match jval_to_link(jv) {
                None => return None
                Some(l) => links.push(l)
              }
            }
          }
        }
      }
      let image_alt = match jp_find(kvs, "image_alt") {
        None => None
        Some(x) => jval_opt_str(x)
      }
      let base = @core.Block::new(kind, title, body)
      Some({ ..base, links: links, image_alt: image_alt })
    }
  }
}

fn jval_to_link(v : JVal) -> @core.Link? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let role = match jp_find(kvs, "role") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => match str_to_link_role(s) {
            None => return None
            Some(r) => r
          }
        }
      }
      let label = match jp_find(kvs, "label") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let url = match jp_find(kvs, "url") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let utm = match jp_find(kvs, "utm") {
        None => None
        Some(x) => jval_opt_str(x)
      }
      let base = @core.Link::new(role, label, url)
      Some({ ..base, utm: utm })
    }
  }
}

fn jval_to_claim(v : JVal) -> @core.Claim? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let text = match jp_find(kvs, "text") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let status = match jp_find(kvs, "status") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => match str_to_claim_status(s) {
            None => return None
            Some(st) => st
          }
        }
      }
      let evidence = match jp_find(kvs, "evidence") {
        None => None
        Some(x) => jval_opt_str(x)
      }
      let base = @core.Claim::new(text)
      Some({ ..base, status: status, evidence: evidence })
    }
  }
}

/// 解析 Campaign Brief
pub fn json_to_brief(s : String) -> @core.Brief? {
  let p = jp_new(s)
  match jp_parse_value(p) {
    None => None
    Some(v) => {
      jp_skip_ws(p)
      if p.pos != p.chars.length() {
        None
      } else {
        jval_to_brief(v)
      }
    }
  }
}

fn jval_to_brief(v : JVal) -> @core.Brief? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let product = match jp_find(kvs, "product") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let audience = match jp_find(kvs, "audience") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let goals : Array[String] = []
      match jp_find(kvs, "goals") {
        None => ()
        Some(x) => match jval_arr(x) {
          None => return None
          Some(arr) => {
            for jv in arr {
              match jval_str(jv) {
                None => return None
                Some(g) => goals.push(g)
              }
            }
          }
        }
      }
      let facts : Array[@core.Fact] = []
      match jp_find(kvs, "facts") {
        None => ()
        Some(x) => match jval_arr(x) {
          None => return None
          Some(arr) => {
            for jv in arr {
              match jval_to_fact(jv) {
                None => return None
                Some(f) => facts.push(f)
              }
            }
          }
        }
      }
      let base = @core.Brief::new(product, audience)
      Some({ ..base, goals: goals, facts: facts })
    }
  }
}

fn jval_to_fact(v : JVal) -> @core.Fact? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let key = match jp_find(kvs, "key") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let value = match jp_find(kvs, "value") {
        None => None
        Some(x) => jval_opt_str(x)
      }
      let confirmed = match jp_find(kvs, "confirmed") {
        None => return None
        Some(x) => match x {
          JBool(b) => b
          _ => return None
        }
      }
      Some({ key: key, value: value, confirmed: confirmed })
    }
  }
}

/// 解析整个 Campaign（Brief + Series）
pub fn json_to_campaign(s : String) -> @core.Campaign? {
  let p = jp_new(s)
  match jp_parse_value(p) {
    None => None
    Some(v) => {
      jp_skip_ws(p)
      if p.pos != p.chars.length() {
        None
      } else {
        match jval_obj(v) {
          None => None
          Some(kvs) => {
            let brief = match jp_find(kvs, "brief") {
              None => return None
              Some(x) => match jval_to_brief(x) {
                None => return None
                Some(b) => b
              }
            }
            let series = match jp_find(kvs, "series") {
              None => return None
              Some(x) => match jval_to_series(x) {
                None => return None
                Some(s) => s
              }
            }
            Some(@core.Campaign::new(brief, series))
          }
        }
      }
    }
  }
}

fn jval_to_series(v : JVal) -> @core.Series? {
  match jval_obj(v) {
    None => None
    Some(kvs) => {
      let id = match jp_find(kvs, "id") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let name = match jp_find(kvs, "name") {
        None => return None
        Some(x) => match jval_str(x) {
          None => return None
          Some(s) => s
        }
      }
      let issues : Array[@core.Issue] = []
      match jp_find(kvs, "issues") {
        None => return None
        Some(x) => match jval_arr(x) {
          None => return None
          Some(arr) => {
            for jv in arr {
              match jval_to_issue(jv) {
                None => return None
                Some(i) => issues.push(i)
              }
            }
          }
        }
      }
      let base = @core.Series::new(id, name)
      Some({ ..base, issues: issues })
    }
  }
}

// ---------- 枚举反查 ----------

fn str_to_issue_status(s : String) -> @core.IssueStatus? {
  if s == "Draft" { Some(@core.IssueStatus::Draft) } else if s == "Gated" {
    Some(@core.IssueStatus::Gated)
  } else if s == "Ready" { Some(@core.IssueStatus::Ready) } else if s == "Approved" {
    Some(@core.IssueStatus::Approved)
  } else if s == "Published" { Some(@core.IssueStatus::Published) } else {
    None
  }
}

fn str_to_block_kind(s : String) -> @core.BlockKind? {
  if s == "Story" { Some(@core.BlockKind::Story) } else if s == "Pain" {
    Some(@core.BlockKind::Pain)
  } else if s == "Evidence" { Some(@core.BlockKind::Evidence) } else if s == "Tip" {
    Some(@core.BlockKind::Tip)
  } else if s == "Product" { Some(@core.BlockKind::Product) } else if s == "Cta" {
    Some(@core.BlockKind::Cta)
  } else if s == "Resource" { Some(@core.BlockKind::Resource) } else if s == "Interaction" {
    Some(@core.BlockKind::Interaction)
  } else {
    None
  }
}

fn str_to_link_role(s : String) -> @core.LinkRole? {
  if s == "PrimaryCta" { Some(@core.LinkRole::PrimaryCta) } else if s == "Opening" {
    Some(@core.LinkRole::Opening)
  } else if s == "Middle" { Some(@core.LinkRole::Middle) } else if s == "Closing" {
    Some(@core.LinkRole::Closing)
  } else if s == "Resource" { Some(@core.LinkRole::Resource) } else if s == "Reply" {
    Some(@core.LinkRole::Reply)
  } else {
    None
  }
}

fn str_to_claim_status(s : String) -> @core.ClaimStatus? {
  if s == "Approved" { Some(@core.ClaimStatus::Approved) } else if s == "Pending" {
    Some(@core.ClaimStatus::Pending)
  } else if s == "Blocked" { Some(@core.ClaimStatus::Blocked) } else {
    None
  }
}
