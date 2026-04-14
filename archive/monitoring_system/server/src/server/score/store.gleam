import pog
import server/score/model

pub fn prioritization(
  _db: pog.Connection,
  _change_signal: model.ChangeSignal,
  _priority: List(model.ItemPriority),
  _priority_signal: model.PrioritySignal,
) -> Result(Nil, String) {
  todo as "call priority, explanation, queue, and change in one write boundary so one prioritized monitored change fully updates the queue-facing state"
}

pub fn priority(
  _db: pog.Connection,
  _change_signal: model.ChangeSignal,
  _priority: List(model.ItemPriority),
) -> Result(Nil, String) {
  todo as "persist one item priority row per unresolved item evaluated for this monitored change so prioritization can then call explanation with durable identifiers"
}

pub fn explanation(
  _db: pog.Connection,
  _priority: List(model.ItemPriority),
) -> Result(Nil, String) {
  todo as "persist one priority explanation row per persisted item priority row so rank.summary has durable queue-facing detail"
}

pub fn queue(
  _db: pog.Connection,
  _priority_signal: model.PrioritySignal,
) -> Result(Nil, String) {
  todo as "upsert the aggregated prioritization signal so /api/inbox/queue reflects the latest top monitored change and priority"
}

pub fn change(
  _db: pog.Connection,
  _change_signal: model.ChangeSignal,
  _priority: List(model.ItemPriority),
) -> Result(Nil, String) {
  todo as "mark the monitored change as prioritized when durable rows were persisted or dismissed when no meaningful signal was found so clock/score only acts as a backstop"
}
