import server/score/model

pub fn signal(
  change_signal: model.ChangeSignal,
  priority: List(model.ItemPriority),
) -> model.PrioritySignal {
  let top = item(priority)

  model.PrioritySignal(
    evaluation_id: change_signal.evaluation_id,
    change_id: change_signal.change_id,
    priority: top.priority,
    priority_summary: summary(top),
  )
}

pub fn item(priority: List(model.ItemPriority)) -> model.ItemPriority {
  case priority {
    [first, ..rest] -> top_priority(first, rest)
    [] -> panic as "rank.item requires at least one item priority"
  }
}

pub fn summary(priority: model.ItemPriority) -> String {
  let model.ItemPriority(explanation:, ..) = priority
  let model.Explanation(summary:, ..) = explanation
  summary
}

fn top_priority(
  current: model.ItemPriority,
  remaining: List(model.ItemPriority),
) -> model.ItemPriority {
  case remaining {
    [] -> current
    [next, ..rest] -> {
      let model.ItemPriority(priority: current_value, ..) = current
      let model.ItemPriority(priority: next_value, ..) = next

      case next_value >. current_value {
        True -> top_priority(next, rest)
        False -> top_priority(current, rest)
      }
    }
  }
}
