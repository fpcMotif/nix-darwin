# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""How batched are Edit calls in Claude Code transcripts?

Usage: uv run edit-batching-census.py TRANSCRIPT.jsonl [...]
Claude Code stores each content block of one assistant message as its own line sharing
message.id, so consecutive lines with one id are merged into one message first. Then, per message:
number of Edit blocks. A serial chain = consecutive assistant messages that each carry exactly one
Edit and no other tool call. Also counts replace_all use and multi-match errors.
"""

import json
import sys
from collections import Counter


def messages(path: str) -> list[dict]:
    """Assistant messages merged by id, in order, plus user entries as chain breakers."""
    out: list[dict] = []
    by_id: dict[str, dict] = {}
    with open(path) as fh:
        for line in fh:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = obj.get("message") or {}
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            blocks = [b for b in content if isinstance(b, dict)]
            if obj.get("type") == "assistant":
                entry = by_id.get(msg.get("id"))
                if entry is None:
                    entry = {"role": "assistant", "id": msg.get("id"), "blocks": []}
                    by_id[msg.get("id")] = entry
                    out.append(entry)
                entry["blocks"].extend(blocks)
            else:
                out.append({"role": "user", "id": "", "blocks": blocks})
    return out


def main(paths: list[str]) -> None:
    edits = replace_all = multi_match_errors = 0
    per_message: Counter = Counter()
    chain_lengths: list[int] = []
    for path in paths:
        edit_ids: set[str] = set()
        chain = 0
        for m in messages(path):
            if m["role"] == "user":
                for b in m["blocks"]:
                    if (
                        b.get("type") == "tool_result"
                        and b.get("is_error")
                        and b.get("tool_use_id") in edit_ids
                    ):
                        text = json.dumps(b.get("content", ""))
                        if "replace_all" in text or "matches" in text:
                            multi_match_errors += 1
                continue
            tools = [b for b in m["blocks"] if b.get("type") == "tool_use"]
            if not tools:
                continue
            edit_blocks = [b for b in tools if b.get("name") == "Edit"]
            edits += len(edit_blocks)
            replace_all += sum(
                1 for b in edit_blocks if (b.get("input") or {}).get("replace_all")
            )
            edit_ids.update(b["id"] for b in edit_blocks)
            if edit_blocks:
                per_message[min(len(edit_blocks), 4)] += 1
            if len(edit_blocks) == 1 and len(tools) == 1:
                chain += 1
            else:
                if chain >= 2:
                    chain_lengths.append(chain)
                chain = 0
        if chain >= 2:
            chain_lengths.append(chain)
    batched = sum(v for k, v in per_message.items() if k >= 2)
    print(f"Edit calls: {edits}; replace_all used: {replace_all}")
    print(
        f"messages with 1 Edit: {per_message[1]}; with 2+ Edits: {batched} "
        f"(2: {per_message[2]}, 3: {per_message[3]}, 4+: {per_message[4]})"
    )
    print(
        f"serial chains (consecutive single-Edit turns): {len(chain_lengths)}, "
        f"edits inside them: {sum(chain_lengths)}, longest: {max(chain_lengths, default=0)}"
    )
    print(f"Edit errors about multiple matches: {multi_match_errors}")


if __name__ == "__main__":
    main(sys.argv[1:])
