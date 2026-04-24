# Data

This file describes the STA data handled by the pipeline. It has two layers:
domain meaning, for understanding what the CGU spreadsheet represents, and
technical shape, for understanding what the code stores and emits.

## Domain Meaning

The input comes from the CGU Sistema de Transparência Ativa, or STA. In the CGU
guide, STA is described as a form filled by each federal órgão or entidade in
Fala.BR. The órgão answers each transparency question, says whether it publishes
the required information, and provides the exact page where the information can
be found. CGU then checks that answer against the órgão's official site and
assigns its own evaluation.

In the spreadsheet, one workbook represents one STA. The STA code comes from the
workbook file name, for example `CBTU`.

Each row is one transparency item:

- `Assunto`: the transparency topic, such as `AÇÕES E PROGRAMAS` or
  `INFORMAÇÕES CLASSIFICADAS`.
- `Item`: the requirement or question being checked.
- `RespostaOrgao`: the answer declared by the órgão in the STA form. This is not
  CGU's evaluation. It can be `Sim`, `Não`, `Não Se Aplica`, a date, a count, or
  free text, depending on the question.
- `URL`: the page supplied by the órgão as evidence.
- `DataAtualizacao`: when the órgão says the information was updated.
- `DataAvaliacaoCGU`: when CGU evaluated the item.
- `Status`: the verification state in the STA export.
- `AvaliacaoCGU`: CGU's compliance judgment.

For analysis, `RespostaOrgao` should be treated as the órgão's claim or
self-declared answer. `AvaliacaoCGU` is the compliance signal. For example,
`RespostaOrgao = Sim` with `AvaliacaoCGU = Não Cumpre` means the órgão claimed
the information existed, but CGU checked the site and found it non-compliant.

The pipeline reduces CGU evaluation values to these verification statuses:

- `Cumpre` becomes `conform`, when `Status` is `Verificado`.
- `Não Cumpre` and `Cumpre Parcialmente` become `non_conform`, when `Status` is
  `Verificado`.
- A missing `AvaliacaoCGU` becomes `not_verified`.

Rows without a URL are kept out of the fetch queue because there is no page to
fetch. They are counted in the ingest response as `skipped_missing_url`, and the
response also includes a `discarded_rows` array with the workbook, row number,
STA id, topic, item, raw URL, and discard reason.

## Technical Input Shape

The current XLSX input is a zip file containing one `.xlsx` workbook per STA.
Each workbook must contain the `Informações Gerais STA` worksheet or exactly one
worksheet. The header must include:

```text
Assunto
Item
RespostaOrgao
URL
DataAtualizacao
DataAvaliacaoCGU
Status
AvaliacaoCGU
```

The parser derives:

- STA identifier: from the workbook name after removing
  `informacoesDetalhadasSTA - ` and `.xlsx`.
- Item URL: from `URL`; it must be an HTTP or HTTPS URL to be scheduled.
- Source key: from workbook name, row number, `Assunto`, `Item`, and `URL`. This
  makes re-ingest idempotent without depending on the uploaded zip file name.
- Item metadata: JSON copied from the row:
  - `source_file`
  - `source_path`
  - `row_number`
  - `assunto`
  - `item`
  - `resposta_orgao`
  - `data_atualizacao`
  - `data_avaliacao_cgu`
  - `status_raw`
  - `avaliacao_cgu`

Unknown non-empty CGU evaluation values make ingest fail instead of being
guessed. Parse failures are logged by the master with the file/row detail
returned to the caller.

## Technical Output Shape

The pipeline stores fetch scheduling and fetch artifacts in these main records:

- `subject`: one STA or scheduled subject.
- `subject_item`: one URL-bearing transparency row belonging to a STA.
- `work_item`: one scheduled fetch.
- `artifact`: one completed fetch result.
- `artifact_text`: one text-extraction result for a completed artifact.

### `subject`

- `id`: stable subject identifier. For XLSX input, this is the STA code derived
  from the workbook name.
- `metadata`: subject-level JSON.
- `inserted_at`, `updated_at`: UTC timestamps.

### `subject_item`

- `id`: subject item UUID.
- `subject_id`: STA that owns this item.
- `source_key`: stable XLSX item identity used for idempotent re-ingest.
- `url`: item URL.
- `verification_status`: `not_verified`, `conform`, or `non_conform`.
- `metadata`: item-level JSON copied from the workbook row.
- `inserted_at`, `updated_at`: UTC timestamps.

### `work_item`

- `id`: work item UUID.
- `subject_id`: subject that owns the URL.
- `subject_item_id`: source item for this fetch URL.
- `kind`: `snapshot.current` or `snapshot.archive`.
- `url`: URL fetched by the worker.
- `archive_date`: requested target date for snapshot work, when present.
- `fetch_host`: normalized host used for host-level rate limiting.
- `status`: `pending`, `running`, `succeeded`, `failed`, or `dead`.
- `priority`, `attempts`, `max_attempts`, `last_error`: scheduling state.
- `metadata`: scheduling JSON. STA ingest writes `source`, `role`, and either
  `target_date` for current snapshot work or `target_dates` for archive
  snapshot work.
- `available_at`, `inserted_at`, `updated_at`: UTC timestamps.

### `artifact`

- `id`: artifact UUID.
- `work_item_id`: source work item.
- `subject_id`: source subject.
- `subject_item_id`: source item, when available.
- `kind`: `snapshot.current` or `snapshot.archive`.
- `source_url`: URL from the work item.
- `fetched_url`: URL associated with the fetch result.
- `status_code`: HTTP status when available.
- `content_type`: response content type header when available.
- `body_sha256`: SHA-256 digest of the raw fetched bytes.
- `body_size_bytes`: raw body size before compression.
- `storage_url`: bucket URL for the stored artifact body.
- `storage_sha256`: SHA-256 digest of the stored bucket object.
- `storage_size_bytes`: stored object size.
- `storage_content_encoding`: `br` for Brotli.
- `metadata`: fetch outcome JSON.
- `fetched_at`: UTC timestamp when the artifact row was inserted.

### `artifact_text`

- `artifact_id`: artifact whose body was extracted.
- `extraction_status`: extractor outcome, such as `succeeded`, `running`,
  `failed`, `empty_body`, `empty_text`, `html_parse_error`, or
  `extraction_error`.
- `title`, `headings`, `lists`, `breadcrumbs`, `language`: structured text
  fields emitted by the extractor when available.
- `raw_text`: extracted plain text before cleanup.
- `cleaned_text`: cleaned text intended for downstream analysis.
- `cleaned_html`: cleaned HTML produced by the extractor.
- `char_count`, `cleaned_char_count`: text lengths.
- `content_type`: content type seen by the extractor.
- `extractor`, `extractor_version`: extractor identity.
- `error`: extraction error detail, when present.
- `attempts`, `max_attempts`: extraction retry state.
- `inserted_at`, `updated_at`: UTC timestamps.

## Artifact Storage

Artifact bodies are Brotli-compressed before bucket upload. Object keys are
based on the raw body hash:

```text
artifacts/sha256/<body_sha256>.br
```

`body_sha256` identifies the raw fetched bytes. `storage_sha256` identifies the
compressed bucket object.

## Fetch Metadata

Use metadata to understand the fetch outcome.

Snapshot archive workers process requested dates in order. The date list comes
from `work_item.metadata.target_dates` when present; otherwise the worker uses
`work_item.archive_date`. For each date, the archive crawl starts with the work
item URL and may visit same-site links up to the configured visit limit.

For each visited URL, archive providers are attempted in this order:

1. Wayback
2. Arquivo.pt
3. Archive-It
4. Library of Congress

Each `metadata.archive_crawl.visit[]` entry records one visited URL. The
`resolution.provider` field identifies the provider that produced the recorded
snapshot when a snapshot was found. If no provider yields a usable snapshot, the
visit records the corresponding unavailable or lookup error case.

Snapshot artifacts use `metadata.archive_crawl.visit[].resolution.case`:

- `exact_period`
- `same_day_fallback`
- `nearby_fallback`
- `snapshot_unavailable`
- `invalid_archive_date`
- `lookup_request_build_error`
- `lookup_http_error`
- `lookup_transport_error`
- `lookup_decode_error`
- `lookup_incomplete_snapshot`

Snapshot artifacts use `metadata.archive_crawl.visit[].fetch.case`:

- `replayed_html`
- `replay_redirect`
- `replay_non_html`
- `replay_http_error`
- `replay_transport_error`
- `replay_escaped_to_live`
- `not_attempted`

Some archive processing failures are represented outside the per-visit list:

- `work_item.last_error`: `invalid_archive_seed_url`
- `work_item.last_error`: `WORKER_ARCHIVE_MAX_VISITS must be greater than zero`
- `work_item.last_error`: `rate_limited`
- `work_item.last_error`: JSON with `case = archive_unavailable`

## Analysis Notes

- Use `subject`, `subject_item`, `work_item`, and `artifact` together to connect
  STAs, item URLs, fetch attempts, and stored artifacts.
- Use `artifact_text` when the analysis needs extracted or cleaned text instead
  of stored raw artifact bodies.
- Multiple STA items can point to the same URL. In that case, `subject_item`
  keeps the item-level rows, and each item can have its own `work_item` per work
  kind and archive date.
- Use `status_code`, `content_type`, and metadata cases together when filtering
  artifacts for analysis.
- Use `body_sha256` to find byte-identical raw fetch outputs.
- Use `storage_url` to locate the compressed artifact body.

## Prepared Analysis API

`GET /api/analysis/prepared-items` exposes a joined view over `subject_item`,
`work_item`, `artifact`, and `artifact_text`. It returns a summary plus paged
rows. The row fields are:

- `subject_item_id`, `subject_id`, `source_key`, `url`
- `verification_status`
- `assunto`, `item`, `resposta_orgao`, `avaliacao_cgu`
- `work_item_id`, `work_kind`, `work_status`, `fetch_host`
- `artifact_id`, `status_code`, `content_type`, `body_size_bytes`,
  `fetched_url`
- `extraction_status`, `char_count`, `cleaned_char_count`, `title`,
  `cleaned_text_excerpt`, `extraction_updated_at`

The summary fields are:

- `subject_item_count`
- `artifact_count`
- `extraction_count`
- `succeeded_count`
- `running_count`
- `failed_count`
- `empty_text_count`
- `median_cleaned_char_count`
- `p95_cleaned_char_count`
