{ config, ... }:

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # Trust my own project roots so `cd` never re-prompts with
    # "direnv: error .envrc is blocked. Run 'direnv allow'": that prompt fires
    # on every `.envrc`/flake.lock churn (auto-update commits, switches, merges)
    # and is the recurring "direnv seems broken" symptom. Scoped to dirs I own —
    # deliberately NOT ~/Downloads, where an untrusted repo's .envrc could land.
    config.whitelist.prefix = [
      "${config.home.homeDirectory}/nix-config"
      "${config.home.homeDirectory}/devv"
      "${config.home.homeDirectory}/Burrow"
      "${config.home.homeDirectory}/ghostty"
    ];
    # Drop direnv's noisy `export +VAR … ~VAR` diff on every `cd`/reload — nix
    # dev shells export ~50 vars and the dump dominates the terminal. `log_filter`
    # is an allowlist (only messages matching the regexp are printed), so this
    # keeps the useful `loading`/`using flake`/`nix-direnv` status lines and hides
    # the export diff. Errors bypass the filter, so a blocked/failing .envrc still
    # surfaces.
    config.global.log_filter = "^(loading|using|nix-direnv)";
  };
}
