# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Two-arm trial of the Claude search routes on headless Claude Code.

Usage: uv run search-routing-trial.py [--runs 2] [--model sonnet] [--workers 4] [--out results.json]

Arm "base": fff and codedb registered without alwaysLoad, no Search section beyond the installed CLAUDE.md.
Arm "routes": fff and codedb with alwaysLoad, plus the Search section of modules/home/claude/CLAUDE.md
appended to the system prompt. Both arms keep the user's settings and hooks. Each run answers a read-only
question in a real repository; the census is the ordered tool calls and whether the answer names the target.
"""

import argparse
import json
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
CLAUDE_MD = HERE.parent / "CLAUDE.md"
REPO = Path.home() / "devv/outlook-feishu-bridge-pr427"
FFF = "/etc/profiles/per-user/martinfan/bin/fff-mcp"
CODEDB = str(Path.home() / "bin/codedb")

ROUTED = ("mcp__fff__", "mcp__codedb__")
SHELL_SEARCH = ("rg", "fd", "find", "grep", "ls", "eza", "codedb", "tree")


@dataclass
class Case:
    name: str
    prompt: str
    target: str


CASES = [
    Case(
        "symbol",
        "Where is isOversizeAttachment defined, and which functions call it? Give file:line for each. Do not edit anything.",
        "attachmentPolicy",
    ),
    Case(
        "file",
        "Which script enforces the JSDoc policy in CI? Give its path. Do not edit anything.",
        "check-jsdoc-policy.ts",
    ),
]


def mcp_config(always_load: bool) -> dict:
    servers = {
        "fff": {"type": "stdio", "command": FFF, "args": []},
        "codedb": {"type": "stdio", "command": CODEDB, "args": ["mcp"]},
    }
    if always_load:
        for server in servers.values():
            server["alwaysLoad"] = True
    return {"mcpServers": servers}


def search_section() -> str:
    text = CLAUDE_MD.read_text()
    return text[text.index("## Search") :]


def classify(block: dict) -> str | None:
    name = block["name"]
    if name.startswith(ROUTED):
        return name
    if name == "Bash":
        words = block["input"].get("command", "").replace("&&", " ").split()
        head = next((w for w in words if w not in ("cd", "z") and not w.startswith(("/", "~", "."))), "")
        return f"Bash:{head}" if head in SHELL_SEARCH else None
    if name in ("Read", "Glob", "Grep", "ToolSearch"):
        return name
    return None


def run(arm: str, case: Case, index: int, model: str, workdir: Path) -> dict:
    config = workdir / f"mcp-{arm}.json"
    command = [
        "claude", "-p", case.prompt,
        "--model", model,
        "--output-format", "stream-json", "--verbose",
        "--strict-mcp-config", "--mcp-config", str(config),
        "--disallowedTools", "Edit", "Write", "NotebookEdit",
        "--max-turns", "20",
    ]
    if arm == "routes":
        command += ["--append-system-prompt-file", str(workdir / "search.md")]
    proc = subprocess.run(command, cwd=REPO, capture_output=True, text=True, timeout=600)
    calls, result = [], ""
    for line in proc.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "assistant":
            for block in event["message"].get("content", []):
                if block.get("type") == "tool_use" and (label := classify(block)):
                    calls.append(label)
        elif event.get("type") == "result":
            result = event.get("result", "")
    routed = sum(c.startswith(ROUTED) for c in calls)
    return {
        "arm": arm, "case": case.name, "run": index,
        "first": calls[0] if calls else None,
        "routed": routed, "searches": len(calls),
        "correct": case.target in result, "calls": calls,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=2)
    parser.add_argument("--model", default="sonnet")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    workdir = Path(tempfile.mkdtemp(prefix="search-routing-trial-"))
    (workdir / "mcp-base.json").write_text(json.dumps(mcp_config(False)))
    (workdir / "mcp-routes.json").write_text(json.dumps(mcp_config(True)))
    (workdir / "search.md").write_text(search_section())

    jobs = [(arm, case, i) for arm in ("base", "routes") for case in CASES for i in range(args.runs)]
    with ThreadPoolExecutor(args.workers) as pool:
        rows = list(pool.map(lambda job: run(*job, args.model, workdir), jobs))

    for row in rows:
        print(f"{row['arm']:6} {row['case']:6} #{row['run']} first={row['first']} "
              f"routed={row['routed']}/{row['searches']} correct={row['correct']} {row['calls']}")
    for arm in ("base", "routes"):
        mine = [r for r in rows if r["arm"] == arm]
        first = sum((r["first"] or "").startswith(ROUTED) for r in mine)
        routed = sum(r["routed"] for r in mine)
        searches = sum(r["searches"] for r in mine)
        correct = sum(r["correct"] for r in mine)
        print(f"{arm}: first call routed {first}/{len(mine)}, routed calls {routed}/{searches}, correct {correct}/{len(mine)}")
    if args.out:
        args.out.write_text(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()
