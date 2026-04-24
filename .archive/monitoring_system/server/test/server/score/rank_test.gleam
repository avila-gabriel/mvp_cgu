import gleam/option.{None}
import server/monitor/model as monitor_model
import server/score/model as score_model
import server/score/rank

pub fn item_chooses_comparison_evaluators_when_baseline_exists_test() {
  todo as "evaluate.item should use comparison evaluators when the candidate has a baseline"
}

pub fn item_chooses_discovery_evaluators_when_baseline_is_missing_test() {
  todo as "evaluate.item should use discovery evaluators when the candidate has no baseline"
}

pub fn heading_scores_heading_signal_test() {
  todo as "evaluate.heading should score heading-based compliance signals"
}

pub fn link_scores_relevant_link_change_test() {
  todo as "evaluate.link should score relevant link additions removals and changes"
}

pub fn section_scores_missing_required_section_test() {
  todo as "evaluate.section should score required section presence and absence"
}

pub fn document_scores_required_document_presence_test() {
  todo as "evaluate.document should score required document or document-link presence"
}

pub fn ast_skips_when_no_baseline_exists_test() {
  todo as "evaluate.ast should not produce a score when the candidate has no baseline"
}

pub fn topology_skips_when_no_baseline_exists_test() {
  todo as "evaluate.topology should not produce a score when the candidate has no baseline"
}

pub fn item_picks_highest_score_test() {
  let top =
    rank.item([
      priority(item_id: "item-1", priority: 0.35, summary: "First"),
      priority(item_id: "item-2", priority: 0.82, summary: "Second"),
      priority(item_id: "item-3", priority: 0.51, summary: "Third"),
    ])

  assert top.priority == 0.82
  assert rank.summary(top) == "Second"
}

pub fn item_keeps_first_score_on_tie_test() {
  let top =
    rank.item([
      priority(item_id: "item-first", priority: 0.82, summary: "First"),
      priority(item_id: "item-second", priority: 0.82, summary: "Second"),
    ])

  assert top.item_id == "item-first"
  assert rank.summary(top) == "First"
}

pub fn signal_uses_top_score_for_priority_test() {
  let candidate =
    score_model.ChangeSignal(
      change_id: "candidate-123",
      evaluation_id: "evaluation-123",
      tracked_path_id: "path-123",
      event: monitor_model.PageChanged,
      change_summary: None,
      has_baseline: True,
    )

  let signal =
    rank.signal(candidate, [
      priority(item_id: "item-1", priority: 0.41, summary: "Lower"),
      priority(item_id: "item-2", priority: 0.91, summary: "Highest"),
      priority(item_id: "item-3", priority: 0.77, summary: "Middle"),
    ])

  assert signal.evaluation_id == "evaluation-123"
  assert signal.change_id == "candidate-123"
  assert signal.priority == 0.91
  assert signal.priority_summary == "Highest"
}

pub fn signal_keeps_first_top_priority_on_tie_test() {
  let candidate =
    score_model.ChangeSignal(
      change_id: "candidate-123",
      evaluation_id: "evaluation-123",
      tracked_path_id: "path-123",
      event: monitor_model.PageChanged,
      change_summary: None,
      has_baseline: True,
    )

  let signal =
    rank.signal(candidate, [
      priority(item_id: "item-first", priority: 0.91, summary: "First top"),
      priority(item_id: "item-second", priority: 0.91, summary: "Second top"),
    ])

  assert signal.priority == 0.91
  assert signal.priority_summary == "First top"
}

pub fn summary_returns_explanation_summary_test() {
  assert rank.summary(priority(
      item_id: "item-1",
      priority: 0.5,
      summary: "Missing accessibility page",
    ))
    == "Missing accessibility page"
}

fn priority(
  item_id item_id: String,
  priority priority: Float,
  summary summary: String,
) -> score_model.ItemPriority {
  score_model.ItemPriority(
    item_id:,
    mode: score_model.Comparison,
    evaluator: "heading",
    priority:,
    explanation: score_model.Explanation(summary:, note: []),
  )
}
