#!/usr/bin/env python3
"""Two-tier model-routing reconciler for codex / pi / omp + the Codex plugin.

Run on every Home Manager activation (see ai-model-routing.nix). Idempotent:
re-asserts ONLY the routing-relevant keys, leaving app-managed state
(timestamps, model caches, changelog versions) and unrelated user config
untouched. A file is only rewritten when a routing key actually differs.

Tiers
  DEEP  — gpt-5.5 @ xhigh (+ service_tier=fast)  — planning / demanding work
  SPARK — gpt-5.3-codex-spark @ medium           — everyday work; the default
          (low for the "smol" / recon roles)
"""

import json
import os
import sys
from pathlib import Path

import tomlkit
import yaml

# ── tiers ────────────────────────────────────────────────────────────────
SPARK = "gpt-5.3-codex-spark"
DEEP = "gpt-5.5"

HOME = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    os.environ.get("HOME", str(Path.home()))
)


def log(msg: str) -> None:
    print(f"[ai-model-routing] {msg}")


# ── codex CLI — ~/.codex/config.toml ─────────────────────────────────────
def reconcile_codex() -> bool:
    """Spark default + fast/fast-low/plan/deep profiles + PI_* env passthrough."""
    path = HOME / ".codex/config.toml"
    if not path.exists():
        log("codex: config.toml absent, skipping")
        return False

    doc = tomlkit.parse(path.read_text())
    before = tomlkit.dumps(doc)

    # Default tier → SPARK.
    doc["model"] = SPARK
    doc["model_reasoning_effort"] = "medium"

    # Named profiles (`codex --profile <name>`).
    if "profiles" not in doc:
        doc["profiles"] = tomlkit.table(is_super_table=True)
    profiles = doc["profiles"]

    def set_profile(name, model, effort, fast=False):
        if name not in profiles:
            profiles[name] = tomlkit.table()
        prof = profiles[name]
        prof["model"] = model
        prof["model_reasoning_effort"] = effort
        if fast:
            prof["service_tier"] = "fast"

    set_profile("fast", SPARK, "medium")
    set_profile("fast-low", SPARK, "low")
    set_profile("plan", DEEP, "xhigh", fast=True)
    set_profile("deep", DEEP, "xhigh", fast=True)

    # Env passthrough for pi/omp shells codex spawns (they read PI_*_MODEL).
    if "shell_environment_policy" not in doc:
        doc["shell_environment_policy"] = tomlkit.table()
    sep = doc["shell_environment_policy"]
    if "set" not in sep:
        sep["set"] = tomlkit.table()
    env = sep["set"]
    env["PI_PLAN_MODEL"] = f"openai-codex/{DEEP}:xhigh"
    env["PI_SLOW_MODEL"] = f"openai-codex/{DEEP}:xhigh"
    env["PI_SMOL_MODEL"] = f"openai-codex/{SPARK}:low"

    after = tomlkit.dumps(doc)
    if after != before:
        path.write_text(after)
        log("codex: config.toml routing keys updated")
        return True
    log("codex: config.toml already in sync")
    return False


# ── pi — ~/.pi/agent/settings.json ───────────────────────────────────────
def reconcile_pi_settings() -> bool:
    """Main-loop default → SPARK; refresh the Ctrl+P model profile list."""
    path = HOME / ".pi/agent/settings.json"
    if not path.exists():
        log("pi: settings.json absent, skipping")
        return False

    data = json.loads(path.read_text())
    before = json.dumps(data, indent=2, ensure_ascii=False)

    data["defaultModel"] = SPARK
    data["defaultThinkingLevel"] = "medium"
    data["modelProfiles"] = [
        {"model": f"openai-codex/{SPARK}", "thinking": "low",
         "label": "Codex Spark Low"},
        {"model": f"openai-codex/{SPARK}", "thinking": "medium",
         "label": "Codex Spark Medium"},
        {"model": f"openai-codex/{DEEP}", "thinking": "xhigh",
         "label": "GPT-5.5 Deep"},
        {"model": "openai-codex/gpt-5.4", "thinking": "xhigh",
         "label": "GPT-5.4 Long Context"},
    ]

    after = json.dumps(data, indent=2, ensure_ascii=False)
    if after != before:
        path.write_text(after + "\n")
        log("pi: settings.json routing keys updated")
        return True
    log("pi: settings.json already in sync")
    return False


# ── pi — ~/.pi/agent/agents/*.md subagent frontmatter ────────────────────
# DEEP for planning / review / general delegated work; SPARK for recon,
# context-prep and research-gathering.
PI_AGENT_TIERS = {
    "planner.md": (f"openai-codex/{DEEP}", "xhigh"),
    "builder.md": (f"openai-codex/{DEEP}", "xhigh"),
    "reviewer.md": (f"openai-codex/{DEEP}", "xhigh"),
    "researcher.md": (f"openai-codex/{SPARK}", "medium"),
    "context-builder.md": (f"openai-codex/{SPARK}", "medium"),
    "scout.md": (f"openai-codex/{SPARK}", "low"),
}


def _patch_frontmatter(text, model, thinking):
    """Set `model:`/`thinking:` in the YAML frontmatter; body untouched."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None
    end = next((i for i in range(1, len(lines))
                if lines[i].strip() == "---"), None)
    if end is None:
        return None

    out, seen_model = [], False
    for ln in lines[1:end]:
        if ln.startswith("model:"):
            out.append(f"model: {model}")
            out.append(f"thinking: {thinking}")
            seen_model = True
        elif ln.startswith("thinking:"):
            continue  # re-emitted right after `model:`
        else:
            out.append(ln)
    if not seen_model:
        out = [f"model: {model}", f"thinking: {thinking}"] + out
    return "\n".join([lines[0]] + out + lines[end:])


def reconcile_pi_agents() -> bool:
    agents = HOME / ".pi/agent/agents"
    if not agents.is_dir():
        log("pi: agents/ absent, skipping")
        return False

    changed = False
    for fname, (model, thinking) in PI_AGENT_TIERS.items():
        path = agents / fname
        if not path.exists():
            continue
        orig = path.read_text()
        patched = _patch_frontmatter(orig, model, thinking)
        if patched is None:
            log(f"pi: {fname} has no frontmatter, skipping")
            continue
        if patched != orig:
            path.write_text(patched)
            log(f"pi: {fname} → {model} ({thinking})")
            changed = True
    if not changed:
        log("pi: agents already in sync")
    return changed


# ── omp — ~/.omp/agent/config.yml ────────────────────────────────────────
def reconcile_omp() -> bool:
    """Assert modelRoles + task.agentModelOverrides; leave the rest alone."""
    path = HOME / ".omp/agent/config.yml"
    if not path.exists():
        log("omp: config.yml absent, skipping")
        return False

    data = yaml.safe_load(path.read_text()) or {}
    dump = dict(sort_keys=False, default_flow_style=False, allow_unicode=True)
    before = yaml.dump(data, **dump)

    roles = data.setdefault("modelRoles", {})
    roles["default"] = f"openai-codex/{SPARK}:medium"
    roles["smol"] = f"openai-codex/{SPARK}:low"
    roles["commit"] = f"openai-codex/{SPARK}:medium"
    roles["task"] = f"openai-codex/{DEEP}:xhigh"
    roles["plan"] = f"openai-codex/{DEEP}:xhigh"
    roles["slow"] = f"openai-codex/{DEEP}:xhigh"
    roles["designer"] = f"openai-codex/{DEEP}:xhigh"

    overrides = data.setdefault("task", {}).setdefault("agentModelOverrides", {})
    overrides["quick_task"] = "pi/smol"
    overrides["explore"] = "pi/smol"
    overrides["librarian"] = "pi/smol"
    overrides["task"] = "pi/task"
    overrides["plan"] = "pi/plan"
    overrides["reviewer"] = "pi/slow"
    overrides["designer"] = "pi/designer"

    after = yaml.dump(data, **dump)
    if after != before:
        path.write_text(after)
        log("omp: config.yml routing keys updated")
        return True
    log("omp: config.yml already in sync")
    return False


# ── Codex plugin — codex-rescue agent + codex-cli-runtime skill ──────────
EFFORT_ANCHORS = [
    "- Leave `--effort` unset unless the user explicitly requests a specific "
    "reasoning effort.",
    "- Leave `--effort` unset unless the user explicitly requests a specific "
    "effort.",
]
MODEL_ANCHORS = [
    "- Leave model unset by default. Only add `--model` when the user "
    "explicitly asks for a specific model.",
    "- Leave model unset by default. Add `--model` only when the user "
    "explicitly asks for one.",
]
EFFORT_ROUTED = (
    "- Default to `--effort medium`. Escalate to `--effort xhigh` when the "
    "task involves planning, architecture, multi-step debugging, or is "
    "otherwise demanding / capacity-intensive."
)
MODEL_ROUTED = (
    "- Default to `--model gpt-5.3-codex-spark` (the fast Spark tier). "
    "Escalate to `--model gpt-5.5` for demanding / capacity-intensive work. "
    "Honor an explicit user model request."
)


def _patch_plugin_file(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text()
    if "capacity-intensive" in text:
        return False  # already routed
    patched = text
    for anchor in EFFORT_ANCHORS:
        patched = patched.replace(anchor, EFFORT_ROUTED)
    for anchor in MODEL_ANCHORS:
        patched = patched.replace(anchor, MODEL_ROUTED)
    if patched != text:
        path.write_text(patched)
        log(f"codex-plugin: routed {path}")
        return True
    log(f"codex-plugin: no anchor lines in {path.name} (upstream reworded?)")
    return False


def reconcile_codex_plugin() -> bool:
    """Make the Claude Code `codex` plugin auto-route spark vs deep.

    Only the active *cache* install is patched — the marketplace git clone is
    left pristine so plugin updates don't hit a dirty worktree. A refreshed
    cache simply gets re-patched on the next activation.
    """
    cache = HOME / ".claude/plugins/cache/openai-codex/codex"
    if not cache.is_dir():
        log("codex-plugin: not installed, skipping")
        return False

    targets = []
    for vdir in sorted(p for p in cache.iterdir() if p.is_dir()):
        targets.append(vdir / "agents/codex-rescue.md")
        targets.append(vdir / "skills/codex-cli-runtime/SKILL.md")

    found = [t for t in targets if t.exists()]
    if not found:
        log("codex-plugin: not installed, skipping")
        return False

    # List comprehension, not a generator — `any()` must not short-circuit
    # or only the first file of each run gets patched.
    results = [_patch_plugin_file(t) for t in found]
    if not any(results):
        log("codex-plugin: already in sync")
    return any(results)


def main() -> None:
    reconcilers = (
        reconcile_codex,
        reconcile_pi_settings,
        reconcile_pi_agents,
        reconcile_omp,
        reconcile_codex_plugin,
    )
    changed = False
    for fn in reconcilers:
        try:
            changed |= bool(fn())
        except Exception as exc:  # never break activation over routing config
            log(f"WARN {fn.__name__}: {exc}")
    log("done — changes applied" if changed else "done — already in sync")


if __name__ == "__main__":
    main()
