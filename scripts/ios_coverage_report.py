#!/usr/bin/env python3
"""Generate an HTML iOS coverage report from xccov JSON and enforce a target."""

from __future__ import annotations

import argparse
import html
import json
from pathlib import Path


def percent(value: float | int | None) -> float:
    if value is None:
        return 0.0
    value = float(value)
    return value * 100 if value <= 1 else value


def file_rows(report: dict, include: list[str]) -> list[dict]:
    rows: list[dict] = []
    for target in report.get("targets", []):
        target_name = target.get("name", "Unknown target")
        for file_info in target.get("files", []):
            path = file_info.get("path") or file_info.get("name") or "Unknown file"
            normalized = path.replace("\\", "/")
            if include and not any(pattern in normalized for pattern in include):
                continue
            rows.append(
                {
                    "target": target_name,
                    "path": normalized,
                    "coverage": percent(file_info.get("lineCoverage")),
                    "covered": int(file_info.get("coveredLines", 0)),
                    "executable": int(file_info.get("executableLines", 0)),
                }
            )
    return sorted(rows, key=lambda row: row["path"])


def weighted_coverage(rows: list[dict]) -> float:
    executable = sum(row["executable"] for row in rows)
    if executable == 0:
        return 100.0
    covered = sum(row["covered"] for row in rows)
    return covered / executable * 100


def render_html(rows: list[dict], overall: float, threshold: float, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    badge_class = "pass" if overall >= threshold else "fail"
    table_rows = "\n".join(
        "<tr>"
        f"<td>{html.escape(row['target'])}</td>"
        f"<td>{html.escape(row['path'])}</td>"
        f"<td>{row['coverage']:.2f}%</td>"
        f"<td>{row['covered']}/{row['executable']}</td>"
        "</tr>"
        for row in rows
    )
    (output / "index.html").write_text(
        f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>iOS Coverage</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; color: #18211e; }}
    .metric {{ display: inline-block; padding: 12px 16px; border: 1px solid #d5ded9; border-radius: 8px; }}
    .pass {{ color: #136c43; }}
    .fail {{ color: #a32626; }}
    table {{ border-collapse: collapse; margin-top: 24px; width: 100%; }}
    th, td {{ border-bottom: 1px solid #e2e8e4; padding: 10px 8px; text-align: left; }}
    th {{ background: #f6faf7; }}
  </style>
</head>
<body>
  <h1>iOS Coverage</h1>
  <div class="metric {badge_class}">
    <strong>{overall:.2f}%</strong> covered, target {threshold:.2f}%
  </div>
  <table>
    <thead><tr><th>Target</th><th>File</th><th>Coverage</th><th>Lines</th></tr></thead>
    <tbody>{table_rows}</tbody>
  </table>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--threshold", type=float, default=100.0)
    parser.add_argument(
        "--include",
        action="append",
        default=[],
        help="Substring filter for files included in the strict gate. Repeatable.",
    )
    args = parser.parse_args()

    report = json.loads(args.input.read_text(encoding="utf-8"))
    rows = file_rows(report, args.include)
    overall = weighted_coverage(rows)
    render_html(rows, overall, args.threshold, args.output)

    if overall + 0.0001 < args.threshold:
        print(f"iOS coverage {overall:.2f}% is below required {args.threshold:.2f}%.")
        return 1

    print(f"iOS coverage {overall:.2f}% meets required {args.threshold:.2f}%.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
