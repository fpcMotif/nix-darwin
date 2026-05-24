{ config, inputs, lib, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.spotlight;
  hmDag = inputs.home-manager.lib.hm.dag;
  markerText = "managed by nix-config martin.spotlight";
in
{
  options.martin.spotlight = {
    enable = lib.mkEnableOption "Spotlight churn controls for development trees";

    excludedPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${currentSystemUserHome}/.bun"
        "${currentSystemUserHome}/.cache"
        "${currentSystemUserHome}/.cargo"
        "${currentSystemUserHome}/.codex"
        "${currentSystemUserHome}/.rustup"
        "${currentSystemUserHome}/cleanmole-expo"
        "${currentSystemUserHome}/gosh-my-pi"
        "${currentSystemUserHome}/ghostty"
        "${currentSystemUserHome}/kwwk"
        "${currentSystemUserHome}/Mole"
        "${currentSystemUserHome}/nix-config"
        "${currentSystemUserHome}/pi"
        "${currentSystemUserHome}/pi-gui"
      ];
      description = ''
        Development/cache directories that should not feed Spotlight's content index.
        Code search is handled by rg, ast-grep, fff/codedb, and mgrep instead.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${currentSystemUser}.programs.git.ignores = [
        ".metadata_never_index"
      ];
    })

    {
      home-manager.users.${currentSystemUser}.home.activation.spotlightExclusions =
        hmDag.entryAfter [ "writeBoundary" ] ''
          state_dir="${currentSystemUserHome}/Library/Application Support/nix-config"
          state_file="$state_dir/spotlight-exclusions"

          if ${if cfg.enable then "true" else "false"} || [ -f "$state_file" ]; then
            run mkdir -p "$state_dir"
            new_state="$(mktemp "$state_dir/.spotlight-exclusions.XXXXXX")"
            : > "$new_state"

            ${lib.optionalString cfg.enable ''
              for path in ${lib.escapeShellArgs cfg.excludedPaths}; do
                if [ -d "$path" ]; then
                  marker="$path/.metadata_never_index"

                  if [ -f "$marker" ] && grep -qx ${lib.escapeShellArg markerText} "$marker"; then
                    printf '%s\n' "$path" >> "$new_state"
                  elif [ ! -e "$marker" ]; then
                    printf '%s\n' ${lib.escapeShellArg markerText} > "$marker"
                    chmod 0644 "$marker" 2>/dev/null || true
                    printf '%s\n' "$path" >> "$new_state"
                  fi
                fi
              done
            ''}

            if [ -f "$state_file" ]; then
              while IFS= read -r old_path; do
                marker="$old_path/.metadata_never_index"
                if [ -n "$old_path" ] \
                  && ! grep -Fxq "$old_path" "$new_state" \
                  && [ -f "$marker" ] \
                  && grep -qx ${lib.escapeShellArg markerText} "$marker"; then
                  rm -f "$marker"
                fi
              done < "$state_file"
            fi

            if [ -s "$new_state" ]; then
              mv "$new_state" "$state_file"
              chmod 0644 "$state_file" 2>/dev/null || true
            else
              rm -f "$state_file" "$new_state"
            fi
          fi
        '';
    }
  ];
}
