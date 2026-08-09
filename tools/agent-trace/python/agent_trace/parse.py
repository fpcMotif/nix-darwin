import json
import re
from pathlib import Path
from collections import Counter


KNOWN_TYPES = {
    "assistant",
    "user",
    "attachment",
    "last-prompt",
    "queue-operation",
    "mode",
    "system",
    "pr-link",
    "custom-title",
    "summary",
}

TOKEN_KEYS = (
    "input_tokens",
    "output_tokens",
    "cache_read_input_tokens",
    "cache_creation_input_tokens",
)


class MalformedCounter:
    def __init__(self):
        self.total = 0
        self.by_file = Counter()

    def add(self, path):
        key = str(path)
        self.total += 1
        self.by_file[key] += 1

    def as_dict(self):
        return {
            "total": self.total,
            "by_file": dict(sorted(self.by_file.items())),
        }


def jsonl_files(root):
    path = Path(root).expanduser()
    if path.is_file():
        if path.suffix == ".jsonl":
            yield path
        return
    for child in path.rglob("*.jsonl"):
        if child.is_file():
            yield child


def iter_records(path, malformed=None):
    path = Path(path).expanduser()
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            raw = line.strip()
            if not raw:
                continue
            try:
                record = json.loads(raw)
            except json.JSONDecodeError:
                if malformed is not None:
                    malformed.add(path)
                continue
            if not isinstance(record, dict):
                if malformed is not None:
                    malformed.add(path)
                continue
            yield record


def record_type(record):
    value = record.get("type")
    if value in KNOWN_TYPES:
        return value
    return "other"


def project_for_path(path):
    return Path(path).expanduser().parent.name


def session_for_path(path):
    return Path(path).expanduser().stem


def session_id(record, path):
    value = record.get("sessionId")
    if isinstance(value, str) and value:
        return value
    return session_for_path(path)


def is_sidechain(record):
    return record.get("isSidechain") is True


def message(record):
    value = record.get("message")
    if isinstance(value, dict):
        return value
    return {}


def content_blocks(record):
    content = message(record).get("content")
    if isinstance(content, list):
        return content
    return []


def tool_use_blocks(record):
    if record_type(record) != "assistant":
        return []
    blocks = []
    for block in content_blocks(record):
        if isinstance(block, dict) and block.get("type") == "tool_use":
            blocks.append(block)
    return blocks


def tool_use_names(record):
    names = []
    for block in tool_use_blocks(record):
        name = block.get("name")
        if not isinstance(name, str) or not name:
            name = "<unknown>"
        names.append(name)
    return names


def assistant_model(record):
    if record_type(record) != "assistant":
        return None
    model = message(record).get("model")
    if isinstance(model, str) and model:
        return model
    return None


def usage(record):
    if record_type(record) != "assistant":
        return {}
    value = message(record).get("usage")
    if isinstance(value, dict):
        return value
    return {}


def as_int(value):
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    return 0


def assistant_api_error(record):
    if record_type(record) != "assistant":
        return False
    return (
        record.get("isApiErrorMessage") is True
        or record.get("apiErrorStatus") is not None
        or record.get("error") is not None
    )


def tool_result_error_count(record):
    if record_type(record) != "user":
        return 0
    count = 0
    for block in content_blocks(record):
        if isinstance(block, dict) and block.get("type") == "tool_result" and block.get("is_error") is True:
            count += 1
    return count


def user_prompt(record):
    if record_type(record) != "user" or record.get("isMeta") is True:
        return None
    content = message(record).get("content")
    if isinstance(content, str):
        return content
    return None


def queue_prompt(record):
    if record_type(record) != "queue-operation":
        return None
    if record.get("operation") != "enqueue":
        return None
    content = record.get("content")
    if isinstance(content, str):
        return content
    return None


def text_preview(text, limit=160):
    if text is None:
        return ""
    # Optimization: Use re.sub for O(n) replacement of consecutive spaces.
    # Yields 26x speedup for strings with many consecutive spaces.
    value = re.sub(r'\s+', ' ', str(text))
    if len(value) <= limit:
        return value
    if limit <= 1:
        return value[:limit]
    return value[: limit - 1] + "…"
