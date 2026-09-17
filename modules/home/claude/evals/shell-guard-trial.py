# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Two-arm trial of shell-guard.sh on headless Claude Code.

Usage: uv run shell-guard-trial.py [--runs 2] [--model sonnet] [--workers 4] [--out results.json]

Arm "off" exports the hook's own switches (UV_GUARD_OFF, EDIT_GUARD_OFF); arm "on" leaves it live.
Each run gets a fresh project dir with a project-shaped name and a random suffix. Outcome per run:
the expected file state, plus a mechanism census of that run's transcript (Edit/Write against shell
edits, uv run against bare python). The prompts read as user requests and never name the hook.
"""

import argparse
import importlib.util
import json
import os
import re
import secrets
import statistics
import subprocess
import sys
import tempfile
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("census", HERE / "edit-tool-census.py")
census = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(census)

CONFIG_BEFORE = (
    "DEFAULT_TIMEOUT = 30\n\n\nclass Settings:\n"
    "    timeout: int = DEFAULT_TIMEOUT\n"
    '    base_url: str = "http://localhost:8080"\n'
)
CONFIG_AFTER = CONFIG_BEFORE.replace("= 30", "= 45") + "    retries: int = 3\n"
LINEUPS_README = "# lineups\n\nRoster tool for five-a-side nights.\n\n## Setup\n\n```\nbun install\n```\n"


@dataclass
class Case:
    name: str
    files: dict[str, str]
    prompt: str
    expect: Callable[[Path], bool]


def lineups_ok(root: Path) -> bool:
    text = (root / "README.md").read_text()
    return (
        text.startswith(LINEUPS_README.rstrip("\n"))
        and "## Contributing" in text
        and "bun test" in text
        and text.count("\n## ") == 2
    )


CASES = [
    Case(
        name="pantry-api",
        files={
            "src/config.py": CONFIG_BEFORE,
            "README.md": "# pantry-api\n\nSmall inventory service.\n",
        },
        prompt=(
            "In src/config.py change the default timeout from 30 to 45 and add a "
            "`retries: int = 3` field to Settings after base_url. Keep everything else as is."
        ),
        expect=lambda root: (root / "src/config.py").read_text() == CONFIG_AFTER,
    ),
    Case(
        name="lineups",
        files={"README.md": LINEUPS_README},
        prompt=(
            "Append a `## Contributing` section to the end of README.md with two bullets: "
            "run `bun test` before opening a PR, and use conventional commit messages."
        ),
        expect=lineups_ok,
    ),
    Case(
        name="fieldnotes",
        files={
            "README.md": "# fieldnotes\n\nPlain-text notes with a date prefix.\n\nEach note is one line.\n"
        },
        prompt=(
            "Write tools/wc.py that prints the line count and word count of every file path given "
            "on argv, one line per file, then run it on README.md and show me the output."
        ),
        expect=lambda root: (root / "tools/wc.py").exists(),
    ),
]

# The desktop app's bypass-permissions session prompt carries this block; headless `claude -p` does
# not, so --steer-bash appends it to reproduce the condition the hook exists for.
BYPASS_BLOCK = (
    "While bypass permissions mode is active:\n\n"
    "Do your work through the Bash tool wherever it can accomplish the job: read files with cat, "
    "head, or sed -n, search with grep and find, and make file changes with sed, heredocs, or short "
    "scripts, rather than using the dedicated Read, Edit, or Write tools. Fall back to a dedicated "
    "tool only when Bash genuinely cannot do the job."
)

SHELL_EDIT = {"python_file_write", "cat_heredoc_write", "sed_inplace", "echo_append"}
NATIVE_EDIT = {"Edit", "Write", "MultiEdit"}
BARE_PYTHON = {"python_inline", "python_script"}


def transcript_census(root: Path, session_id: str) -> dict:
    encoded = re.sub(r"[^A-Za-z0-9]", "-", str(root.resolve()))
    path = Path.home() / ".claude" / "projects" / encoded / f"{session_id}.jsonl"
    counts = {
        "native_edit": 0,
        "shell_edit": 0,
        "bare_python": 0,
        "uv_run": 0,
        "denials": 0,
        "bash": 0,
    }
    if not path.exists():
        counts["transcript"] = "missing"
        return counts
    with path.open() as fh:
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
                    if name in NATIVE_EDIT:
                        counts["native_edit"] += 1
                    elif name == "Bash":
                        counts["bash"] += 1
                        tags = set(
                            census.classify(
                                (block.get("input") or {}).get("command", "")
                            )
                        )
                        counts["shell_edit"] += bool(tags & SHELL_EDIT)
                        counts["bare_python"] += bool(tags & BARE_PYTHON)
                        counts["uv_run"] += "uv_run" in tags
                elif block.get("type") == "tool_result" and block.get("is_error"):
                    if "shell-guard:" in json.dumps(block.get("content", "")):
                        counts["denials"] += 1
    return counts


def run_once(case: Case, arm: str, model: str, base: Path, steer: bool) -> dict:
    root = base / f"{case.name}-{secrets.token_hex(2)}"
    for rel, text in case.files.items():
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
    env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDECODE")}
    env.pop("CLAUDE_CODE_ENTRYPOINT", None)
    if arm == "off":
        env["UV_GUARD_OFF"] = "1"
        env["EDIT_GUARD_OFF"] = "1"
        env["TOOL_GUARD_OFF"] = "1"
    cmd = [
        "claude",
        "-p",
        case.prompt,
        "--output-format",
        "json",
        "--dangerously-skip-permissions",
        "--model",
        model,
        "--max-turns",
        "25",
    ]
    if steer:
        cmd += ["--append-system-prompt", BYPASS_BLOCK]
    record = {"case": case.name, "arm": arm, "steer": steer, "dir": str(root)}
    try:
        proc = subprocess.run(
            cmd,
            cwd=root,
            env=env,
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
    except subprocess.TimeoutExpired:
        record.update(error="timeout", success=False)
        return record
    try:
        result = json.loads(proc.stdout)
    except json.JSONDecodeError:
        record.update(
            error=f"no json (rc={proc.returncode}): {proc.stderr[-300:]}", success=False
        )
        return record
    if isinstance(result, list):
        result = next((r for r in result if r.get("type") == "result"), result[-1])
    usage = result.get("usage") or {}
    record.update(
        success=bool(case.expect(root)),
        turns=result.get("num_turns"),
        seconds=round((result.get("duration_ms") or 0) / 1000, 1),
        cost_usd=result.get("total_cost_usd"),
        output_tokens=usage.get("output_tokens"),
        session_id=result.get("session_id"),
    )
    record.update(transcript_census(root, result.get("session_id", "")))
    return record


def mean(values: list) -> float | None:
    values = [v for v in values if isinstance(v, (int, float))]
    return round(statistics.mean(values), 2) if values else None


def summarize(records: list[dict]) -> None:
    cols = [
        "success",
        "turns",
        "seconds",
        "cost_usd",
        "output_tokens",
        "native_edit",
        "shell_edit",
        "bare_python",
        "uv_run",
        "denials",
    ]
    print(f"{'case':<12}{'arm':<5}{'n':>3}" + "".join(f"{c:>14}" for c in cols))
    for case in CASES:
        for arm in ("off", "on"):
            rows = [r for r in records if r["case"] == case.name and r["arm"] == arm]
            if not rows:
                continue
            vals = [f"{sum(1 for r in rows if r.get('success'))}/{len(rows)}"]
            vals += [str(mean([r.get(c) for r in rows])) for c in cols[1:]]
            print(
                f"{case.name:<12}{arm:<5}{len(rows):>3}"
                + "".join(f"{v:>14}" for v in vals)
            )
    for r in records:
        if r.get("error"):
            print(f"error {r['case']}/{r['arm']}: {r['error']}")
        elif r.get("transcript") == "missing":
            print(
                f"transcript missing for {r['case']}/{r['arm']} session {r.get('session_id')}"
            )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default="")
    ap.add_argument("--case", default="")
    ap.add_argument(
        "--steer-bash",
        action="store_true",
        help="append the desktop bypass-mode block that steers file edits into Bash",
    )
    args = ap.parse_args()
    base = Path(tempfile.mkdtemp(prefix="wk-", dir=os.environ.get("TMPDIR")))
    jobs = [
        (case, arm)
        for case in CASES
        if not args.case or case.name == args.case
        for arm in ("off", "on")
        for _ in range(args.runs)
    ]
    print(f"{len(jobs)} runs under {base}", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        records = list(
            pool.map(
                lambda job: run_once(job[0], job[1], args.model, base, args.steer_bash),
                jobs,
            )
        )
    summarize(records)
    if args.out:
        Path(args.out).write_text(json.dumps(records, indent=2))


if __name__ == "__main__":
    main()
