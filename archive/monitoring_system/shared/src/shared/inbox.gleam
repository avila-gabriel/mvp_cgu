import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}

pub type QueueEntry {
  QueueEntry(
    evaluation_id: String,
    organization_name: String,
    base_url: String,
    priority: Float,
    priority_summary: Option(String),
    aging_deadline_at: Option(String),
    last_prioritized_at: Option(String),
    event: Option(Event),
    top_url: Option(String),
    explanation_summary: Option(String),
    top_item_priority: Option(Float),
  )
}

pub fn entry_to_json(entry: QueueEntry) -> json.Json {
  let QueueEntry(
    evaluation_id:,
    organization_name:,
    base_url:,
    priority:,
    priority_summary:,
    aging_deadline_at:,
    last_prioritized_at:,
    event:,
    top_url:,
    explanation_summary:,
    top_item_priority:,
  ) = entry
  json.object([
    #("evaluation_id", json.string(evaluation_id)),
    #("organization_name", json.string(organization_name)),
    #("base_url", json.string(base_url)),
    #("priority", json.float(priority)),
    #("priority_summary", case priority_summary {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("aging_deadline_at", case aging_deadline_at {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("last_prioritized_at", case last_prioritized_at {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("event", case event {
      option.None -> json.null()
      option.Some(value) -> event_to_json(value)
    }),
    #("top_url", case top_url {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("explanation_summary", case explanation_summary {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("top_item_priority", case top_item_priority {
      option.None -> json.null()
      option.Some(value) -> json.float(value)
    }),
  ])
}

pub fn entry_decoder() -> decode.Decoder(QueueEntry) {
  use evaluation_id <- decode.field("evaluation_id", decode.string)
  use organization_name <- decode.field("organization_name", decode.string)
  use base_url <- decode.field("base_url", decode.string)
  use priority <- decode.field("priority", decode.float)
  use priority_summary <- decode.field(
    "priority_summary",
    decode.optional(decode.string),
  )
  use aging_deadline_at <- decode.field(
    "aging_deadline_at",
    decode.optional(decode.string),
  )
  use last_prioritized_at <- decode.field(
    "last_prioritized_at",
    decode.optional(decode.string),
  )
  use event <- decode.field("event", decode.optional(event_decoder()))
  use top_url <- decode.field("top_url", decode.optional(decode.string))
  use explanation_summary <- decode.field(
    "explanation_summary",
    decode.optional(decode.string),
  )
  use top_item_priority <- decode.field(
    "top_item_priority",
    decode.optional(decode.float),
  )
  decode.success(QueueEntry(
    evaluation_id:,
    organization_name:,
    base_url:,
    priority:,
    priority_summary:,
    aging_deadline_at:,
    last_prioritized_at:,
    event:,
    top_url:,
    explanation_summary:,
    top_item_priority:,
  ))
}

pub type Event {
  PageChanged
  PathDiscovered
  PathRemoved
  TopologyChanged
}

pub fn event_to_json(event: Event) -> json.Json {
  case event {
    PageChanged -> json.string("page_changed")
    PathDiscovered -> json.string("path_discovered")
    PathRemoved -> json.string("path_removed")
    TopologyChanged -> json.string("topology_changed")
  }
}

pub fn event_decoder() -> decode.Decoder(Event) {
  use variant <- decode.then(decode.string)
  case variant {
    "page_changed" -> decode.success(PageChanged)
    "path_discovered" -> decode.success(PathDiscovered)
    "path_removed" -> decode.success(PathRemoved)
    "topology_changed" -> decode.success(TopologyChanged)
    _ -> decode.failure(PageChanged, "Event")
  }
}
