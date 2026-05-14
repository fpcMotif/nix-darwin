{ pkgs, lib, config, ... }:

# Two-tier automatic model routing for the OpenAI-Codex-backed coding agents
# — codex CLI, pi, omp — and the Claude Code `codex` plugin.
#
#   DEEP  — gpt-5.5 @ xhigh (+ service_tier=fast)  — planning / demanding,
#           model-capacity-intensive work
#   SPARK — gpt-5.3-codex-spark @ medium           — everyday work; the default
#           (low for the "smol" / recon roles)
#
# codex/pi/omp each rewrite their own config files at runtime (model caches,
# changelog versions, in-session model switches), so Home Manager can't own
# them as read-only store symlinks — a symlink would just fight the app.
# Instead, every activation runs an idempotent Python reconciler that
# re-asserts ONLY the routing-relevant keys and leaves app-managed state and
# unrelated user config untouched. See ./ai-model-routing.py for the exact
# keys owned per file; a file is only rewritten when a routing key differs.
#
# Consequence: those routing keys are Nix-owned. Change tiers in
# ./ai-model-routing.py, not in the live config files — a rebuild reverts
# live edits to the specific keys the reconciler manages.
#
# Manual run (e.g. to re-assert after codex flips its in-session model):
#   nix run nixpkgs#python3.withPackages \
#     --impure --expr '...' -- ai-model-routing.py "$HOME"
# or just `darwin-rebuild switch`.

let
  pyEnv = pkgs.python3.withPackages (ps: with ps; [ tomlkit pyyaml ]);
in
{
  home.activation.aiModelRouting = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pyEnv}/bin/python3 ${./ai-model-routing.py} ${config.home.homeDirectory}
  '';
}
