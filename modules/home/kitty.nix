{ pkgs, lib, ... }:

let
  sxyaziIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/sxyazi/dotfiles/main/kitty/kitty.app.icns";
    sha256 = "110s4gb6mkgnmh6hl1jy361kji14v9hl30g9vb48xah6zs6zzqh8";
  };

  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";
in
{
  programs.kitty = {
    enable = true;
    # Stock, Hydra-cached kitty — do NOT overrideAttrs this. Baking the icon
    # in via overrideAttrs (former kittyWithIcon) changed the drv hash so it
    # never matched cache.nixos.org and kitty rebuilt from source on every
    # switch; that rebuild's `make -C docs man` step reliably dies with a
    # libffi assertion (ffi_trampoline_table_alloc_block_invoke, closures.c:258,
    # Abort trap 6) at this nixpkgs pin. The icon is instead patched into a
    # real /Applications copy at activation time (see home.activation below),
    # which needs no store rebuild.
    package = pkgs.kitty;
    themeFile = "Catppuccin-Macchiato";

    font = {
      name = "MonoLisa";
      size = 18;
    };

    settings = {
      shell_integration = "enabled";
      cursor_blink_interval = "0.5";
      mouse_hide_wait = "3.0";

      macos_option_as_alt = "yes";
      macos_quit_when_last_window_closed = "yes";
      hide_window_decorations = "titlebar-only";
      confirm_os_window_close = 0;

      window_padding_width = 0;
      background_opacity = "1.0";
      mouse_wheel_scroll_multiplier = "0.4";

      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

      enable_audio_bell = "no";
      visual_bell_duration = "0.0";
    };
  };

  # Home Manager only ever surfaces kitty.app as a symlink straight into the
  # (read-only) store under ~/Applications/Home Manager Apps — see
  # modules/darwin/zed.nix for the same observation about Zed. You can't
  # patch a custom icon into a read-only store path, and modules/home/zsh.nix
  # already expects real terminfo files under /Applications/kitty.app, so
  # place a *copy* of kitty.app in /Applications (same install_managed_app
  # idea as modules/darwin/mouse-display.nix / modules/darwin/zed.nix, just
  # run from home.activation since kitty is home-managed) and patch the icon
  # into that writable copy. Idempotent via the `.kitty.src` marker: re-copies
  # only when the underlying store path actually changes.
  home.activation.kittyApp = lib.mkIf pkgs.stdenv.isDarwin (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kitty_src="${pkgs.kitty}/Applications/kitty.app"
    kitty_dst="/Applications/kitty.app"
    kitty_marker="/Applications/.kitty.src"

    if [ ! -d "$kitty_src" ]; then
      echo "[kitty] WARNING: $kitty_src not found; skipping /Applications install" >&2
    else
      if [ "$(readlink "$kitty_marker" 2>/dev/null)" != "${pkgs.kitty}" ]; then
        echo "[kitty] installing $kitty_src into /Applications"
        if [ -e "$kitty_dst" ]; then
          run xattr -rc "$kitty_dst" 2>/dev/null || true
          run chmod -R u+w "$kitty_dst" 2>/dev/null || true
        fi
        run rm -rf "$kitty_dst"
        run cp -R "$kitty_src" "$kitty_dst"
        run chmod -R u+w "$kitty_dst"
        run ln -sfn "${pkgs.kitty}" "$kitty_marker"
      fi

      kitty_icns="$kitty_dst/Contents/Resources/kitty.icns"
      if ! /usr/bin/cmp -s "${sxyaziIcon}" "$kitty_icns" 2>/dev/null; then
        echo "[kitty] patching custom icon into $kitty_dst"
        run cp -f "${sxyaziIcon}" "$kitty_icns"
        run touch "$kitty_dst"
        run ${lsregister} -f "$kitty_dst" || true
      fi
    fi
  '');
}
