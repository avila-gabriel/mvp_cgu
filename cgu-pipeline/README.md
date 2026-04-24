# cgu-pipeline

Pipeline for collecting website snapshots and keeping the raw evidence needed
for later analysis.

The system records what was scheduled, what was fetched, where the raw artifact
was stored, and what transport-level outcome was observed.

## What Is Here

- `master`: receives inputs, schedules work, and records results.
- `worker`: fetches scheduled item URLs and stores artifact bodies.
- `shared`: data shapes shared by the services.
- `DATA.md`: the analysis-facing contract for STA inputs and produced data.
