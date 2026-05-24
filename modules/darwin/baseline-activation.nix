{ config, inputs, lib, currentSystemUser, ... }:

let
  cfg = config.martin.darwinBaseline.activationState;
  hmDag = inputs.home-manager.lib.hm.dag;

  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    escapeShellArgs
    listToAttrs
    mkOption
    optionalString
    types;

  domainType = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum [ "system" "gui" ];
        description = "launchd domain kind for Darwin baseline activation state.";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User whose GUI launchd domain should be targeted when kind = gui.";
      };
    };
  };

  launchdDisabledDomainType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Stable name for this launchd suppression entry.";
      };

      domain = mkOption {
        type = domainType;
        description = "launchd domain whose labels should be suppressed.";
      };

      labels = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "launchd labels to disable and boot out.";
      };

      reason = mkOption {
        type = types.str;
        default = "Darwin baseline activation state";
        description = "Domain reason for suppressing these launchd labels.";
      };

      bootout = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to boot out the job after disabling it.";
      };
    };
  };

  pathMarkerType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Home Manager activation key for this path-marker reconciliation.";
      };

      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the marker paths are desired; stale managed markers are still cleaned when false.";
      };

      stateFile = mkOption {
        type = types.str;
        description = "Line-oriented state file tracking paths whose markers were created by Nix.";
      };

      paths = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Existing directories that should receive the managed marker.";
      };

      markerName = mkOption {
        type = types.str;
        default = ".metadata_never_index";
        description = "Marker file basename to create inside each path.";
      };

      markerText = mkOption {
        type = types.str;
        description = "Single-line text proving a marker is managed by this module.";
      };
    };
  };

  renderLaunchdEntry = entry:
    let
      labels = escapeShellArgs entry.labels;
      bootoutFlag = if entry.bootout then "1" else "0";
      callDisable = scope: optionalString (entry.labels != [ ]) ''
        # ${entry.name}: ${entry.reason}
        disable_launchd_labels ${escapeShellArg scope} ${bootoutFlag} ${labels}
      '';
      callDisableForGui = user: optionalString (entry.labels != [ ]) ''
        # ${entry.name}: ${entry.reason}
        user_uid="$(/usr/bin/id -u ${escapeShellArg user} 2>/dev/null || true)"
        if [ -n "$user_uid" ]; then
          disable_launchd_labels "gui/$user_uid" ${bootoutFlag} ${labels}
        fi
      '';
    in
    if entry.domain.kind == "system" then
      callDisable "system"
    else
      callDisableForGui entry.domain.user;

  renderLaunchdState = entries: ''
    # Darwin baseline activation state: reversible launchd suppression.
    state_dir="/var/db/nix-config"
    state_file="$state_dir/background-services-disabled-by-nix"
    /bin/mkdir -p "$state_dir"
    next_state="$(/usr/bin/mktemp "$state_dir/.background-services.XXXXXX")"
    : > "$next_state"

    disable_launchd_labels() {
      scope="$1"
      bootout="$2"
      shift 2

      for label in "$@"; do
        domain="$scope/$label"
        already_disabled=0
        managed_before=0

        if [ -f "$state_file" ] \
          && /usr/bin/grep -Fxq "$domain" "$state_file"; then
          managed_before=1
        fi

        if /bin/launchctl print-disabled "$scope" 2>/dev/null \
          | /usr/bin/grep -F "\"$label\" => true" >/dev/null; then
          already_disabled=1
        fi

        if /bin/launchctl disable "$domain" 2>/dev/null \
          && { [ "$already_disabled" -eq 0 ] || [ "$managed_before" -eq 1 ]; }; then
          printf '%s\n' "$domain" >> "$next_state"
        fi

        if [ "$bootout" -eq 1 ]; then
          /bin/launchctl bootout "$domain" 2>/dev/null || true
        fi
      done
    }

    ${concatMapStringsSep "\n" renderLaunchdEntry entries}

    if [ -f "$state_file" ]; then
      while IFS= read -r domain; do
        if [ -n "$domain" ] && ! /usr/bin/grep -Fxq "$domain" "$next_state"; then
          /bin/launchctl enable "$domain" 2>/dev/null || true
        fi
      done < "$state_file"
    fi

    if [ -s "$next_state" ]; then
      /bin/mv "$next_state" "$state_file"
      /bin/chmod 0644 "$state_file" 2>/dev/null || true
    else
      /bin/rm -f "$state_file" "$next_state"
    fi
  '';

  renderPathMarker = marker:
    let
      tmpName = lib.replaceStrings [ " " "/" "'" "\"" ] [ "-" "-" "-" "-" ] marker.name;
    in
    ''
      # Darwin baseline activation state: reversible path markers for ${marker.name}.
      state_file=${escapeShellArg marker.stateFile}
      state_dir="$(dirname "$state_file")"
      marker_name=${escapeShellArg marker.markerName}

      if ${if marker.enable then "true" else "false"} || [ -f "$state_file" ]; then
        run mkdir -p "$state_dir"
        new_state="$(mktemp "$state_dir/.${tmpName}.XXXXXX")"
        : > "$new_state"

        ${optionalString (marker.enable && marker.paths != [ ]) ''
          for path in ${escapeShellArgs marker.paths}; do
            if [ -d "$path" ]; then
              marker="$path/$marker_name"

              if [ -f "$marker" ] && grep -qx ${escapeShellArg marker.markerText} "$marker"; then
                printf '%s\n' "$path" >> "$new_state"
              elif [ ! -e "$marker" ]; then
                printf '%s\n' ${escapeShellArg marker.markerText} > "$marker"
                chmod 0644 "$marker" 2>/dev/null || true
                printf '%s\n' "$path" >> "$new_state"
              fi
            fi
          done
        ''}

        if [ -f "$state_file" ]; then
          while IFS= read -r old_path; do
            marker="$old_path/$marker_name"
            if [ -n "$old_path" ] \
              && ! grep -Fxq "$old_path" "$new_state" \
              && [ -f "$marker" ] \
              && grep -qx ${escapeShellArg marker.markerText} "$marker"; then
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

  pathMarkerActivations = listToAttrs (map
    (marker: {
      inherit (marker) name;
      value = hmDag.entryAfter [ "writeBoundary" ] (renderPathMarker marker);
    })
    cfg.pathMarkers);
in
{
  options.martin.darwinBaseline.activationState = {
    launchdDisabledDomains = mkOption {
      type = types.listOf launchdDisabledDomainType;
      default = [ ];
      description = ''
        Darwin baseline launchd domains that should be disabled reversibly.
        The implementation records only jobs disabled by Nix and only re-enables
        stale jobs from that managed state file.
      '';
    };

    pathMarkers = mkOption {
      type = types.listOf pathMarkerType;
      default = [ ];
      description = ''
        Darwin baseline path markers that should be created reversibly without
        clobbering unmanaged marker files.
      '';
    };
  };

  config = {
    assertions =
      (map
        (entry: {
          assertion = entry.domain.kind != "gui" || entry.domain.user != null;
          message = "Darwin baseline activation state entry ${entry.name} uses a gui domain without a user.";
        })
        cfg.launchdDisabledDomains)
      ++ (map
        (marker: {
          assertion = !(lib.hasInfix "/" marker.markerName);
          message = "Darwin baseline activation state marker ${marker.name} must use a markerName basename, not a path.";
        })
        cfg.pathMarkers);

    system.activationScripts.postActivation.text = lib.mkAfter (renderLaunchdState cfg.launchdDisabledDomains);

    home-manager.users.${currentSystemUser}.home.activation = pathMarkerActivations;
  };
}
