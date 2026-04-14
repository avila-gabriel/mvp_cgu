# Score

This job is downstream from `monitor`.

Its purpose is to rank change evidence so the CGU team can decide what may
deserve faster human verification.

It is not a compliance engine.

## Operational role

Score should transform raw candidate changes into a priority signal tied to the
evaluation context.

The output means:

- "this change may be worth looking at sooner"

The output does not mean:

- "this item now complies"
- "this item should be marked `Cumpre`"
- "this item should be marked `Nao Cumpre`"

## Execution order

1. `load.scope`
2. `evaluate.scope`
3. `rank.signal`
4. `store.prioritization`

## Trigger model

- the main path is event-driven: `monitor` should enqueue `score` as soon as it
  persists a candidate change worth triaging
- `clock/score.gleam` is only a backstop that scans pending candidate changes
  every 2 minutes and enqueues missing score work
- score jobs are unique per candidate change through `score.key`

## Current status

- `score.gleam` owns the `m25` boundary and orchestration
- `load.gleam` is the read boundary for candidate and unresolved item context
- `evaluate.gleam` isolates evaluator families
- `rank.gleam` turns evidence into an evaluation-level priority signal
- `store.gleam` persists `item_priority`, `priority_explanation`,
  `monitored_change`, and `evaluation_queue`
- evaluator internals stay as `todo` until triage heuristics are known

## Design rules

- scoring operates in the scope of one candidate change and the unresolved
  items from the same evaluation context
- a score is a triage signal, not a compliance result
- comparison mode applies when the candidate change has a previous baseline
- discovery mode applies when the path is new and has no previous baseline

## Recommended interpretation

- high score: relevant change signal, likely worth faster human verification
- low score: weak signal, noisy change, or low apparent value
- dismissed candidate: no meaningful triage signal was found

## SQL files in `sql/`

- `candidate.sql`: load the candidate change, page context, and diff context
- `item.sql`: load unresolved evaluation items for the candidate evaluation
- `score.sql`: upsert `item_priority`
- `explanation.sql`: upsert `priority_explanation`
- `queue.sql`: upsert the aggregated `evaluation_queue` signal
- `status.sql`: mark the candidate change as `scored` or `dismissed`

## Decision note for the first implementation

- unresolved item means any `evaluation_item.status <> 'fully_complies'`
- `monitored_change.status = 'prioritized'` when at least one `item_priority`
  is persisted for the monitored change
- `monitored_change.status = 'dismissed'` when no meaningful `item_priority`
  is persisted for the monitored change
- `rank.signal` should use the highest item priority as the queue priority
- `rank.summary` should come from the same top item priority explanation
- comparison mode should try `ast`, `heading`, `link`, `topology`, `section`,
  and `document`
- discovery mode should try `discovery`, `heading`, `link`, `section`, and
  `document`
- `ast` and `topology` should not run when the candidate has no previous
  baseline
