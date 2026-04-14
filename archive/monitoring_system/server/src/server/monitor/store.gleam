import pog
import server/monitor/model

pub fn evaluation(
  _db: pog.Connection,
  _evaluation_id: String,
  _evidence: List(model.Evidence),
  _decision: List(model.Decision),
) -> Result(Nil, String) {
  todo as "call snapshot, path, and candidate in one write boundary, then call score.enqueue for each newly persisted relevant change so scoring does not wait only for the backstop clock"
}

pub fn snapshot(
  _db: pog.Connection,
  _evaluation_id: String,
  _evidence: List(model.Evidence),
) -> Result(Nil, String) {
  todo as "persist the latest snapshots for the monitored evaluation paths so evaluation can call this before path and candidate persistence"
}

pub fn path(
  _db: pog.Connection,
  _evaluation_id: String,
  _evidence: List(model.Evidence),
) -> Result(Nil, String) {
  todo as "upsert discovered paths, mark removed paths, and touch the known site map for the evaluation so evaluation can keep path state aligned with the persisted snapshots"
}

pub fn candidate(
  _db: pog.Connection,
  _evaluation_id: String,
  _decision: List(model.Decision),
) -> Result(Nil, String) {
  todo as "persist the final monitored changes that survived the relevance pass and return enough durable identity for evaluation to enqueue score work"
}
