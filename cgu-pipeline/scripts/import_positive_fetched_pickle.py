#!/usr/bin/env python3
"""Load the positive fetched STA export from input/<export_name>.

Usage:
    python scripts/import_positive_fetched_pickle.py
    python scripts/import_positive_fetched_pickle.py positive_fetched_records.pkl

From another Python file:
    from scripts.import_positive_fetched_pickle import load_export

    data = load_export("positive_fetched_records.pkl")
    records = data["records"]
"""

from __future__ import annotations

import argparse
import pickle
from pathlib import Path
from typing import Any


DEFAULT_EXPORT_NAME = "positive_fetched_records.pkl"
DEFAULT_INPUT_DIR = Path("input")


def load_export(
    export_name: str = DEFAULT_EXPORT_NAME,
    input_dir: str | Path = DEFAULT_INPUT_DIR,
) -> dict[str, Any]:
    """Load a pickle export from input/<export_name>."""
    path = Path(input_dir) / export_name
    with path.open("rb") as file:
        data = pickle.load(file)

    if not isinstance(data, dict):
        raise TypeError(f"Expected top-level dict, got {type(data).__name__}")
    if not isinstance(data.get("records"), list):
        raise TypeError("Expected data['records'] to be a list")

    return data


def first_body_as_text(record: dict[str, Any], encoding: str = "utf-8") -> str:
    """Decode fetched_body.raw_body_bytes for quick inspection."""
    body = record.get("fetched_body") or {}
    raw_body = body.get("raw_body_bytes")
    if raw_body is None:
        return ""
    if not isinstance(raw_body, bytes):
        raise TypeError(
            "Expected record['fetched_body']['raw_body_bytes'] to be bytes"
        )
    return raw_body.decode(encoding, errors="replace")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Load positive fetched STA pickle data."
    )
    parser.add_argument(
        "export_name",
        nargs="?",
        default=DEFAULT_EXPORT_NAME,
        help=f"Pickle filename under input/; default: {DEFAULT_EXPORT_NAME}",
    )
    parser.add_argument(
        "--input-dir",
        default=str(DEFAULT_INPUT_DIR),
        help="Directory containing the export; default: input",
    )
    args = parser.parse_args()

    data = load_export(args.export_name, args.input_dir)
    records = data["records"]
    first_record = records[0] if records else {}

    print(f"type(data): {type(data).__name__}")
    print(f"records: {len(records)}")
    print(f"top-level keys: {list(data.keys())}")
    print(f"record keys: {list(first_record.keys()) if first_record else []}")

    summary = data.get("summary")
    if isinstance(summary, dict):
        print(f"summary: {summary}")

    if first_record:
        parsed_columns = first_record.get("parsed_columns", {})
        fetch = first_record.get("fetch", {})
        print(f"first STA: {parsed_columns.get('sta_id')}")
        print(f"first URL: {parsed_columns.get('URL')}")
        print(f"first fetched URL: {fetch.get('fetched_url')}")
        print(
            "first raw body bytes: "
            f"{len(first_record['fetched_body']['raw_body_bytes'])}"
        )


if __name__ == "__main__":
    main()
