///|
/// campaign-qa：发布前检查规则
///
/// 覆盖真实运营中常见的发布事故面：
/// 邮件主题超长被截断、链接失效/协议错误、图片缺 alt、正文重复。

/// 主题长度检查（经验阈值 ≤ 60 字符，可在调用方覆盖）
pub fn check_subject_length(subject : String) -> Array[String] {
  if subject.length() > 60 {
    ["邮件主题过长（" + subject.length().to_string() + " 字符，建议 ≤ 60）"]
  } else {
    []
  }
}

/// 预览文本长度检查（≤ 85 字符）
pub fn check_preview_length(preview : String) -> Array[String] {
  if preview.length() > 85 {
    ["预览文本过长（" + preview.length().to_string() + " 字符，建议 ≤ 85）"]
  } else {
    []
  }
}

/// 链接协议必须为 http/https（拦截 javascript: 等危险协议）
pub fn check_url_protocol(issue : @core.Issue) -> Array[String] {
  let problems : Array[String] = []
  for b in issue.blocks {
    for l in b.links {
      // Reply 角色允许 mailto:（回复型互动），其余必须 http/https
      let reply_mailto = l.role == @core.LinkRole::Reply && l.url.has_prefix("mailto:")
      if !l.url.has_prefix("http://") && !l.url.has_prefix("https://") && !reply_mailto {
        problems.push("链接协议非法：" + l.label + " -> " + l.url)
      }
    }
  }
  problems
}

/// 图片必须提供 alt（无障碍与 ESP 兼容性）
pub fn check_image_alt(issue : @core.Issue) -> Array[String] {
  let problems : Array[String] = []
  for b in issue.blocks {
    if b.image_alt == None {
      problems.push("图片模块缺少 alt 文本：「" + b.title + "」")
    }
  }
  problems
}

/// 相邻模块正文不得重复（内容重复度检查的简化版）
pub fn check_repeated_bodies(issue : @core.Issue) -> Array[String] {
  let problems : Array[String] = []
  let mut prev : String? = None
  for b in issue.blocks {
    if prev == Some(b.body) {
      problems.push("相邻模块正文重复：「" + b.title + "」")
    }
    prev = Some(b.body)
  }
  problems
}

/// 聚合 QA：主题、预览、链接、图片、正文
pub fn run_qa(subject : String, preview : String, issue : @core.Issue) -> Array[String] {
  let problems : Array[String] = []
  problems.append(check_subject_length(subject))
  problems.append(check_preview_length(preview))
  problems.append(check_url_protocol(issue))
  problems.append(check_image_alt(issue))
  problems.append(check_repeated_bodies(issue))
  problems
}

// ---------- 系列级 QA：多期之间的多样性与差异化 ----------

/// 系列多样性：期与期之间标题不得完全重复
pub fn check_series_title_diversity(series : @core.Series) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for i in series.issues {
    let mut dup = false
    for s in seen {
      if s == i.title {
        dup = true
      }
    }
    if dup {
      problems.push("系列内标题重复：「" + i.title + "」")
    } else {
      seen.push(i.title)
    }
  }
  problems
}

/// 系列多样性：主行动（PrimaryCta）目标不得多期完全相同，
/// 否则系列每期都在推同一件事，内容价值递减。
pub fn check_cta_diversity(series : @core.Series) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for i in series.issues {
    let mut cta_url : String? = None
    for b in i.blocks {
      for l in b.links {
        if l.role == @core.LinkRole::PrimaryCta && cta_url == None {
          cta_url = Some(l.url)
        }
      }
    }
    match cta_url {
      Some(url) => {
        let mut dup = false
        for s in seen {
          if s == url {
            dup = true
          }
        }
        if dup {
          problems.push("主行动目标多期重复：" + url + "（" + i.title + "）")
        } else {
          seen.push(url)
        }
      }
      None => ()
    }
  }
  problems
}

/// 系列级聚合检查
pub fn run_series_qa(series : @core.Series) -> Array[String] {
  let problems : Array[String] = []
  problems.append(check_series_title_diversity(series))
  problems.append(check_cta_diversity(series))
  problems
}
