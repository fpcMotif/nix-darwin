# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Census of hook denials and agent tool choices in Claude Code transcripts.

Usage: uv run hook-census.py [--since DATE] [--until DATE] [--out DIR] [--compare BASELINE.json]
DATE is YYYY-MM-DD and bounds each tool call's own timestamp, so long sessions
do not leak events from outside the window. Every denial maps to one rule, and
rule counts sum to each hook's total. A denial whose next call came from the
same assistant message is a parallel sibling; one whose later, separate call
was denied again is a loop. Tasks run from a typed prompt to the last
assistant row before the next prompt (main sessions) or span one subagent run.
--out writes summary.json and representative.jsonl (up to three denied
commands per rule, with $HOME shortened to ~). --compare prints the summary's
headline metrics beside a saved baseline.
"""

import argparse
import json
import re
import statistics
from collections import Counter, defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path.home() / ".claude" / "projects"
DENIAL = re.compile(
    r"^(?:PreToolUse|PostToolUse):?[\w|]* hook error: \[([^\]]+)\]: ?(.*)", re.DOTALL
)
RULES = [
    ("shell.inline_write", r"Inline scripts that call open"),
    ("shell.sed_inplace", r"in-place sed/perl"),
    ("shell.echo_write", r"echo/printf into a file"),
    ("shell.heredoc_write", r"heredoc redirected into a file"),
    ("shell.python", r"Python runs through uv"),
    ("shell.cat", r"cat is denied"),
    ("shell.sed", r"sed is denied"),
    ("shell.find", r"find is denied"),
    ("shell.perl", r"perl one-liners"),
    ("search.codedb_word", r"'codedb word'"),
    ("search.umbrella", r"umbrella"),
    ("search.long_file", r"has \d+ lines"),
    ("search.alternation", r"4\+ alternatives"),
    ("search.grep", r"plain grep"),
    ("read.long_file", r"^read-guard"),
    ("doclock.markdown", r"is Markdown"),
    ("doclock.comments", r"comments"),
]
RETIRED = {"shell.cat", "search.alternation", "search.grep", "read.long_file"}
WRAPPERS = ("sudo", "time", "nohup", "exec", "command", "env", "xargs")
HEADLINE = [
    ("bash calls", ("populations", "all", "bash")),
    ("denials per 1k bash", ("denials", "per_1k_bash")),
    ("avoidable retries per 1k bash", ("avoidable", "per_1k_bash")),
    ("loops", ("loops", "sequential")),
    ("median deny->next s", ("deny_to_next", "median_s")),
    ("main tasks completed share", ("tasks", "main", "completed_share")),
    ("main task median min", ("tasks", "main", "median_min")),
    ("subagent runs completed share", ("tasks", "subagent", "completed_share")),
]


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            b.get("text", "")
            for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        )
    return ""


def ts(row) -> datetime | None:
    try:
        return datetime.fromisoformat(row["timestamp"].replace("Z", "+00:00"))
    except (KeyError, AttributeError, ValueError):
        return None


def hook_of(command: str) -> str:
    m = re.search(r"([\w.-]+)\.sh\b", command)
    return m.group(1) if m else command.split()[0] if command.split() else "?"


def rule_of(hook: str, message: str) -> str:
    family = {
        "shell-guard": "shell.",
        "search-guard": "search.",
        "read-guard": "read.",
        "doc-lock": "doclock.",
    }.get(hook)
    for rule, pattern in RULES:
        if family and rule.startswith(family) and re.search(pattern, message):
            return rule
    return f"{hook}.other"


def first_word(command: str) -> str:
    words = command.strip().split()
    while words and (
        words[0] in WRAPPERS
        or words[0] in ("&&", ";", "||")
        or re.match(r"^[A-Za-z_]\w*=", words[0])
    ):
        words = words[1:]
    if len(words) >= 3 and words[0] == "cd" and words[2] in ("&&", ";"):
        return first_word(" ".join(words[3:]))
    return Path(words[0]).name if words else ""


def is_prompt(row) -> bool:
    if row.get("type") != "user" or row.get("isMeta") or row.get("isSidechain"):
        return False
    content = (row.get("message") or {}).get("content")
    if isinstance(content, list) and any(
        isinstance(b, dict) and b.get("type") == "tool_result" for b in content
    ):
        return False
    text = text_of(content).lstrip()
    return bool(text) and not text.startswith(
        ("<task-notification", "[Request interrupted", "<system-reminder")
    )


def shorten(s: str) -> str:
    return s.replace(str(Path.home()), "~")


def in_window(row, since: str, until: str) -> bool:
    stamp = (row.get("timestamp") or "")[:10]
    return bool(stamp) and since <= stamp <= until


def scan(since: str, until: str):
    cutoff = datetime.fromisoformat(since).timestamp()
    files = [p for p in ROOT.rglob("*.jsonl") if p.stat().st_mtime >= cutoff]
    pop = defaultdict(Counter)
    first = Counter()
    native = Counter()
    denials = []
    tasks = {"main": [], "subagent": []}
    model_bash = Counter()
    for f in files:
        scope = "subagent" if "subagents" in f.parts else "main"
        rows = []
        with f.open(errors="replace") as fh:
            for line in fh:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
        uses: dict[str, dict[str, Any]] = {}
        order = []
        model = None
        for i, r in enumerate(rows):
            msg = r.get("message") or {}
            if r.get("type") != "assistant":
                continue
            model = msg.get("model") or model
            for b in msg.get("content") or []:
                if not (isinstance(b, dict) and b.get("type") == "tool_use"):
                    continue
                uses[b["id"]] = {
                    "tool": b.get("name"),
                    "input": b.get("input") or {},
                    "row": i,
                    "msg": msg.get("id"),
                    "ts": ts(r),
                    "model": model,
                    "window": in_window(r, since, until),
                }
                order.append(b["id"])
                if not in_window(r, since, until):
                    continue
                pop[scope]["tool_calls"] += 1
                name = b.get("name")
                if name == "Bash":
                    pop[scope]["bash"] += 1
                    model_bash[model] += 1
                    first[
                        first_word(str((b.get("input") or {}).get("command", "")))
                    ] += 1
                else:
                    native[name] += 1
        position = {tid: k for k, tid in enumerate(order)}
        denied_rows = []
        for i, r in enumerate(rows):
            msg = r.get("message") or {}
            if r.get("type") != "user" or not isinstance(msg.get("content"), list):
                continue
            for b in msg["content"]:
                if not (isinstance(b, dict) and b.get("type") == "tool_result"):
                    continue
                m = DENIAL.match(text_of(b.get("content")).strip())
                use = uses.get(b.get("tool_use_id"))
                if not m or not use or not use["window"]:
                    continue
                hook = hook_of(m.group(1))
                k = position[b["tool_use_id"]]
                nxt = uses[order[k + 1]] if k + 1 < len(order) else None
                sibling = bool(nxt and nxt["msg"] and nxt["msg"] == use["msg"])
                later_id = next(
                    (t for t in order[k + 1 :] if uses[t]["msg"] != use["msg"]), None
                )
                later = uses.get(later_id)
                gap = (
                    (later["ts"] - use["ts"]).total_seconds()
                    if later and later["ts"] and use["ts"]
                    else None
                )
                denials.append(
                    {
                        "id": b["tool_use_id"],
                        "hook": hook,
                        "rule": rule_of(hook, m.group(2)),
                        "scope": scope,
                        "model": use["model"],
                        "tool": use["tool"],
                        "input": shorten(
                            str(
                                use["input"].get("command")
                                or use["input"].get("file_path")
                                or ""
                            )
                        )[:300],
                        "message": shorten(m.group(2).strip().split("\n")[0])[:200],
                        "sibling": sibling,
                        "later_id": later_id,
                        "gap": gap,
                        "file": str(f),
                    }
                )
                denied_rows.append(i)
        if scope == "subagent":
            stamps = [t for r in rows if in_window(r, since, until) and (t := ts(r))]
            if stamps:
                last = next(
                    (r for r in reversed(rows) if r.get("type") == "assistant"), {}
                )
                done = any(
                    isinstance(b, dict) and b.get("type") == "text"
                    for b in (last.get("message") or {}).get("content") or []
                )
                tasks["subagent"].append(
                    {
                        "minutes": (max(stamps) - min(stamps)).total_seconds() / 60,
                        "outcome": "completed" if done else "open",
                        "denials": sum(1 for d in denials if d["file"] == str(f)),
                    }
                )
            continue
        prompts = [
            i for i, r in enumerate(rows) if is_prompt(r) and in_window(r, since, until)
        ]
        for a, start in enumerate(prompts):
            end = prompts[a + 1] if a + 1 < len(prompts) else len(rows)
            span = rows[start:end]
            assistants = [r for r in span if r.get("type") == "assistant"]
            began = ts(rows[start])
            ended = ts(assistants[-1]) if assistants else None
            if not began or not ended:
                continue
            interrupted = any(
                r.get("type") == "user"
                and text_of((r.get("message") or {}).get("content")).startswith(
                    "[Request interrupted"
                )
                for r in span
            )
            content = (assistants[-1].get("message") or {}).get("content") or []
            ended_in_text = any(
                isinstance(b, dict) and b.get("type") == "text" for b in content
            ) and not any(
                isinstance(b, dict) and b.get("type") == "tool_use" for b in content
            )
            tasks["main"].append(
                {
                    "minutes": (ended - began).total_seconds() / 60,
                    "outcome": "interrupted"
                    if interrupted
                    else "completed"
                    if ended_in_text
                    else "open",
                    "denials": sum(1 for i in denied_rows if start <= i < end),
                }
            )
    return files, pop, first, native, denials, tasks, model_bash


def summarize(since, until, files, pop, first, native, denials, tasks, model_bash):
    ids = {d["id"] for d in denials}
    bash = sum(p["bash"] for p in pop.values())
    by_hook = Counter(d["hook"] for d in denials)
    by_rule = Counter(d["rule"] for d in denials)
    loops = sum(1 for d in denials if d["later_id"] in ids and not d["sibling"])
    retired = sum(1 for d in denials if d["rule"] in RETIRED)
    gaps = [d["gap"] for d in denials if d["gap"] is not None and 0 <= d["gap"] < 600]
    rules_by_hook = defaultdict(dict)
    for rule, n in by_rule.most_common():
        hook = next(d["hook"] for d in denials if d["rule"] == rule)
        rules_by_hook[hook][rule] = n

    def task_stats(items):
        if not items:
            return {"n": 0}
        outcomes = Counter(t["outcome"] for t in items)
        return {
            "n": len(items),
            "completed_share": round(outcomes["completed"] / len(items), 3),
            "interrupted_share": round(outcomes["interrupted"] / len(items), 3),
            "median_min": round(statistics.median(t["minutes"] for t in items), 2),
            "median_min_with_denial": round(
                statistics.median([t["minutes"] for t in items if t["denials"]] or [0]),
                2,
            ),
            "median_min_without_denial": round(
                statistics.median(
                    [t["minutes"] for t in items if not t["denials"]] or [0]
                ),
                2,
            ),
            "share_with_denial": round(
                sum(1 for t in items if t["denials"]) / len(items), 3
            ),
        }

    per_1k = lambda n: round(1000 * n / bash, 1) if bash else None
    return {
        "window": {"since": since, "until": until, "files": len(files)},
        "populations": {
            "all": {
                "bash": bash,
                "tool_calls": sum(p["tool_calls"] for p in pop.values()),
            },
            **{k: dict(v) for k, v in pop.items()},
        },
        "denials": {
            "total": len(denials),
            "per_1k_bash": per_1k(len(denials)),
            "by_hook": dict(by_hook.most_common()),
            "by_rule": dict(rules_by_hook),
            "by_scope": dict(Counter(d["scope"] for d in denials)),
            "reconciled": all(
                sum(rules_by_hook[h].values()) == n for h, n in by_hook.items()
            ),
        },
        "loops": {
            "sequential": loops,
            "parallel_siblings": sum(1 for d in denials if d["sibling"]),
        },
        "avoidable": {
            "retired_rules": retired,
            "loops": loops,
            "per_1k_bash": per_1k(retired + loops),
        },
        "deny_to_next": {
            "n": len(gaps),
            "median_s": round(statistics.median(gaps), 1) if gaps else None,
            "total_min": round(sum(gaps) / 60, 1),
        },
        "first_choice": {
            "bash_first_word": dict(first.most_common(30)),
            "native_tools": dict(native.most_common(15)),
        },
        "models": {
            m: {"bash": n, "denials": sum(1 for d in denials if d["model"] == m)}
            for m, n in model_bash.most_common()
            if n >= 100
        },
        "tasks": {
            "main": task_stats(tasks["main"]),
            "subagent": task_stats(tasks["subagent"]),
        },
    }


def dig(obj, path):
    for key in path:
        obj = (obj or {}).get(key)
    return obj


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", default="2026-09-28")
    ap.add_argument("--until", default=datetime.now(UTC).strftime("%Y-%m-%d"))
    ap.add_argument("--out", type=Path)
    ap.add_argument("--compare", type=Path)
    args = ap.parse_args()
    files, pop, first, native, denials, tasks, model_bash = scan(args.since, args.until)
    summary = summarize(
        args.since, args.until, files, pop, first, native, denials, tasks, model_bash
    )
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "summary.json").write_text(json.dumps(summary, indent=1) + "\n")
        examples = defaultdict(list)
        for d in denials:
            if len(examples[d["rule"]]) < 3:
                examples[d["rule"]].append(
                    {
                        k: d[k]
                        for k in ("rule", "scope", "model", "tool", "input", "message")
                    }
                )
        (args.out / "representative.jsonl").write_text(
            "".join(
                json.dumps(e) + "\n"
                for rule in sorted(examples)
                for e in examples[rule]
            )
        )
    if args.compare:
        base = json.loads(args.compare.read_text())
        print(f"{'metric':34} {'baseline':>10} {'now':>10}")
        for label, path in HEADLINE:
            print(f"{label:34} {dig(base, path)!s:>10} {dig(summary, path)!s:>10}")
        for hook in sorted(
            set(dig(base, ("denials", "by_rule")) or {})
            | set(summary["denials"]["by_rule"])
        ):
            rules = set(dig(base, ("denials", "by_rule", hook)) or {}) | set(
                summary["denials"]["by_rule"].get(hook, {})
            )
            for rule in sorted(rules):
                print(
                    f"  {rule:32} {dig(base, ('denials', 'by_rule', hook, rule)) or 0!s:>10} "
                    f"{summary['denials']['by_rule'].get(hook, {}).get(rule, 0)!s:>10}"
                )
    else:
        print(json.dumps(summary, indent=1))


if __name__ == "__main__":
    main()
