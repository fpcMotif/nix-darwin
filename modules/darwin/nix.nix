{ currentSystemUser, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Flake builds here run from the live working tree, which is almost always
    # dirty (nightly auto-update commits, in-progress edits). The resulting
    # "Git tree '…' is dirty" line on every `just switch` is pure noise — the
    # build still uses the working tree as-is — so silence it.
    warn-dirty = false;

    trusted-users = [
      "root"
      currentSystemUser
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://claude-code.cachix.org"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];

    # macOS boots through Apple's own firmware path; nix-darwin does not manage
    # Linux-style EFI/systemd-boot settings. Efficiency gains on Darwin come
    # from faster and leaner Nix store behavior instead.
    #
    # Inline store optimisation (auto-optimise-store) is NOT used here: it has
    # a long-standing store-corruption bug on macOS
    # (https://github.com/NixOS/nix/issues/7273). The scheduled `nix.optimise`
    # job below provides the same deduplication safely.
    max-jobs = "auto";
    cores = 0;

    # Keep builders from overcommitting RAM under parallel builds on laptops.
    # This still allows build parallelism, but caps memory pressure.
    max-substitution-jobs = 16;

    # nix-direnv pins `nix develop` shells with GC roots; keeping outputs and
    # derivations alive is its documented requirement so dev shells survive
    # garbage collection and stay usable offline
    # (https://github.com/nix-community/nix-direnv#installation).
    # The weekly GC below still bounds store growth.
    keep-outputs = true;
    keep-derivations = true;
  };

  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 4; Minute = 30; };
    options = "--delete-older-than 14d";
  };

  # Scheduled `nix store optimise` (hardlink deduplication), run after the
  # weekly GC so it only deduplicates what survived collection.
  nix.optimise = {
    automatic = true;
    interval = { Weekday = 0; Hour = 5; Minute = 30; };
  };
}
