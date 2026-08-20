#!/usr/bin/env python3
"""Two-tier model-routing reconciler for codex / pi / omp + the Codex plugin.

Run on every Home Manager activation (see ai-model-routing.nix). Idempotent:
re-asserts ONLY the routing-relevant keys, leaving app-managed state
(timestamps, model caches, changelog versions) and unrelated user config
untouched. A file is only rewritten when a routing key actually differs.

Tiers (codex CLI + pi)
  DEEP  — gpt-5.5 @ xhigh (+ service_tier=fast)  — planning / demanding work
  SPARK — gpt-5.3-codex-spark @ medium           — everyday work; the default
          (low for the "smol" / recon roles)

omp instead runs the gpt-5.6 codename pair + an off-sub advisor — see
reconcile_omp().
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
KIMI_K3 = "kimi-code/k3:max"

# gpt-5.6 codename pair — omp only, both on the ChatGPT sub via openai-codex.
# `max` is the ceiling: the catalog exposes low/medium/high/xhigh/max, there
# is no `ultra`. Verify with `omp models openai-codex` before raising these.
# As of 2026-08-15 `omp models openai-codex` (post-refresh) lists only
# gpt-5.4-mini / gpt-5.5 / luna / terra — gpt-5.6-sol, gpt-5.3-codex-spark and
# gpt-5.4 dropped off, likely gated by that account's free plan.
# They are NOT gone globally: the Cursor provider still carries the whole
# gpt-5.6 family (`cursor/gpt-5.6-sol-medium`, `-terra-*`, `-luna-*`) plus
# 5.1–5.5 and the codex variants. Cursor is the route to sol while the codex
# sub lacks it. Reasoning is baked into cursor slugs — no `:effort` suffix.
LUNA = "openai-codex/gpt-5.6-luna"
TERRA = "openai-codex/gpt-5.6-terra"

# ── omp role routing ─────────────────────────────────────────────────────
# 2026-08-15: openai-codex is 100% spent with ~26d to reset, so NO omp role
# rides it right now. Load is spread across the three healthy subs by what
# each one is cheap at — check `omp usage` before rebalancing:
#
#   Antigravity — Google bucket was 0% used and resets DAILY. Best home for
#     the high-volume roles (recon + main loop). Its Claude route is the
#     250K-context opus-4-6.
#   Kimi — separate sub, its own ceiling, k3 is 1M-context with a real `max`
#     thinking tier. Carries the delegated + demanding work.
#   Cursor — two buckets: "Cursor Models" (generous) and "Other Models",
#     a hard $20/mo cap that Claude/Gemini slugs bill against. Reserved for
#     the advisory/review/design roles; deliberately NOT the main loop, which
#     would drain $20 fast. Cursor bakes reasoning into the slug, so these
#     take no `:effort` suffix.
# Antigravity's gemini-3.7-flash rejects thinking level MINIMAL with a 400
# ("not supported for this model") even though the catalog advertises it.
# Verified 2026-08-15: :minimal 400s, :low/:medium/:high all return OK.
# So these roles are pinned at :high — never at the low end where the request
# can resolve to MINIMAL. Do not lower these without retesting.
OMP_SMOL = "google-antigravity/gemini-3.7-flash:high"
OMP_COMMIT = "google-antigravity/gemini-3.7-flash:high"
OMP_DEFAULT = "google-antigravity/claude-opus-4-6:high"
OMP_PLAN = "google-antigravity/claude-opus-4-6:high"
# grok 4.6 tops out at `xhigh` — there is no `max` on this line, unlike the
# claude/gpt slugs. Note reviewer and task are the same family by request, so
# the review is not an independent-family check on the builder's output.
OMP_TASK = "cursor/cursor-grok-4.6-high"
OMP_SLOW = KIMI_K3
OMP_DESIGNER = "google-antigravity/gemini-3.7-flash:high"
OMP_REVIEWER = "cursor/cursor-grok-4.6-xhigh"

# Advisor rides the same Antigravity opus as the main loop by request. Note
# this is deliberately NOT an independent-family second opinion — it will
# share the main loop's blind spots. It was on cursor/gpt-5.6-sol-medium,
# which kept tripping the advisor's first-event timeout.
ADVISOR = "google-antigravity/claude-opus-4-6:high"

# Absent from the openai-codex catalog — pruned from enabledModels on every
# run so they stop showing up in Ctrl+P and 400-ing on selection.
OMP_RETIRED = [
    "openai-codex/gpt-5.6-sol:max",
    "openai-codex/gpt-5.6-sol:medium",
    "openai-codex/gpt-5.3-codex-spark:medium",
    "openai-codex/gpt-5.3-codex-spark:low",
    "openai-codex/gpt-5.4:xhigh",
]

# Kept selectable in omp's Ctrl+P picker without owning the whole list.
# 2026-08-15 `omp usage`: Cursor is healthy again (18.5% monthly), while
# openai-codex is 100% spent on a free plan until it resets. Google
# Antigravity sub is authenticated and has quota — added as another free
# fallback route (also proxies Claude Opus, not just Gemini). Cursor's
# catalog got gemini-3.7-flash first; Antigravity caught up in omp 17.3.2
# (its route is the 1M-context one, vs cursor's 200K), so both are listed.
OMP_PICKER = [
    f"{TERRA}:max",
    f"{TERRA}:medium",
    f"{LUNA}:max",
    ADVISOR,
    OMP_REVIEWER,
    OMP_DESIGNER,
    OMP_TASK,
    KIMI_K3,
    "cursor/gpt-5.6-sol-xhigh",
    "cursor/claude-opus-4-8-xhigh",
    "cursor/claude-sonnet-5-high",
    "kimi-code/k3:high",
    "cursor/composer-2.5",
    "cursor/gemini-3.7-flash-high",
    "google-antigravity/claude-opus-4-6:high",
    "google-antigravity/gemini-3.6-flash:high",
    "google-antigravity/gemini-3.7-flash:high",
]

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
    """Assert modelRoles + task.agentModelOverrides; leave the rest alone.

    omp does not use the SPARK/DEEP two-tier split the other agents run on.
    Because openai-codex is quota-dead (see the OMP_* block), every role is
    pinned to a specific model on a healthy sub instead of a shared tier —
    Antigravity for the high-volume roles, Kimi for delegated/demanding work,
    Cursor for the advisory/review roles.
    """
    path = HOME / ".omp/agent/config.yml"
    if not path.exists():
        log("omp: config.yml absent, skipping")
        return False

    data = yaml.safe_load(path.read_text()) or {}
    dump = dict(sort_keys=False, default_flow_style=False, allow_unicode=True)
    before = yaml.dump(data, **dump)

    roles = data.setdefault("modelRoles", {})
    roles["default"] = OMP_DEFAULT
    roles["task"] = OMP_TASK
    roles["advisor"] = ADVISOR
    roles["plan"] = OMP_PLAN
    roles["designer"] = OMP_DESIGNER
    roles["reviewer"] = OMP_REVIEWER
    roles["smol"] = OMP_SMOL
    roles["commit"] = OMP_COMMIT
    roles["slow"] = OMP_SLOW

    # Append-only for the picker, so hand-added models survive — but retired
    # models get dropped, since leaving them listed just invites a 400.
    enabled = data.setdefault("enabledModels", [])
    for model in OMP_RETIRED:
        if model in enabled:
            enabled.remove(model)
            log(f"omp: dropped retired model {model}")
    for model in OMP_PICKER:
        if model not in enabled:
            enabled.append(model)

    overrides = data.setdefault("task", {}).setdefault("agentModelOverrides", {})
    overrides["quick_task"] = "pi/smol"
    overrides["explore"] = "pi/smol"
    overrides["librarian"] = "pi/smol"
    overrides["task"] = "pi/task"
    overrides["plan"] = "pi/plan"
    overrides["reviewer"] = "pi/reviewer"
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
