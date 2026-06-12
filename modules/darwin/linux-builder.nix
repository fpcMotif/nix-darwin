{ config, lib, ... }:

let
  cfg = config.martin.linuxBuilder;
in
{
  options.martin.linuxBuilder = {
    enable = lib.mkEnableOption ''
      the nix-darwin managed Linux builder VM. This registers a local
      aarch64-linux builder (nixpkgs' darwin.linux-builder under launchd) so
      the Mac can build Linux closures itself — the UTM guest
      (nixosConfigurations.vm-aarch64-utm) and the dev container image
      (packages.aarch64-linux.dev-container) — without a remote builder.

      Off by default: it runs a background QEMU VM whose disk image is
      fetched from the binary cache on first activation, so enable it
      deliberately and keep the substituters reachable when first switching
    '';

    cores = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Guest CPU cores. Leave headroom for the host's own builds.";
    };

    memoryGb = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "Guest RAM in GiB. dockerTools image builds are memory-hungry.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.linux-builder = {
      enable = true;

      # Reset the builder disk on every restart. The VM is a build appliance,
      # not a pet: ephemeral state keeps its behavior reproducible and makes
      # "restart the builder" a complete repair procedure.
      ephemeral = true;

      maxJobs = 4;

      config = {
        virtualisation = {
          cores = cfg.cores;
          darwin-builder.memorySize = cfg.memoryGb * 1024;
        };
      };
    };
  };
}
