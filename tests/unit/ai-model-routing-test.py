"""Exercise mutable adapters through the shared semantic routing policy."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Protocol, cast

import yaml

Policy = dict[str, Any]


class RoutingModule(Protocol):
    def apply_policy(self, home: Path, policy: Policy) -> bool: ...

    def load_policy(self, path: Path) -> Policy: ...


def load_routing_module(source: Path) -> RoutingModule:
    spec = importlib.util.spec_from_file_location("ai_model_routing", source)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load routing module from {source}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return cast(RoutingModule, module)


def agent_fixture(description: str) -> str:
    return (
        "---\n"
        "model: user/old-model\n"
        "thinking: low\n"
        f"description: {description}\n"
        "---\n"
        f"{description} body\n"
    )


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: ai-model-routing-test.py ROUTING_SCRIPT POLICY_JSON")

    routing = load_routing_module(Path(sys.argv[1]))
    policy = routing.load_policy(Path(sys.argv[2]))

    with tempfile.TemporaryDirectory(prefix="ai-model-routing-test-") as temp:
        home = Path(temp)
        settings_path = home / ".pi/agent/settings.json"
        settings_path.parent.mkdir(parents=True)
        settings_path.write_text(
            json.dumps(
                {
                    "defaultProvider": "openai-codex",
                    "defaultModel": "user/old-model",
                    "defaultThinkingLevel": "low",
                    "modelProfiles": [],
                    "defaultTools": ["read", "bash", "edit", "write"],
                    "codemode": {"mode": "only", "inlineBudget": 1234},
                    "userSetting": "keep-me",
                }
            )
        )
        auth_path = settings_path.with_name("auth.json")
        auth_contents = '{"openai":{"type":"oauth","refresh":"preserve-this-token"}}\n'
        auth_path.write_text(auth_contents)

        agents_dir = home / ".pi/agent/agents"
        agents_dir.mkdir(parents=True)
        expected_agents = {
            "planner.md": ("gpt-6-astra", "xhigh"),
            "builder.md": ("gpt-6-astra", "high"),
            "reviewer.md": ("gpt-6-sol", "high"),
            "researcher.md": ("gpt-6-sol", "medium"),
            "context-builder.md": ("gpt-6-sol", "medium"),
            "scout.md": ("gpt-6-sol", "medium"),
        }
        for filename in expected_agents:
            (agents_dir / filename).write_text(agent_fixture(filename))

        omp_path = home / ".omp/agent/config.yml"
        omp_path.parent.mkdir(parents=True)
        original_omp = {
            "modelRoles": {"default": "google-antigravity/gemini-3.8-flash:high"},
            "task": {
                "maxConcurrency": 16,
                "agentModelOverrides": {"task": "@old"},
            },
            "enabledModels": ["google-antigravity/gemini-3.8-flash:high"],
            "retry": {"maxRetries": 99},
            "userSetting": "keep-me",
        }
        omp_path.write_text(yaml.safe_dump(original_omp, sort_keys=False))

        assert routing.apply_policy(home, policy)

        settings = json.loads(settings_path.read_text())
        assert settings["defaultProvider"] == "openai"
        assert settings["defaultModel"] == "gpt-6-astra"
        assert settings["defaultThinkingLevel"] == "high"
        assert settings["userSetting"] == "keep-me"
        assert settings["defaultTools"] == ["read", "bash", "edit", "write", "codemode"]
        assert settings["codemode"] == {"mode": "on", "inlineBudget": 1234}
        assert auth_path.read_text() == auth_contents
        assert {profile["model"] for profile in settings["modelProfiles"]} == {
            "openai/gpt-6-astra",
            "openai/gpt-6-sol",
            "openai/gpt-6-luna",
        }

        for filename, (model, effort) in expected_agents.items():
            text = (agents_dir / filename).read_text()
            assert f"model: openai/{model}" in text
            assert f"thinking: {effort}" in text
            assert f"{filename} body" in text

        omp = yaml.safe_load(omp_path.read_text())
        normal = policy["adapters"]["omp"]["normal"]
        assert omp["modelRoles"] == normal["modelRoles"]
        assert omp["enabledModels"] == normal["enabledModels"]
        assert "google-antigravity/*" in omp["enabledModels"]
        assert all(
            model == "google-antigravity/*"
            or model.startswith("openai-codex/gpt-6-")
            for model in omp["enabledModels"]
        )
        assert omp["retry"] == normal["retry"]
        assert (
            omp["task"]["agentModelOverrides"] == normal["task"]["agentModelOverrides"]
        )
        assert omp["task"]["maxConcurrency"] == 16
        assert omp["userSetting"] == "keep-me"
        backup = omp_path.with_name("config.yml.before-nix-routing")
        assert yaml.safe_load(backup.read_text()) == original_omp

        managed_paths = [
            settings_path,
            omp_path,
            *(agents_dir / name for name in expected_agents),
        ]
        first_run = {path: path.read_bytes() for path in managed_paths}
        assert not routing.apply_policy(home, policy)
        for path, contents in first_run.items():
            assert path.read_bytes() == contents, f"second run rewrote {path}"

        settings_path.unlink()
        assert routing.apply_policy(home, policy)
        fresh_settings = json.loads(settings_path.read_text())
        assert fresh_settings["defaultProvider"] == "openai"
        assert fresh_settings["defaultTools"] == settings["defaultTools"]
        assert fresh_settings["codemode"]["mode"] == "on"
        assert auth_path.read_text() == auth_contents
        assert not routing.apply_policy(home, policy)


if __name__ == "__main__":
    main()
