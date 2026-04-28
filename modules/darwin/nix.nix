{ currentSystemUser, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [
      "root"
      currentSystemUser
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
