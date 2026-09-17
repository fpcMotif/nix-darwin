# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Census of file-edit mechanisms in Claude Code transcripts.

Usage: uv run edit-tool-census.py TRANSCRIPT.jsonl [...]
Counts native Edit/Write calls against Bash-driven edits (python heredocs,
cat heredocs, sed -i), with error rates and input sizes per mechanism.
"""

import json
import re
import statistics
import sys
from collections import defaultdict

NATIVE = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
LEAD = r"(?:^|[;&|(\s])"
RULES = [
    ("uv_run", re.compile(LEAD + r"(?:uv run|uvx)\b")),
    (
        "python_file_write",
        re.compile(
            r"python3?\b.*(?:open\([^)]*['\"][wa]|write_text\(|\.write\()", re.DOTALL
        ),
    ),
    (
        "python_inline",
        re.compile(LEAD + r"python3?\s+(?:-\s*<<|-c\b|-\s*$)", re.MULTILINE),
    ),
    ("python_script", re.compile(LEAD + r"python3?\s+\S+\.py\b")),
    (
        "cat_heredoc_write",
        re.compile(r"(?:cat|tee)\b[^|\n]*(?:>{1,2}\s*\S+[^|\n]*<<|<<[^|\n]*>{1,2})"),
    ),
    ("sed_inplace", re.compile(LEAD + r"(?:sed\s+-i|perl\s+-p?i)")),
    ("echo_append", re.compile(LEAD + r"(?:echo|printf)\b[^|;\n]*>>")),
]
GUARD = re.compile(r"\bassert\b|\braise\b|sys\.exit|\bcount\(|!= s\b|== s\b")


def classify(cmd: str) -> list[str]:
    tags = [name for name, rx in RULES if rx.search(cmd)]
    return tags or ["bash_other"]


def main(paths: list[str]) -> None:
    calls: dict[str, dict] = {}
    for path in paths:
        with open(path) as fh:
            for line in fh:
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                content = (obj.get("message") or {}).get("content")
                if not isinstance(content, list):
                    continue
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "tool_use":
                        name = block.get("name", "")
                        inp = block.get("input") or {}
                        if name in NATIVE:
                            tags = [name]
                            text = json.dumps(inp)
                            guarded = True
                        elif name == "Bash":
                            text = inp.get("command", "")
                            tags = classify(text)
                            guarded = bool(GUARD.search(text))
                        else:
                            continue
                        calls[block["id"]] = {
                            "tags": tags,
                            "chars": len(text),
                            "guarded": guarded,
                            "error": None,
                            "src": path,
                        }
                    elif block.get("type") == "tool_result":
                        rec = calls.get(block.get("tool_use_id"))
                        if rec is not None:
                            rec["error"] = bool(block.get("is_error"))

    by_tag: dict[str, list[dict]] = defaultdict(list)
    for rec in calls.values():
        for tag in rec["tags"]:
            by_tag[tag].append(rec)

    print(
        f"{'mechanism':<20}{'calls':>7}{'errors':>8}{'err%':>7}{'median_chars':>14}{'guarded%':>10}"
    )
    for tag, recs in sorted(by_tag.items(), key=lambda kv: -len(kv[1])):
        errs = sum(1 for r in recs if r["error"])
        med = int(statistics.median(r["chars"] for r in recs))
        guarded = sum(1 for r in recs if r["guarded"])
        print(
            f"{tag:<20}{len(recs):>7}{errs:>8}{100 * errs / len(recs):>6.1f}%"
            f"{med:>14}{100 * guarded / len(recs):>9.0f}%"
        )

    py_edits = by_tag.get("python_file_write", [])
    unguarded = [r for r in py_edits if not r["guarded"]]
    print(
        f"\npython file-writes with no assert/raise/count guard: {len(unguarded)}/{len(py_edits)}"
    )


if __name__ == "__main__":
    main(sys.argv[1:])
