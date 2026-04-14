import gleam/option.{type Option}
import pog
import server/monitor/model

pub type Scope {
  Scope(
    evaluation_id: String,
    base_url: String,
    item: List(Item),
    url: List(Url),
    tracked_path: List(TrackedPath),
  )
}

pub type Item {
  Item(item_id: String, text: String)
}

pub type Url {
  Url(monitored_url_id: String, url: String)
}

pub type TrackedPath {
  TrackedPath(tracked_path_id: String, path: String, page: Option(model.Page))
}

pub fn scope(
  _db: pog.Connection,
  _evaluation_id: String,
) -> Result(Scope, String) {
  todo as "load the active evaluation scope, unresolved items, monitored URLs, tracked paths, and latest baseline pages needed for monitoring"
}
