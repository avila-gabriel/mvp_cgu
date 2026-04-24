update artifact_text
set
  extraction_status = $2,
  title = $3,
  headings = $4,
  lists = $5,
  breadcrumbs = $6,
  language = $7,
  raw_text = $8,
  cleaned_text = $9,
  cleaned_html = $10,
  char_count = $11,
  cleaned_char_count = $12,
  content_type = $13,
  extractor = $14,
  extractor_version = $15,
  error = $16,
  worker_id = null,
  lease_expires_at = null,
  updated_at = timezone('utc', now())
where artifact_id = $1
  and extraction_status = 'running'
  and worker_id = $17
returning artifact_id::text
