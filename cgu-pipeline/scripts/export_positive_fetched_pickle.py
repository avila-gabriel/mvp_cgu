#!/usr/bin/env python3
import datetime as dt
import hashlib
import hmac
import json
import os
import pickle
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote, urlparse

import requests


POSTGRES_CONTAINER = os.environ.get("POSTGRES_CONTAINER", "deploy-postgres-1")
POSTGRES_DB = os.environ.get("POSTGRES_DB", "cgu_pipeline")
POSTGRES_USER = os.environ.get("POSTGRES_USER", "postgres")

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://127.0.0.1:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "cgu_pipeline")
MINIO_SECRET_KEY = os.environ.get(
    "MINIO_SECRET_KEY",
    "cgu_pipeline_dev_password",
)
MINIO_REGION = os.environ.get("MINIO_REGION", "us-east-1")

OUTPUT_PATH = Path(
    os.environ.get("OUTPUT_PATH", "exports/positive_fetched_records.pkl")
)


SQL = r"""
with positive_fetched as (
  select
    s,
    si,
    w,
    a,
    t
  from subject_item si
  join subject s on s.id = si.subject_id
  join work_item w on w.subject_item_id = si.id
  join artifact a on a.work_item_id = w.id
  left join artifact_text t on t.artifact_id = a.id
  where si.verification_status = 'conform'
    and w.status = 'succeeded'
)
select jsonb_build_object(
  'summary', jsonb_build_object(
    'filter', 'subject_item.verification_status = conform, work_item.status = succeeded, and artifact exists',
    'positive_fetched_record_count', (select count(*) from positive_fetched),
    'positive_subject_items_with_successful_fetch', (
      select count(distinct (si).id)
      from positive_fetched
    ),
    'positive_artifact_count', (select count(*) from positive_fetched),
    'positive_artifact_text_count', (
      select count(*)
      from positive_fetched
      where (t).artifact_id is not null
    ),
    'all_subject_item_count', (select count(*) from subject_item),
    'all_positive_subject_item_count', (
      select count(*)
      from subject_item
      where verification_status = 'conform'
    ),
    'all_artifact_count', (select count(*) from artifact)
  ),
  'records', coalesce(jsonb_agg(
    jsonb_build_object(
      'sta', jsonb_build_object(
        'id', (s).id,
        'metadata', (s).metadata
      ),
      'parsed_columns', jsonb_build_object(
        'sta_id', (si).subject_id,
        'subject_item_id', (si).id,
        'source_key', (si).source_key,
        'source_file', coalesce((si).metadata->>'source_file', ''),
        'source_path', coalesce((si).metadata->>'source_path', ''),
        'row_number', (si).metadata->'row_number',
        'Assunto', coalesce((si).metadata->>'assunto', (si).metadata->>'Assunto', ''),
        'Item', coalesce((si).metadata->>'item', (si).metadata->>'Item', ''),
        'RespostaOrgao', coalesce((si).metadata->>'resposta_orgao', (si).metadata->>'RespostaOrgao', ''),
        'URL', (si).url,
        'DataAtualizacao', coalesce((si).metadata->>'data_atualizacao', (si).metadata->>'DataAtualizacao', ''),
        'DataAvaliacaoCGU', coalesce((si).metadata->>'data_avaliacao_cgu', (si).metadata->>'DataAvaliacaoCGU', ''),
        'Status', coalesce((si).metadata->>'status_raw', (si).metadata->>'Status', ''),
        'AvaliacaoCGU', coalesce((si).metadata->>'avaliacao_cgu', (si).metadata->>'AvaliacaoCGU', ''),
        'verification_status', (si).verification_status::text,
        'raw_metadata', (si).metadata
      ),
      'fetch', jsonb_build_object(
        'work_item_id', (w).id,
        'kind', (w).kind,
        'archive_date', (w).archive_date,
        'requested_url', (w).url,
        'fetch_host', (w).fetch_host,
        'work_status', (w).status::text,
        'work_metadata', (w).metadata,
        'artifact_id', (a).id,
        'source_url', (a).source_url,
        'fetched_url', (a).fetched_url,
        'status_code', (a).status_code,
        'content_type', (a).content_type,
        'body_sha256', (a).body_sha256,
        'body_size_bytes', (a).body_size_bytes,
        'storage_url', (a).storage_url,
        'storage_sha256', (a).storage_sha256,
        'storage_size_bytes', (a).storage_size_bytes,
        'storage_content_encoding', (a).storage_content_encoding,
        'fetch_metadata', (a).metadata,
        'fetched_at', (a).fetched_at
      ),
      'text', case
        when (t).artifact_id is null then null
        else jsonb_build_object(
          'extraction_status', (t).extraction_status,
          'title', (t).title,
          'headings', (t).headings,
          'lists', (t).lists,
          'breadcrumbs', (t).breadcrumbs,
          'language', (t).language,
          'raw_text', (t).raw_text,
          'cleaned_text', (t).cleaned_text,
          'cleaned_html', (t).cleaned_html,
          'char_count', (t).char_count,
          'cleaned_char_count', (t).cleaned_char_count,
          'content_type', (t).content_type,
          'extractor', (t).extractor,
          'extractor_version', (t).extractor_version,
          'error', (t).error,
          'inserted_at', (t).inserted_at,
          'updated_at', (t).updated_at
        )
      end
    )
    order by (si).subject_id, (si).source_key, (w).kind, (a).fetched_at desc
  ), '[]'::jsonb)
)::text
from positive_fetched;
"""


def run_psql_json() -> dict:
    command = [
        "docker",
        "exec",
        "-i",
        POSTGRES_CONTAINER,
        "psql",
        "-U",
        POSTGRES_USER,
        "-d",
        POSTGRES_DB,
        "-At",
        "-v",
        "ON_ERROR_STOP=1",
        "-f",
        "-",
    ]
    result = subprocess.run(
        command,
        input=SQL,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    return json.loads(result.stdout)


def signing_key(secret_key: str, date_stamp: str, region: str) -> bytes:
    date_key = hmac.new(
        ("AWS4" + secret_key).encode(),
        date_stamp.encode(),
        hashlib.sha256,
    ).digest()
    region_key = hmac.new(date_key, region.encode(), hashlib.sha256).digest()
    service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
    return hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()


def signed_get(url: str) -> bytes:
    parsed = urlparse(url)
    bucket = parsed.netloc
    key = parsed.path.lstrip("/")
    endpoint = urlparse(MINIO_ENDPOINT)
    path = f"/{bucket}/{quote(key, safe='/')}"
    request_url = f"{MINIO_ENDPOINT.rstrip('/')}{path}"

    now = dt.datetime.now(dt.UTC)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(b"").hexdigest()
    host = endpoint.netloc

    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = "\n".join(
        [
            "GET",
            path,
            "",
            canonical_headers,
            signed_headers,
            payload_hash,
        ]
    )
    credential_scope = f"{date_stamp}/{MINIO_REGION}/s3/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            credential_scope,
            hashlib.sha256(canonical_request.encode()).hexdigest(),
        ]
    )
    signature = hmac.new(
        signing_key(MINIO_SECRET_KEY, date_stamp, MINIO_REGION),
        string_to_sign.encode(),
        hashlib.sha256,
    ).hexdigest()
    headers = {
        "Authorization": (
            "AWS4-HMAC-SHA256 "
            f"Credential={MINIO_ACCESS_KEY}/{credential_scope}, "
            f"SignedHeaders={signed_headers}, Signature={signature}"
        ),
        "Host": host,
        "x-amz-content-sha256": payload_hash,
        "x-amz-date": amz_date,
    }
    response = requests.get(request_url, headers=headers, timeout=30)
    response.raise_for_status()
    return response.content


def brotli_decompress(compressed: bytes) -> bytes:
    result = subprocess.run(
        ["brotli", "--decompress", "--stdout"],
        input=compressed,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    return result.stdout


def attach_bodies(export: dict) -> None:
    body_count = 0
    missing_count = 0
    raw_total = 0
    compressed_total = 0

    for record in export["records"]:
        fetch = record["fetch"]
        body = {
            "storage_url": fetch["storage_url"],
            "storage_content_encoding": fetch["storage_content_encoding"],
            "compressed_body_bytes": None,
            "raw_body_bytes": None,
            "error": None,
        }
        try:
            compressed = signed_get(fetch["storage_url"])
            raw = brotli_decompress(compressed)
            body["compressed_body_bytes"] = compressed
            body["raw_body_bytes"] = raw
            body["compressed_size_bytes"] = len(compressed)
            body["raw_size_bytes"] = len(raw)
            body["raw_sha256"] = hashlib.sha256(raw).hexdigest()
            body_count += 1
            raw_total += len(raw)
            compressed_total += len(compressed)
        except Exception as exc:
            body["error"] = str(exc)
            missing_count += 1
        record["fetched_body"] = body

    export["summary"]["stored_bodies_included"] = body_count
    export["summary"]["stored_bodies_missing"] = missing_count
    export["summary"]["stored_body_raw_total_bytes"] = raw_total
    export["summary"]["stored_body_compressed_total_bytes"] = compressed_total


def main() -> None:
    export = run_psql_json()
    export["exported_at_utc"] = dt.datetime.now(dt.UTC).isoformat()
    export["pickle_schema"] = {
        "top_level_type": "dict",
        "records_type": "list[dict]",
        "record_shape": {
            "sta": "dict with id and metadata",
            "parsed_columns": "dict with STA id, source row info, original parsed STA columns, URL, verification_status, and raw_metadata",
            "fetch": "dict with work request fields and artifact fetch/storage fields",
            "text": "dict | None with artifact_text extraction output",
            "fetched_body": "dict with bytes fields",
            "fetched_body.compressed_body_bytes": "bytes | None",
            "fetched_body.raw_body_bytes": "bytes | None",
        },
    }
    attach_bodies(export)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("wb") as output:
        pickle.dump(export, output, protocol=pickle.HIGHEST_PROTOCOL)

    size = OUTPUT_PATH.stat().st_size
    print(json.dumps({
        "output_path": str(OUTPUT_PATH),
        "pickle_size_bytes": size,
        "pickle_size_mib": round(size / 1024 / 1024, 3),
        "top_level_type": type(export).__name__,
        "records_type": type(export["records"]).__name__,
        "records_count": len(export["records"]),
        "summary": export["summary"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
