"""Apply mutable adapters for the shared semantic model-routing policy."""

from __future__ import annotations

import copy
import json
import shutil
import sys
from pathlib import Path
from typing import Any

import yaml

Policy = dict[str, Any]


def log(message: str) -> None:
    print(f"[ai-model-routing] {message}")


def load_policy(path: Path) -> Policy:
    policy = json.loads(path.read_text())
    if policy.get("schemaVersion") != 1:
        raise ValueError("unsupported model-routing policy schema")
    return policy


def resolve(policy: Policy, job: str) -> tuple[str, str]:
    assignment = policy["jobs"][job]
    model = policy["models"][assignment["model"]]
    return f"{model['provider']}/{model['id']}", assignment["effort"]


def reconcile_pi_settings(home: Path, policy: Policy) -> bool:
    path = home / ".pi/agent/settings.json"
    if not path.exists():
        log("pi: settings.json absent, skipping")
        return False

    data = json.loads(path.read_text())
    before = json.dumps(data, indent=2, ensure_ascii=False)
    adapter = policy["adapters"]["pi"]
    default_assignment = policy["jobs"][adapter["defaultJob"]]
    default_model = policy["models"][default_assignment["model"]]
    data["defaultProvider"] = default_model["provider"]
    data["defaultModel"] = default_model["id"]
    data["defaultThinkingLevel"] = default_assignment["effort"]
    data["modelProfiles"] = [
        {
            "model": model,
            "thinking": effort,
            "label": f"{job.title()} · {model.rsplit('/', 1)[-1]}",
        }
        for job in adapter["profiles"]
        for model, effort in [resolve(policy, job)]
    ]

    after = json.dumps(data, indent=2, ensure_ascii=False)
    if after == before:
        log("pi: settings already in sync")
        return False
    path.write_text(after + "\n")
    log("pi: settings updated")
    return True


def patch_frontmatter(text: str, model: str, thinking: str) -> str | None:
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None
    end = next(
        (
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == "---"
        ),
        None,
    )
    if end is None:
        return None

    body: list[str] = []
    saw_model = False
    for line in lines[1:end]:
        if line.startswith("model:"):
            body.extend((f"model: {model}", f"thinking: {thinking}"))
            saw_model = True
        elif not line.startswith("thinking:"):
            body.append(line)
    if not saw_model:
        body[:0] = [f"model: {model}", f"thinking: {thinking}"]
    return "\n".join([lines[0], *body, *lines[end:]])


def reconcile_pi_agents(home: Path, policy: Policy) -> bool:
    directory = home / ".pi/agent/agents"
    if not directory.is_dir():
        log("pi: agents absent, skipping")
        return False

    changed = False
    for filename, job in policy["adapters"]["pi"]["agents"].items():
        path = directory / filename
        if not path.exists():
            continue
        model, thinking = resolve(policy, job)
        original = path.read_text()
        patched = patch_frontmatter(original, model, thinking)
        if patched is None:
            log(f"pi: {filename} has no frontmatter, skipping")
        elif patched != original:
            path.write_text(patched)
            log(f"pi: {filename} -> {job}")
            changed = True
    if not changed:
        log("pi: agents already in sync")
    return changed


def reconcile_omp_config(home: Path, policy: Policy) -> bool:
    path = home / ".omp/agent/config.yml"
    original = path.read_text() if path.exists() else ""
    loaded = yaml.safe_load(original) if original else {}
    if not isinstance(loaded, dict):
        raise TypeError("omp: config.yml must contain a YAML mapping")

    data: dict[str, Any] = loaded
    normal = policy["adapters"]["omp"]["normal"]
    data["modelRoles"] = copy.deepcopy(normal["modelRoles"])
    data["enabledModels"] = copy.deepcopy(normal["enabledModels"])
    data["retry"] = copy.deepcopy(normal["retry"])

    task = data.setdefault("task", {})
    if not isinstance(task, dict):
        raise TypeError("omp: task must contain a YAML mapping")
    task["agentModelOverrides"] = copy.deepcopy(normal["task"]["agentModelOverrides"])

    updated = yaml.safe_dump(data, sort_keys=False, allow_unicode=True)
    if updated == original:
        log("omp: config.yml already in sync")
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    backup = path.with_name(f"{path.name}.before-nix-routing")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    path.write_text(updated)
    path.chmod(0o600)
    log("omp: config.yml updated")
    return True


def apply_policy(home: Path, policy: Policy) -> bool:
    return (
        reconcile_pi_settings(home, policy)
        | reconcile_pi_agents(home, policy)
        | reconcile_omp_config(home, policy)
    )


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: ai-model-routing.py POLICY_JSON HOME")
    policy = load_policy(Path(sys.argv[1]))
    apply_policy(Path(sys.argv[2]), policy)


if __name__ == "__main__":
    main()
