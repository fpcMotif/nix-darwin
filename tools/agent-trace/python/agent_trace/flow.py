from .parse import (
    MalformedCounter,
    assistant_api_error,
    assistant_model,
    iter_records,
    queue_prompt,
    record_type,
    text_preview,
    tool_result_error_count,
    tool_use_names,
    user_prompt,
    is_sidechain,
)


def _record_uuid(record, index, nodes):
    value = record.get("uuid")
    if not isinstance(value, str) or not value:
        value = "<record:" + str(index) + ">"
    base = value
    suffix = 2
    while value in nodes:
        value = base + "#" + str(suffix)
        suffix += 1
    return value


def _record_parent(record):
    value = record.get("parentUuid")
    if isinstance(value, str) and value:
        return value
    return None


def _label(record):
    typ = record_type(record)
    parts = [typ]
    timestamp = record.get("timestamp")
    if isinstance(timestamp, str) and timestamp:
        parts.append(timestamp)
    if is_sidechain(record):
        parts.append("[sidechain]")

    if typ == "assistant":
        model = assistant_model(record)
        if model is not None:
            parts.append("model=" + model)
        names = tool_use_names(record)
        if names:
            parts.append("tools=" + ",".join(names))
        if assistant_api_error(record):
            parts.append("[API_ERROR]")
    elif typ == "user":
        prompt = user_prompt(record)
        if prompt is not None:
            parts.append("prompt=\"" + text_preview(prompt, 90) + "\"")
        errors = tool_result_error_count(record)
        if errors:
            parts.append("tool_result_errors=" + str(errors))
            parts.append("[ERROR]")
    elif typ == "queue-operation":
        operation = record.get("operation")
        if isinstance(operation, str) and operation:
            parts.append(operation)
        prompt = queue_prompt(record)
        if prompt is not None:
            parts.append("content=\"" + text_preview(prompt, 90) + "\"")
    elif typ == "summary":
        summary = record.get("summary")
        if isinstance(summary, str) and summary:
            parts.append("summary=\"" + text_preview(summary, 90) + "\"")
    elif typ == "system":
        content = record.get("content")
        if isinstance(content, str) and content:
            parts.append("content=\"" + text_preview(content, 90) + "\"")

    return " ".join(parts)


def render(path):
    malformed = MalformedCounter()
    nodes = {}
    order = []
    index = 0

    for record in iter_records(path, malformed):
        index += 1
        uuid = _record_uuid(record, index, nodes)
        nodes[uuid] = {
            "uuid": uuid,
            "parent": _record_parent(record),
            "label": _label(record),
            "children": [],
        }
        order.append(uuid)

    roots = []
    for uuid in order:
        parent = nodes[uuid]["parent"]
        if parent in nodes:
            nodes[parent]["children"].append(uuid)
        else:
            roots.append(uuid)

    lines = []
    if malformed.total:
        lines.append("malformed skipped: " + str(malformed.total))
    if not roots and not nodes:
        lines.append("(no records)")
        return {"file": str(path), "malformed": malformed.as_dict(), "lines": lines}

    stack = []
    for uuid in reversed(roots):
        stack.append((uuid, 0))
    seen = set()
    while stack:
        uuid, depth = stack.pop()
        if uuid in seen:
            lines.append("  " * depth + uuid + " [cycle]")
            continue
        seen.add(uuid)
        lines.append("  " * depth + uuid + " " + nodes[uuid]["label"])
        children = nodes[uuid]["children"]
        for child in reversed(children):
            stack.append((child, depth + 1))

    return {"file": str(path), "malformed": malformed.as_dict(), "lines": lines}


def format_table(data):
    return "\n".join(data["lines"])
