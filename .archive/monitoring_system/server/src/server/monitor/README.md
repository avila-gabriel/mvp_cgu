# Monitor

This job supports `STA` revalidation by tracking changes on public
institutional pages linked to previously evaluated items.

It is not the formal source of revalidation. The formal workflow still runs
through `Fala.BR` / `STA` and CGU validation.

## Operational role

Monitor should answer:

- which tracked pages changed since the last CGU evaluation context
- whether the observed change looks potentially relevant or mostly noise
- which candidate changes should be forwarded to prioritization

Monitor should not answer:

- whether an item now `Cumpre`
- whether an item now `Cumpre Parcialmente`
- whether an item now `Nao Cumpre`

## Execution order

1. `load.scope`
2. `fetch.evaluation`
3. `normalize.evaluation`
4. `noise.evidence`
5. `candidate.evaluation`
6. `store.evaluation`

## Current status

- `monitor.gleam` owns the `m25` boundary and orchestration
- `noise.gleam` is the irrelevant-diff boundary
- harder rules stay as `todo` until normalization is richer
- `evaluation.next_monitor_at` is the due field for periodic monitor selection
- `clock/monitor.gleam` picks due evaluations every 30 minutes
- due means active evaluation with at least one item whose status is not `fully_complies`
- `store.evaluation` persists snapshots and candidate changes for downstream triage

## Design rules

- monitor works from the last known CGU evaluation context
- monitor tracks public URLs relevant to the evaluated item set
- monitor records evidence of change
- monitor suppresses obvious noise when possible
- monitor never makes the final compliance decision

## Why this job exists

According to the source documents, the pain is not lack of a formal `STA`
workflow. The pain is lack of automatic signals for updates on institutional
pages.

This job exists to create that missing operational signal.

## SQL files in `sql/`

- `scope.sql`: load evaluation scope, active items, monitored URLs, known paths, and baselines
- `snapshot.sql`: insert the latest normalized snapshot rows
- `discover.sql`: insert newly discovered paths
- `remove.sql`: mark removed paths
- `candidate.sql`: insert candidate changes
- `touch.sql`: update path freshness / last seen markers
