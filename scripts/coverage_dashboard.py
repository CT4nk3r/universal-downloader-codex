#!/usr/bin/env python3
"""Build a small cross-platform coverage dashboard for CI artifacts."""

from __future__ import annotations

import argparse
import csv
import html
from pathlib import Path


def android_summary(csv_path: Path) -> tuple[float, str]:
    if not csv_path.exists():
        return 0.0, "Android JaCoCo CSV not found"

    missed = 0
    covered = 0
    with csv_path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            missed += int(row.get("INSTRUCTION_MISSED", 0))
            covered += int(row.get("INSTRUCTION_COVERED", 0))
    total = missed + covered
    coverage = 100.0 if total == 0 else covered / total * 100
    return coverage, f"{covered}/{total} instructions covered"


def write_dashboard(output: Path, android_csv: Path, ios_html: Path | None) -> None:
    output.mkdir(parents=True, exist_ok=True)
    android_coverage, android_detail = android_summary(android_csv)
    ios_link = '<a href="../ios/index.html">iOS coverage report</a>' if ios_html else "iOS report not provided"
    (output / "index.html").write_text(
        f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Universal Downloader Coverage</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; color: #17201d; }}
    section {{ border: 1px solid #dce5df; border-radius: 8px; padding: 18px; margin-bottom: 16px; }}
    a {{ color: #0b6e55; }}
  </style>
</head>
<body>
  <h1>Universal Downloader Coverage</h1>
  <section>
    <h2>Android Unit Coverage</h2>
    <p><strong>{android_coverage:.2f}%</strong> - {html.escape(android_detail)}</p>
    <p><a href="../android/html/index.html">Android JaCoCo HTML report</a></p>
  </section>
  <section>
    <h2>iOS Unit Coverage</h2>
    <p>{ios_link}</p>
  </section>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--android-csv", required=True, type=Path)
    parser.add_argument("--ios-html", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    write_dashboard(args.output, args.android_csv, args.ios_html)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
