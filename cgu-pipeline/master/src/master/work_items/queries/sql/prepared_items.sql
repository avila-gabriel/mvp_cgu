select
  count(*) over ()::int as total_count,
  si.id::text as subject_item_id,
  si.subject_id,
  si.source_key,
  si.url,
  si.verification_status::text as verification_status,
  coalesce(si.metadata->>'assunto', si.metadata->>'Assunto', '') as assunto,
  coalesce(si.metadata->>'item', si.metadata->>'Item', '') as item,
  coalesce(si.metadata->>'resposta_orgao', si.metadata->>'RespostaOrgao', '') as resposta_orgao,
  coalesce(si.metadata->>'avaliacao_cgu', si.metadata->>'AvaliacaoCGU', '') as avaliacao_cgu,
  coalesce(w.id::text, '') as work_item_id,
  w.kind::text as work_kind,
  coalesce(w.status::text, '') as work_status,
  w.fetch_host,
  coalesce(a.id::text, '') as artifact_id,
  a.status_code,
  a.content_type,
  coalesce(a.body_size_bytes::int, 0) as body_size_bytes,
  a.fetched_url,
  t.extraction_status,
  t.char_count,
  t.cleaned_char_count,
  t.title,
  coalesce(left(t.cleaned_text, 1200), '') as cleaned_text_excerpt,
  coalesce(t.updated_at::text, '') as extraction_updated_at
from subject_item si
left join work_item w on w.subject_item_id = si.id
left join artifact a on a.work_item_id = w.id
left join artifact_text t on t.artifact_id = a.id
order by
  si.subject_id,
  si.source_key,
  w.kind nulls last,
  a.fetched_at desc nulls last
limit $1
offset $2
