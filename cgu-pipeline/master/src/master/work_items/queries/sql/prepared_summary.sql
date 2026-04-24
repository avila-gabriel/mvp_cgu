select
  (select count(*)::int from subject_item) as subject_item_count,
  (select count(*)::int from artifact) as artifact_count,
  count(*)::int as extraction_count,
  count(*) filter (where extraction_status = 'succeeded')::int as succeeded_count,
  count(*) filter (where extraction_status = 'running')::int as running_count,
  count(*) filter (
    where extraction_status in ('failed', 'empty_body', 'empty_text', 'html_parse_error', 'extraction_error')
  )::int as failed_count,
  count(*) filter (where cleaned_char_count = 0)::int as empty_text_count,
  coalesce(percentile_cont(0.5) within group (order by cleaned_char_count), 0)::int as median_cleaned_char_count,
  coalesce(percentile_cont(0.95) within group (order by cleaned_char_count), 0)::int as p95_cleaned_char_count
from artifact_text
