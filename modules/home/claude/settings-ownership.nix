{ pkgs, policy, seed }:

let
  policyJson = builtins.toJSON policy;
  program = pkgs.writeText "claude-settings-ownership.jq" ''
    def lookup($object; $path):
      reduce $path[] as $key
        ({ present: true, value: $object };
          if .present and (.value | type) == "object" and (.value | has($key)) then
            .value = .value[$key]
          else
            .present = false
          end);

    def has_path($object; $path):
      lookup($object; $path).present;

    def set_owned($path; $value):
      if ($path | length) == 0 then
        $value
      else
        (if type == "object" then . else {} end)
        | .[$path[0]] |= set_owned($path[1:]; $value)
      end;

    def set_default($path; $value):
      if ($path | length) == 0 or type != "object" then
        .
      elif ($path | length) == 1 then
        .[$path[0]] = $value
      elif .[$path[0]] == null then
        .[$path[0]] = ({} | set_default($path[1:]; $value))
      else
        .[$path[0]] |= set_default($path[1:]; $value)
      end;

    def event_groups($settings; $event):
      if ($settings | type) == "object"
        and ($settings.hooks | type) == "object"
        and ($settings.hooks[$event] | type) == "array" then
        $settings.hooks[$event]
      else
        []
      end;

    def command_path($command):
      try ($command | tostring | capture("^[[:space:]]*(?<path>[^[:space:]]+)").path) catch "";

    def has_event_command($settings; $hook):
      event_groups($settings; $hook.event) as $groups
      | any($groups[]?;
          (.hooks // []) as $items
          | if ($items | type) == "array" then
              any($items[]?; command_path(.command // "") == command_path($hook.command))
            else
              false
            end);

    def add_hook($hook):
      if has_event_command(.; $hook) then
        .
      else
        . as $settings
        | (if ($settings.hooks | type) == "object" then $settings.hooks else {} end) as $hooks
        | (if ($hooks[$hook.event] | type) == "array" then $hooks[$hook.event] else [] end) as $groups
        | .hooks = $hooks
        | .hooks[$hook.event] = $groups + [
            { matcher: $hook.matcher, hooks: [{ type: "command", command: $hook.command }] }
          ]
      end;

    # Removes only the exact entry Nix once added: same event, matcher, and full
    # command. A group or event that held nothing else goes with it.
    def is_owned_command($hook):
      type == "object" and .type == "command" and .command == $hook.command;

    def remove_hook($hook):
      if (.hooks | type) == "object" and (.hooks[$hook.event] | type) == "array" then
        .hooks[$hook.event] as $groups
        | [ $groups[]
            | if type == "object" and .matcher == $hook.matcher
                and (.hooks | type) == "array" and any(.hooks[]; is_owned_command($hook)) then
                (.hooks | map(select(is_owned_command($hook) | not))) as $rest
                | if ($rest | length) == 0 then empty else .hooks = $rest end
              else
                .
              end
          ] as $kept
        | if $kept == $groups then
            .
          elif ($kept | length) == 0 then
            del(.hooks[$hook.event])
          else
            .hooks[$hook.event] = $kept
          end
      else
        .
      end;

    def path_changed($before; $after; $path):
      lookup($before; $path) as $old
      | lookup($after; $path) as $new
      | ($old.present != $new.present)
        or ($old.present and $old.value != $new.value);

    . as $input
    | if ($input | type) != "object" then
        error("Claude settings must be a JSON object")
      else
        ($policy.own // []) as $own
        | ($policy.default // []) as $defaults
        | ($policy.add // []) as $additions
        | ($policy.remove // []) as $removals
        | (if ($oldState | type) == "object" and ($oldState.owned | type) == "array"
           then $oldState.owned
           else []
           end) as $oldOwned
        | (if $targetMissing then {} else $input end) as $before
        | (if $targetMissing then $seed else $input end) as $starting
        | ($own | map(.path)) as $currentPaths
        | [ $oldOwned[] as $entry
            | select(($entry.path | type) == "array" and ($entry.path | length) > 0)
            | select(($currentPaths | index($entry.path)) == null)
            | $entry
          ] as $stale
        | (if $targetMissing then
            $starting
          else
            reduce $stale[] as $entry ($starting;
              if has_path(.; $entry.path) and getpath($entry.path) == $entry.value then
                delpaths([$entry.path])
              else
                .
              end)
          end) as $cleaned
        | (reduce $own[] as $entry ($cleaned;
            set_owned($entry.path; $entry.value))) as $ownedSettings
        | (reduce $defaults[] as $entry ($ownedSettings;
            if has_path(.; $entry.path) then . else set_default($entry.path; $entry.value) end)) as $defaultSettings
        | (reduce $removals[] as $hook ($defaultSettings; remove_hook($hook))) as $prunedSettings
        | (reduce $additions[] as $hook ($prunedSettings; add_hook($hook))) as $updated
        | { version: 1, owned: ($own | map({ path: .path, value: .value })) } as $newState
        | ((($own | map(.path))
            + ($defaults | map(.path))
            + ($additions | map(["hooks", .event]))
            + ($removals | map(["hooks", .event]))
            + ($oldOwned | map(.path))
            + (if $targetMissing then ($seed | keys_unsorted | map([.])) else [] end))
            | unique) as $candidatePaths
        | {
            settings: $updated,
            settingsChanged: ($targetMissing or $updated != $input),
            changedPaths: [ $candidatePaths[] as $path
              | select(path_changed($before; $updated; $path))
              | ($path | join("."))
            ] | unique,
            state: $newState,
            stateChanged: ($stateMissing or $oldState != $newState)
          }
        | [
            (.settings | tojson),
            (.settingsChanged | tostring),
            (.changedPaths | tojson),
            (.state | tojson),
            (.stateChanged | tostring)
          ]
        | .[]
      end
  '';
  command = pkgs.writeShellApplication {
    name = "claude-settings-ownership";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "usage: claude-settings-ownership HOME" >&2
        exit 2
      fi

      home_dir=$1
      target=$home_dir/.claude/settings.json
      state=$home_dir/.local/state/nix-config/claude-settings-ownership.json
      target_missing=false
      input_file=$target
      if [ ! -f "$target" ]; then
        target_missing=true
        input_file=${seed}
      fi

      seed_json=$(cat -- ${seed})
      if [ -f "$state" ]; then
        state_missing=false
        state_json=$(cat -- "$state")
      else
        state_missing=true
        state_json='{"version":1,"owned":[]}'
      fi

      result=$(jq -r \
        --argjson seed "$seed_json" \
        --argjson policy ${pkgs.lib.escapeShellArg policyJson} \
        --argjson oldState "$state_json" \
        --argjson stateMissing "$state_missing" \
        --argjson targetMissing "$target_missing" \
        --from-file ${program} \
        "$input_file")
      mapfile -t result_fields <<< "$result"
      settings_json=''${result_fields[0]}
      settings_changed=''${result_fields[1]}
      changed_paths=''${result_fields[2]}
      new_state=''${result_fields[3]}
      state_changed=''${result_fields[4]}

      if [ -n "''${DRY_RUN:-}" ]; then
        if [ "$settings_changed" = true ]; then
          printf 'claude-settings-ownership: would change keys: %s\n' "$changed_paths" >&2
        fi
        if [ "$state_changed" = true ]; then
          printf 'claude-settings-ownership: would update owned-key state at %s\n' "$state" >&2
        fi
        exit 0
      fi

      settings_tmp=
      state_tmp=
      cleanup() {
        if [ -n "$settings_tmp" ]; then rm -f -- "$settings_tmp"; fi
        if [ -n "$state_tmp" ]; then rm -f -- "$state_tmp"; fi
      }
      trap cleanup EXIT

      if [ "$settings_changed" = true ]; then
        mkdir -p -- "$(dirname -- "$target")"
        settings_tmp=$(mktemp "$target.tmp.XXXXXX")
        printf '%s\n' "$settings_json" > "$settings_tmp"
        if [ -f "$target" ]; then
          chmod --reference="$target" "$settings_tmp"
        else
          chmod 0644 "$settings_tmp"
        fi
        mv -f -- "$settings_tmp" "$target"
        settings_tmp=
        printf 'claude-settings-ownership: updated %s\n' "$target" >&2
      fi

      if [ "$state_changed" = true ]; then
        mkdir -p -- "$(dirname -- "$state")"
        state_tmp=$(mktemp "$state.tmp.XXXXXX")
        printf '%s\n' "$new_state" > "$state_tmp"
        mv -f -- "$state_tmp" "$state"
        state_tmp=
        printf 'claude-settings-ownership: recorded owned keys in %s\n' "$state" >&2
      fi
    '';
  };
in
{
  inherit command program;
}
