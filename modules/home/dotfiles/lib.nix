{ lib }:

{
  guardTargets = targets:
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      check_martin_dotfile_target() {
        local target="$1"
        local display="$2"

        if [ -e "$target" ] || [ -L "$target" ]; then
          if [ -L "$target" ]; then
            local link_target
            link_target="$(readlink "$target")"
            case "$link_target" in
              /nix/store/*) return 0 ;;
            esac
          fi

          echo "ERROR: $display already exists and is not a Nix/Home Manager symlink." >&2
          echo "To migrate this path to martin.dotfiles, remove the unmanaged copy first:" >&2
          echo "  chezmoi forget --force \"$display\"" >&2
          echo "  rm -rf \"$display\"" >&2
          echo "Then re-run your system activation (darwin-rebuild / nixos-rebuild / home-manager switch)." >&2
          exit 1
        fi
      }

      ${lib.concatMapStringsSep "\n" (target: ''check_martin_dotfile_target "$HOME/${target}" "\$HOME/${target}"'') targets}
    '';

  profileAsset = baseDir: profile: path: baseDir + "/assets/${profile}/${path}";
}
