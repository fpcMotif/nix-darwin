{ currentSystemUser, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [
      "root"
      currentSystemUser
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://claude-code.cachix.org"
      "https://zed.cachix.org"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];

    # macOS boots through Apple's own firmware path; nix-darwin does not manage
    # Linux-style EFI/systemd-boot settings. Efficiency gains on Darwin come
    # from faster and leaner Nix store behavior instead.
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;

    # Keep builders from overcommitting RAM under parallel builds on laptops.
    # This still allows build parallelism, but caps memory pressure.
    max-substitution-jobs = 16;

    # Prevent long-lived old generations/caches from bloating local storage.
    keep-outputs = false;
    keep-derivations = false;
  };

  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 4; Minute = 30; };
    options = "--delete-older-than 14d";
  };
}
