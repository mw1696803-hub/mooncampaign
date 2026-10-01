///|
/// campaign-gates：事实 / 声明 / 验收门禁状态机
///
/// 来自真实项目的教训：
///   - 产品对象选错（曾把 Hand Wash 写成当期产品）→ 需要 Brief 事实锁定；
///   - 「8 小时保湿 / 屏障修护」未经核验不得直接写 → claim 门禁；
///   - 未确认的业务事实（价格、时间、成分）→ 强制占位，不得编默认值；
///   - 每期需要「人工验收」签字才能进入发布（Voice Owner 门禁）。

/// 声明门禁：Blocked 不得进入发布；Pending 必须占位或附证据
pub fn check_claims(claims : Array[@core.Claim]) -> Array[String] {
  let problems : Array[String] = []
  for c in claims {
    match c.status {
      @core.ClaimStatus::Blocked => problems.push("被阻断的声明不得进入发布稿：" + c.text)
      @core.ClaimStatus::Pending => {
        match c.evidence {
          None => problems.push("待核验声明必须占位或附证据：" + c.text)
          Some(_) => problems.push("待核验声明暂以「占位」形式保留（证据待人工确认）：" + c.text)
        }
      }
      @core.ClaimStatus::Approved => ()
    }
  }
  problems
}

/// 事实门禁：未确认事实必须强制占位
pub fn check_facts(brief : @core.Brief) -> Array[String] {
  let problems : Array[String] = []
  for f in brief.facts {
    if !f.confirmed {
      problems.push("未确认事实必须占位，不得编造默认值：「" + f.key + "」")
    } else {
      match f.value {
        None => problems.push("已确认事实缺少取值：「" + f.key + "」")
        Some(_) => ()
      }
    }
  }
  problems
}

/// 门禁执行：通过 → Ready，未通过 → Gated
pub fn gate(issue : @core.Issue, brief : @core.Brief) -> (@core.Issue, Array[String]) {
  let problems : Array[String] = []
  problems.append(check_claims(issue.claims))
  problems.append(check_facts(brief))
  if problems.is_empty() {
    ({ ..issue, status: @core.IssueStatus::Ready }, [])
  } else {
    ({ ..issue, status: @core.IssueStatus::Gated }, problems)
  }
}

/// 人工验收：只有 Ready 状态可以升级为 Approved
pub fn approve(issue : @core.Issue) -> @core.Issue {
  match issue.status {
    @core.IssueStatus::Ready => { ..issue, status: @core.IssueStatus::Approved }
    _ => issue
  }
}

/// 发布：只有 Approved 状态可以升级为 Published
pub fn publish(issue : @core.Issue) -> @core.Issue {
  match issue.status {
    @core.IssueStatus::Approved => { ..issue, status: @core.IssueStatus::Published }
    _ => issue
  }
}

/// 状态机合法性检查：发布 / 验收等动作是否被允许
pub fn can_approve(issue : @core.Issue) -> Bool {
  issue.status == @core.IssueStatus::Ready
}

pub fn can_publish(issue : @core.Issue) -> Bool {
  issue.status == @core.IssueStatus::Approved
}
