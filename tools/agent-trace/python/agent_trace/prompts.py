from .parse import (
    MalformedCounter,
    iter_records,
    jsonl_files,
    project_for_path,
    queue_prompt,
    session_id,
    session_for_path,
    text_preview,
    user_prompt,
)


def collect(root, grep=None, min_len=0):
    malformed = MalformedCounter()
    rows = []
    needle = grep.lower() if isinstance(grep, str) and grep else None

    for path in jsonl_files(root):
        project = project_for_path(path)
        sid = session_for_path(path)
        first_queue = None
        first_user = None

        for record in iter_records(path, malformed):
            sid = session_id(record, path)
            prompt = queue_prompt(record)
            if prompt is not None and first_queue is None:
                first_queue = {
                    "timestamp": record.get("timestamp") or "",
                    "project": project,
                    "sessionId": sid,
                    "source": "queue-operation",
                    "length": len(prompt),
                    "prompt": prompt,
                }
            prompt = user_prompt(record)
            if prompt is not None and first_user is None:
                first_user = {
                    "timestamp": record.get("timestamp") or "",
                    "project": project,
                    "sessionId": sid,
                    "source": "user",
                    "length": len(prompt),
                    "prompt": prompt,
                }

        chosen = first_queue if first_queue is not None else first_user
        if chosen is None:
            continue
        if chosen["length"] < min_len:
            continue
        if needle is not None and needle not in chosen["prompt"].lower():
            continue
        rows.append(chosen)

    rows.sort(key=lambda row: (row["timestamp"], row["project"], row["sessionId"]))
    return {
        "root": str(root),
        "malformed": malformed.as_dict(),
        "prompts": rows,
    }


def _format_rows(headers, rows):
    text_rows = [[str(value) for value in row] for row in rows]
    widths = [len(str(header)) for header in headers]
    for row in text_rows:
        for idx, value in enumerate(row):
            if len(value) > widths[idx]:
                widths[idx] = len(value)
    lines = []
    lines.append("  ".join(str(header).ljust(widths[idx]) for idx, header in enumerate(headers)))
    lines.append("  ".join("-" * width for width in widths))
    for row in text_rows:
        lines.append("  ".join(value.ljust(widths[idx]) for idx, value in enumerate(row)))
    return lines


def format_table(data):
    rows = []
    for item in data["prompts"]:
        rows.append(
            (
                item["timestamp"],
                item["project"],
                item["sessionId"],
                item["source"],
                item["length"],
                text_preview(item["prompt"], 160),
            )
        )
    if not rows:
        return "timestamp  project  sessionId  source  length  prompt\n---------  -------  ---------  ------  ------  ------"
    return "\n".join(_format_rows(("timestamp", "project", "sessionId", "source", "length", "prompt"), rows))
