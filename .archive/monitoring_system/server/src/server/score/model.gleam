import gleam/option.{type Option}
import server/monitor/model.{type Event}

pub type ChangeSignal {
  ChangeSignal(
    change_id: String,
    evaluation_id: String,
    tracked_path_id: String,
    event: Event,
    change_summary: Option(String),
    has_baseline: Bool,
  )
}

pub type Mode {
  Comparison
  Discovery
}

pub type Note {
  Note(label: String, value: String)
}

pub type Explanation {
  Explanation(summary: String, note: List(Note))
}

pub type ItemPriority {
  ItemPriority(
    item_id: String,
    mode: Mode,
    evaluator: String,
    priority: Float,
    explanation: Explanation,
  )
}

pub type PrioritySignal {
  PrioritySignal(
    evaluation_id: String,
    change_id: String,
    priority: Float,
    priority_summary: String,
  )
}
