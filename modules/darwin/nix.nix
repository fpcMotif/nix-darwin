{ currentSystemUser, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # The working tree is almost always dirty; the warning is noise.
    warn-dirty = false;

    trusted-users = [
      "root"
      currentSystemUser
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://claude-code.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];

    # No auto-optimise-store: it can corrupt the store on macOS
    # (https://github.com/NixOS/nix/issues/7273). The scheduled
    # `nix.optimise` job below dedupes safely.
    max-jobs = "auto";
    cores = 0;

    # Keep builders from overcommitting RAM under parallel builds on laptops.
    # This still allows build parallelism, but caps memory pressure.
    max-substitution-jobs = 16;

    # HTTP/2 puts every download on one TLS stream through the Surge TUN; one
    # stall kills them all (CURLE_SEND_ERROR 55). HTTP/1.1 gives each its own socket.
    http2 = false;

    # nix-direnv needs outputs and derivations kept so dev shells survive GC
    # (https://github.com/nix-community/nix-direnv#installation).
    keep-outputs = true;
    keep-derivations = true;
  };

  # Twice-daily (~every 12h) instead of weekly: bounds store growth faster.
  # Retention stays at 14d (not `-d`) so a broken switch always has a rollback
  # target — see PANIC.md.
  nix.gc = {
    automatic = true;
    interval = [
      { Hour = 4; Minute = 30; }
      { Hour = 16; Minute = 30; }
    ];
    options = "--delete-older-than 14d";
  };

  # Scheduled `nix store optimise` (hardlink deduplication), run an hour after
  # each GC so it only deduplicates what survived collection.
  nix.optimise = {
    automatic = true;
    interval = [
      { Hour = 5; Minute = 30; }
      { Hour = 17; Minute = 30; }
    ];
  };
}
