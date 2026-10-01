///|
/// campaign-dsl：模块序列编排规则
///
/// 来自真实项目的方法论：一篇内容不能所有模块都在重复同一信息类型，
/// 相邻模块必须更换信息类型，为读者提供不断变化的阅读回报；
/// 同时每期必须有一个主行动（PrimaryCta）。

/// 检查相邻模块是否连续使用同一信息类型
pub fn check_no_adjacent_same_kind(blocks : Array[@core.Block]) -> Array[String] {
  let problems : Array[String] = []
  let mut prev : @core.BlockKind? = None
  for b in blocks {
    if prev == Some(b.kind) {
      problems.push(
        "相邻模块连续使用同一信息类型「" + b.kind.label() + "」：至少插入一种其他类型",
      )
    }
    prev = Some(b.kind)
  }
  problems
}

/// 检查一期是否至少存在一个主行动链接
pub fn check_has_primary_cta(blocks : Array[@core.Block]) -> Array[String] {
  let mut found = false
  for b in blocks {
    for l in b.links {
      if l.role == @core.LinkRole::PrimaryCta {
        found = true
      }
    }
  }
  if found {
    []
  } else {
    ["本期缺少主行动（PrimaryCta）链接"]
  }
}

/// 检查主行动所在模块是否为 Cta 或 Product 类型（主行动应出现在读者准备好的位置）
pub fn check_primary_cta_placement(blocks : Array[@core.Block]) -> Array[String] {
  let problems : Array[String] = []
  for b in blocks {
    for l in b.links {
      if (l.role == @core.LinkRole::PrimaryCta && b.kind != @core.BlockKind::Cta &&
        b.kind != @core.BlockKind::Product) {
        problems.push(
          "主行动链接出现在「" + b.kind.label() + "」模块，建议放在 Cta / Product 模块",
        )
      }
    }
  }
  problems
}

/// 聚合所有编排规则，返回全部问题
pub fn check_sequence(blocks : Array[@core.Block]) -> Array[String] {
  let problems : Array[String] = []
  problems.append(check_no_adjacent_same_kind(blocks))
  problems.append(check_has_primary_cta(blocks))
  problems.append(check_primary_cta_placement(blocks))
  problems
}
