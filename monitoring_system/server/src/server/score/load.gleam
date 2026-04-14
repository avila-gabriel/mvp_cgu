import gleam/option.{type Option}
import pog
import server/score/model

pub type Scope {
  Scope(change_signal: model.ChangeSignal, item: List(Item))
}

pub type Item {
  Item(
    item_id: String,
    name: String,
    exact_url: Option(String),
    justification: Option(String),
    observed_evidence: Option(String),
    note: Option(String),
  )
}

pub fn scope(_db: pog.Connection, _change_id: String) -> Result(Scope, String) {
  todo as "load the monitored change, its evaluation context, and the still unresolved items that should be prioritized"
}
