import gleam/option.{type Option}
import server/monitor/load
import server/monitor/model

pub fn evaluation(
  _item: List(load.Item),
  _classified: List(model.Classified),
) -> List(model.Decision) {
  todo as "reconsider noisy and non noisy changes against the active evaluation items and decide which ones become monitored changes"
}

pub fn page(
  _item: List(load.Item),
  _classified: model.Classified,
) -> model.Decision {
  todo as "decide whether one classified page change should be ignored or persisted as a candidate change"
}

pub fn item(_item: load.Item, _classified: model.Classified) -> Option(String) {
  todo as "return the evaluation item reason that makes a noisy or subtle page change still relevant enough to keep"
}
