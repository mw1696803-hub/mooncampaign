test "被阻断的声明被检出" {
  let c = { ..@core.Claim::new("8 hour hydration"), status: @core.ClaimStatus::Blocked }
  assert_eq(check_claims([c]).length(), 1)
}

test "待核验声明无证据被检出" {
  let c = @core.Claim::new("barrier repair")
  assert_eq(check_claims([c]).length(), 1)
}

test "已核验声明通过" {
  let c = { ..@core.Claim::new("8 hour hydration"), status: @core.ClaimStatus::Approved,
    evidence: Some("R&D doc v2") }
  assert_eq(check_claims([c]).length(), 0)
}

test "未确认事实必须占位" {
  let brief = @core.Brief::new("x", "y")
  brief.facts.push(@core.Fact::pending("price"))
  assert_eq(check_facts(brief).length(), 1)
}

test "已确认事实通过" {
  let brief = @core.Brief::new("x", "y")
  brief.facts.push(@core.Fact::confirmed("price", "£12"))
  assert_eq(check_facts(brief).length(), 0)
}

test "门禁通过则置为 Ready" {
  let issue = @core.Issue::new("i1", "ok")
  let brief = @core.Brief::new("x", "y")
  brief.facts.push(@core.Fact::confirmed("price", "£12"))
  let (gated, problems) = gate(issue, brief)
  assert_eq(problems.length(), 0)
  assert_eq(gated.status, @core.IssueStatus::Ready)
}

test "门禁未通过则置为 Gated" {
  let issue = @core.Issue::new("i1", "bad")
  let brief = @core.Brief::new("x", "y")
  brief.facts.push(@core.Fact::pending("price"))
  let (gated, problems) = gate(issue, brief)
  assert_eq(problems.length(), 1)
  assert_eq(gated.status, @core.IssueStatus::Gated)
}

test "状态机：只有 Ready 才能 Approved，只有 Approved 才能 Published" {
  let draft = @core.Issue::new("i1", "x")
  assert_eq(approve(draft).status, @core.IssueStatus::Draft)
  assert_false(can_approve(draft))

  let ready = { ..draft, status: @core.IssueStatus::Ready }
  assert_true(can_approve(ready))
  let approved = approve(ready)
  assert_eq(approved.status, @core.IssueStatus::Approved)
  assert_false(can_publish(ready))
  assert_true(can_publish(approved))
  assert_eq(publish(approved).status, @core.IssueStatus::Published)
}

test "带审计记录的 approve：Ready → Approved + approver 记录" {
  let ready = { ..@core.Issue::new("i1", "x"), status: @core.IssueStatus::Ready }
  let (issue, rec) = approve_with_record(ready, "voice-owner-zhang")
  assert_eq(issue.status, @core.IssueStatus::Approved)
  assert_eq(rec.action, "approve")
  assert_eq(rec.actor, "voice-owner-zhang")
  assert_eq(rec.issue_id, "i1")
}

test "带审计记录的 approve：非 Ready 被拒绝" {
  let draft = @core.Issue::new("i1", "x")
  let (issue, rec) = approve_with_record(draft, "voice-owner-zhang")
  assert_eq(issue.status, @core.IssueStatus::Draft)
  assert_eq(rec.action, "rejected")
}

test "带审计记录的 publish：Approved → Published + channel 记录" {
  let approved = { ..@core.Issue::new("i1", "x"), status: @core.IssueStatus::Approved }
  let (issue, rec) = publish_with_record(approved, "esp")
  assert_eq(issue.status, @core.IssueStatus::Published)
  assert_eq(rec.action, "publish")
  assert_eq(rec.actor, "esp")
}

test "带审计记录的 publish：非 Approved 被拒绝" {
  let ready = { ..@core.Issue::new("i1", "x"), status: @core.IssueStatus::Ready }
  let (issue, rec) = publish_with_record(ready, "esp")
  assert_eq(issue.status, @core.IssueStatus::Ready)
  assert_eq(rec.action, "rejected")
}