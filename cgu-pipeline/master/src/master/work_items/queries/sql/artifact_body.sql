select
  storage_url
from artifact
where id = $1
  and body_size_bytes > 0
  and storage_content_encoding = 'br'
