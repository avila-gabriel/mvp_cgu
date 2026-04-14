import gleam/result
import pog
import server/monitor
import wisp.{type Request}

pub type Submission

pub type StoredEvaluation {
  StoredEvaluation(evaluation_id: String, has_unresolved_items: Bool)
}

type NextStep {
  Resolved(String)
  Monitoring(String)
}

pub fn process(db: pog.Connection, req: Request) -> Result(Nil, String) {
  use submission <- result.try(decode(req))
  use stored_evaluation <- result.try(persist(db, submission))
  apply(db, stored_evaluation)
}

fn decode(req: Request) -> Result(Submission, String) {
  let _ = req
  todo as "decode the submitted evaluation payload, including extension_version, into one normalized submission shape regardless of whether the human considered it a first evaluation or a revalidation"
}

fn persist(
  db: pog.Connection,
  submission: Submission,
) -> Result(StoredEvaluation, String) {
  let _ = db
  let _ = submission
  todo as "persist the submitted evaluation into evaluation, evaluation_item, tracked_url, and evaluation_queue seed state, then return whether unresolved items still exist"
}

fn apply(
  db: pog.Connection,
  stored_evaluation: StoredEvaluation,
) -> Result(Nil, String) {
  case next_step(stored_evaluation) {
    Resolved(evaluation_id) -> resolve(db, evaluation_id)
    Monitoring(evaluation_id) -> monitor_evaluation(db, evaluation_id)
  }
}

fn next_step(stored_evaluation: StoredEvaluation) -> NextStep {
  let StoredEvaluation(evaluation_id:, has_unresolved_items:) =
    stored_evaluation

  case has_unresolved_items {
    True -> Monitoring(evaluation_id)
    False -> Resolved(evaluation_id)
  }
}

fn resolve(db: pog.Connection, evaluation_id: String) -> Result(Nil, String) {
  let _ = db
  let _ = evaluation_id
  todo as "mark the submitted evaluation as operationally resolved so it no longer contributes queue or monitoring work when the human validation has no unresolved items"
}

fn monitor_evaluation(
  db: pog.Connection,
  evaluation_id: String,
) -> Result(Nil, String) {
  case monitor.enqueue(db, evaluation_id) {
    Ok(_) -> Ok(Nil)
    Error(detail) -> Error("failed to enqueue monitor job: " <> detail)
  }
}
