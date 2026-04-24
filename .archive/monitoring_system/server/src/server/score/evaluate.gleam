import gleam/option.{type Option}
import server/score/load
import server/score/model

pub fn scope(scope: load.Scope) -> List(model.ItemPriority) {
  let load.Scope(change_signal:, item: items) = scope
  items
  |> list_map(fn(entry) { item(change_signal, entry) })
}

pub fn item(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> model.ItemPriority {
  todo as "choose the evaluator family for one unresolved item and produce the final priority and explanation"
}

pub fn ast(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one item by comparing the previous and current page structure when a baseline snapshot exists"
}

pub fn heading(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one item from heading presence and heading changes that indicate stronger evaluation value"
}

pub fn link(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one item from added, removed, or changed links that matter to the item"
}

pub fn topology(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one item from page topology changes such as menu, navigation, or section structure updates"
}

pub fn section(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one item from the presence or absence of sections that should exist for compliance"
}

pub fn document(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one item from the appearance of required documents or document links"
}

pub fn discovery(
  _change_signal: model.ChangeSignal,
  _item: load.Item,
) -> Option(model.ItemPriority) {
  todo as "prioritize one unresolved item for a newly discovered path that has no previous baseline"
}

fn list_map(value: List(a), each: fn(a) -> b) -> List(b) {
  case value {
    [] -> []
    [first, ..rest] -> [each(first), ..list_map(rest, each)]
  }
}
