from collections import Counter, defaultdict

from .parse import (
    MalformedCounter,
    TOKEN_KEYS,
    as_int,
    assistant_api_error,
    assistant_model,
    iter_records,
    jsonl_files,
    project_for_path,
    record_type,
    tool_result_error_count,
    tool_use_names,
    usage,
)


def _project_entry():
    return {
        "sessions": set(),
        "records": 0,
        "records_by_type": Counter(),
        "tool_uses": Counter(),
        "models": Counter(),
        "tokens": Counter(),
        "api_errors": 0,
        "tool_result_errors": 0,
        "malformed": 0,
    }


def aggregate(root):
    malformed = MalformedCounter()
    projects = defaultdict(_project_entry)
    totals = {
        "root": str(root),
        "sessions": set(),
        "records": 0,
        "records_by_type": Counter(),
        "tool_uses": Counter(),
        "models": Counter(),
        "tokens": Counter(),
        "api_errors": 0,
        "tool_result_errors": 0,
        "malformed": malformed,
        "projects": projects,
    }

    for path in jsonl_files(root):
        project = project_for_path(path)
        entry = projects[project]
        before_bad = malformed.total

        for record in iter_records(path, malformed):
            session_id = record.get("sessionId")
            if session_id:
                totals["sessions"].add(session_id)
                entry["sessions"].add(session_id)
            typ = record_type(record)
            totals["records"] += 1
            totals["records_by_type"][typ] += 1
            entry["records"] += 1
            entry["records_by_type"][typ] += 1

            model = assistant_model(record)
            if model is not None:
                totals["models"][model] += 1
                entry["models"][model] += 1

            for name in tool_use_names(record):
                totals["tool_uses"][name] += 1
                entry["tool_uses"][name] += 1

            use = usage(record)
            for key in TOKEN_KEYS:
                value = as_int(use.get(key))
                totals["tokens"][key] += value
                entry["tokens"][key] += value

            if assistant_api_error(record):
                totals["api_errors"] += 1
                entry["api_errors"] += 1

            result_errors = tool_result_error_count(record)
            if result_errors:
                totals["tool_result_errors"] += result_errors
                entry["tool_result_errors"] += result_errors

        bad = malformed.total - before_bad
        entry["malformed"] += bad

    return totals


def _counter_dict(counter):
    return {key: counter[key] for key in sorted(counter, key=lambda name: (-counter[name], name))}


def to_jsonable(data):
    projects = {}
    for name in sorted(data["projects"]):
        entry = data["projects"][name]
        projects[name] = {
            "sessions": len(entry["sessions"]),
            "records": entry["records"],
            "records_by_type": _counter_dict(entry["records_by_type"]),
            "tool_uses": _counter_dict(entry["tool_uses"]),
            "models": _counter_dict(entry["models"]),
            "tokens": {key: entry["tokens"][key] for key in TOKEN_KEYS},
            "api_errors": entry["api_errors"],
            "tool_result_errors": entry["tool_result_errors"],
            "malformed": entry["malformed"],
        }
    return {
        "root": data["root"],
        "sessions": len(data["sessions"]),
        "records": data["records"],
        "records_by_type": _counter_dict(data["records_by_type"]),
        "tool_uses": _counter_dict(data["tool_uses"]),
        "models": _counter_dict(data["models"]),
        "tokens": {key: data["tokens"][key] for key in TOKEN_KEYS},
        "api_errors": data["api_errors"],
        "tool_result_errors": data["tool_result_errors"],
        "malformed": data["malformed"].as_dict(),
        "projects": projects,
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
    result = to_jsonable(data)
    lines = [
        "agent-trace stats",
        "root: " + result["root"],
        "sessions: " + str(result["sessions"]),
        "records: " + str(result["records"]),
        "malformed: " + str(result["malformed"]["total"]),
        "api_errors: " + str(result["api_errors"]),
        "tool_result_errors: " + str(result["tool_result_errors"]),
        "",
        "tokens",
    ]
    token_rows = [(key, result["tokens"].get(key, 0)) for key in TOKEN_KEYS]
    lines.extend(_format_rows(("kind", "total"), token_rows))

    lines.append("")
    lines.append("records by type")
    lines.extend(_format_rows(("type", "count"), result["records_by_type"].items()))

    lines.append("")
    lines.append("tool_use histogram")
    tool_rows = list(result["tool_uses"].items())
    if tool_rows:
        lines.extend(_format_rows(("tool", "count"), tool_rows))
    else:
        lines.append("(none)")

    lines.append("")
    lines.append("models")
    model_rows = list(result["models"].items())
    if model_rows:
        lines.extend(_format_rows(("model", "count"), model_rows))
    else:
        lines.append("(none)")

    lines.append("")
    lines.append("per project")
    project_rows = []
    for project, entry in result["projects"].items():
        project_rows.append(
            (
                project,
                entry["sessions"],
                entry["records"],
                sum(entry["tool_uses"].values()),
                entry["tokens"].get("input_tokens", 0),
                entry["tokens"].get("output_tokens", 0),
                entry["tokens"].get("cache_read_input_tokens", 0),
                entry["tokens"].get("cache_creation_input_tokens", 0),
                entry["api_errors"],
                entry["tool_result_errors"],
                entry["malformed"],
            )
        )
    project_rows.sort(key=lambda row: (-int(row[2]), str(row[0])))
    if project_rows:
        lines.extend(
            _format_rows(
                (
                    "project",
                    "sessions",
                    "records",
                    "tool_uses",
                    "input",
                    "output",
                    "cache_read",
                    "cache_creation",
                    "api_errors",
                    "tool_errors",
                    "malformed",
                ),
                project_rows,
            )
        )
    else:
        lines.append("(none)")
    return "\n".join(lines)
