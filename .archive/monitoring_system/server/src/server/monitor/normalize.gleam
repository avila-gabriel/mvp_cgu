import gleam/option.{type Option}
import server/monitor/fetch
import server/monitor/load
import server/monitor/model

pub fn evaluation(
  _scope: load.Scope,
  _visit: List(fetch.Visit),
) -> List(model.Evidence) {
  todo as "normalize fetched pages into stable evidence with path matching, visible text, headings, and previous baseline pages"
}

pub fn evidence(_scope: load.Scope, _visit: fetch.Visit) -> model.Evidence {
  todo as "pair one fetched page with its known baseline and produce the evidence shape used by the monitor filters"
}

pub fn page(_visit: fetch.Visit) -> model.Page {
  todo as "extract the stable page representation used for diffing from one fetched visit"
}

pub fn before(_scope: load.Scope, _path: String) -> Option(model.Page) {
  todo as "resolve the latest known baseline page for a path when the evaluation already knows that path"
}
