from __future__ import annotations

import argparse
import base64
import json
import os
from dataclasses import asdict, dataclass
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from deboiler import Deboiler
from deboiler.dataset import ListDataset
from deboiler.models.page import ParsedPage
from dotenv import load_dotenv


MIN_DEBOILER_PAGES = 3


@dataclass(frozen=True)
class Artifact:
    artifact_id: str
    subject_id: str
    host: str
    source_url: str
    fetched_url: str
    content_type: str | None
    body_sha256: str
    body_size_bytes: int


@dataclass(frozen=True)
class Page:
    key: str
    content: bytes
    artifacts: list[Artifact]


@dataclass(frozen=True)
class Extraction:
    artifact_id: str
    extraction_status: str
    title: str | None = None
    headings: str | None = None
    lists: str | None = None
    breadcrumbs: str | None = None
    language: str | None = None
    raw_text: str | None = None
    cleaned_text: str | None = None
    cleaned_html: str | None = None
    char_count: int = 0
    cleaned_char_count: int = 0
    content_type: str | None = None
    error: str | None = None


def main() -> None:
    load_dotenv()
    args = parse_args()
    client = MasterClient.from_env()

    artifacts = client.claim_preparation(args.limit)
    groups = group_artifacts(artifacts)

    total_groups = 0
    total_pages = 0
    total_artifacts = 0
    for group_key, group_artifacts_ in groups.items():
        total_groups += 1
        pages = load_distinct_pages(client, group_artifacts_)
        total_pages += len(pages)
        total_artifacts += sum(len(page.artifacts) for page in pages)

        print(
            f"preparing subject={group_key[0]} host={group_key[1]} "
            f"pages={len(pages)} artifacts={sum(len(page.artifacts) for page in pages)}"
        )

        if len(pages) >= MIN_DEBOILER_PAGES:
            extractions = extract_with_deboiler(group_key[1], pages)
        else:
            extractions = extract_with_fallback(pages)

        for extraction in extractions:
            client.store_extraction(extraction)

    print(
        f"prepared groups={total_groups} distinct_pages={total_pages} "
        f"artifacts={total_artifacts}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare cleaned HTML/text from collection artifacts through master."
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=100,
        help="Maximum number of unprepared artifacts to process.",
    )
    return parser.parse_args()


class MasterClient:
    def __init__(
        self,
        base_url: str,
        access_key: str,
        timeout_seconds: float,
        worker_id: str,
        lease_seconds: float,
    ):
        self.base_url = base_url.rstrip("/")
        self.access_key = access_key.strip()
        self.timeout_seconds = timeout_seconds
        self.worker_id = worker_id
        self.lease_seconds = lease_seconds

    @classmethod
    def from_env(cls) -> MasterClient:
        base_url = os.getenv("MASTER_BASE_URL", "").strip()
        if not base_url:
            raise RuntimeError("MASTER_BASE_URL is required for preparation.")
        timeout_ms = int(os.getenv("WORKER_REQUEST_TIMEOUT_MS", "30000"))
        return cls(
            base_url=base_url,
            access_key=os.getenv("MASTER_ACCESS_KEY", ""),
            timeout_seconds=timeout_ms / 1000,
            worker_id=os.getenv("WORKER_ID", "preparation-worker"),
            lease_seconds=float(os.getenv("WORKER_LEASE_SECONDS", "900")),
        )

    def claim_preparation(self, limit: int) -> list[Artifact]:
        payload = self.post_json(
            "/api/preparation/artifacts/claim",
            {
                "worker_id": self.worker_id,
                "lease_seconds": self.lease_seconds,
                "limit": limit,
            },
        )
        return [Artifact(**artifact) for artifact in payload["artifacts"]]

    def artifact_body(self, artifact_id: str) -> bytes:
        payload = self.get_json(f"/api/preparation/artifacts/{artifact_id}/body")
        return base64.b64decode(payload["body_base64"])

    def store_extraction(self, extraction: Extraction) -> None:
        try:
            self.post_json(
                f"/api/preparation/artifacts/{extraction.artifact_id}/extraction",
                extraction_payload(extraction, self.worker_id),
            )
        except LeaseConflict:
            print(f"skipped stale lease artifact={extraction.artifact_id}")

    def get_json(
        self, path: str, query: dict[str, str] | None = None
    ) -> dict[str, object]:
        url = self.url(path, query)
        request = Request(url, headers=self.headers())
        return self.open_json(request)

    def post_json(self, path: str, payload: dict[str, object]) -> dict[str, object]:
        data = json.dumps(payload).encode("utf-8")
        request = Request(
            self.url(path),
            data=data,
            headers={
                **self.headers(),
                "content-type": "application/json",
            },
            method="POST",
        )
        return self.open_json(request)

    def open_json(self, request: Request) -> dict[str, object]:
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            if error.code == 409:
                raise LeaseConflict(detail) from error
            raise RuntimeError(
                f"master returned HTTP {error.code} for {request.full_url}: {detail}"
            ) from error
        except URLError as error:
            raise RuntimeError(
                f"could not reach master at {request.full_url}: {error.reason}"
            ) from error

    def url(self, path: str, query: dict[str, str] | None = None) -> str:
        url = self.base_url + path
        if query:
            url += "?" + urlencode(query)
        return url

    def headers(self) -> dict[str, str]:
        headers = {
            "accept": "application/json",
            "user-agent": "cgu-pipeline/preparation-worker",
        }
        if self.access_key:
            headers["x-master-access-key"] = self.access_key
        return headers


class LeaseConflict(RuntimeError):
    pass


def group_artifacts(
    artifacts: Iterable[Artifact],
) -> dict[tuple[str, str], list[Artifact]]:
    groups: dict[tuple[str, str], list[Artifact]] = {}
    for artifact in artifacts:
        key = (artifact.subject_id, artifact.host)
        groups.setdefault(key, []).append(artifact)
    return groups


def load_distinct_pages(client: MasterClient, artifacts: list[Artifact]) -> list[Page]:
    pages: dict[str, Page] = {}
    for artifact in artifacts:
        key = (
            artifact.body_sha256
            or normalize_url(artifact.fetched_url)
            or artifact.artifact_id
        )
        if key in pages:
            pages[key].artifacts.append(artifact)
            continue

        try:
            pages[key] = Page(
                key=page_dataset_key(artifact),
                content=client.artifact_body(artifact.artifact_id),
                artifacts=[artifact],
            )
        except Exception as error:
            pages[f"error:{artifact.artifact_id}"] = Page(
                key=page_dataset_key(artifact),
                content=b"",
                artifacts=[artifact],
            )
            print(f"failed to load artifact={artifact.artifact_id}: {error}")

    return list(pages.values())


def page_dataset_key(artifact: Artifact) -> str:
    url = normalize_url(artifact.fetched_url) or normalize_url(artifact.source_url)
    return url or f"artifact:{artifact.artifact_id}"


def normalize_url(url: str | None) -> str:
    if not url:
        return ""
    return url.strip()


def extract_with_deboiler(host: str, pages: list[Page]) -> list[Extraction]:
    records = [
        {"url": page.key, "status": 200, "content": page.content}
        for page in pages
        if page.content
    ]
    if len(records) < MIN_DEBOILER_PAGES:
        return extract_with_fallback(pages)

    dataset = ListDataset(records, content_type_key=None, verbose=False)
    deboiler = Deboiler(
        n_processes=1,
        operation_mode="performance",
        domain=host,
        verbose=False,
    )
    deboiler.fit(dataset)
    outputs = {
        output.url: output
        for output in deboiler.transform(dataset, include_cleaned_html=True)
    }

    extractions: list[Extraction] = []
    for page in pages:
        output = outputs.get(page.key)
        if output is None:
            extractions.extend(failed_page_extractions(page, "empty_body"))
            continue
        extractions.extend(page_extractions(page, "succeeded", output))
    return extractions


def extract_with_fallback(pages: list[Page]) -> list[Extraction]:
    deboiler = Deboiler(n_processes=1, operation_mode="memory", verbose=False)
    extractions: list[Extraction] = []
    for page in pages:
        if not page.content:
            extractions.extend(failed_page_extractions(page, "empty_body"))
            continue
        try:
            output = deboiler.transform_parsed_page(
                ParsedPage(page.key, page.content),
                include_cleaned_html=True,
            )
            extractions.extend(page_extractions(page, "fallback_succeeded", output))
        except Exception as error:
            extractions.extend(
                failed_page_extractions(page, "html_parse_error", str(error))
            )
    return extractions


def page_extractions(page: Page, status: str, output) -> list[Extraction]:
    raw_text = output.text or ""
    cleaned_text = output.cleaned_text or ""
    return [
        Extraction(
            artifact_id=artifact.artifact_id,
            extraction_status=status,
            title=output.title,
            headings=output.headings,
            lists=output.lists,
            breadcrumbs=output.breadcrumbs,
            language=output.language,
            raw_text=raw_text,
            cleaned_text=cleaned_text,
            cleaned_html=output.cleaned_html,
            char_count=len(raw_text),
            cleaned_char_count=len(cleaned_text),
            content_type=artifact.content_type,
        )
        for artifact in page.artifacts
    ]


def failed_page_extractions(
    page: Page, status: str, error: str | None = None
) -> list[Extraction]:
    return [
        Extraction(
            artifact_id=artifact.artifact_id,
            extraction_status=status,
            content_type=artifact.content_type,
            error=error,
        )
        for artifact in page.artifacts
    ]


def extraction_payload(
    extraction: Extraction, worker_id: str = ""
) -> dict[str, object]:
    payload = asdict(extraction)
    payload["worker_id"] = worker_id
    for key, value in list(payload.items()):
        if value is None:
            payload[key] = ""
    return payload


if __name__ == "__main__":
    main()
