{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Inactive Apple-Silicon/ARM64 UTM scaffold, adapted from
  # references/nixos-config-mitchellh. This is intentionally a NixOS host,
  # not part of the active macOS path.
  networking = {
    useDHCP = lib.mkDefault false;
    useNetworkd = lib.mkDefault true;
  };

  # Avoid baking in the reference VM's single NIC name (`enp0s10`).
  # UTM/QEMU interface names can vary; match common Ethernet prefixes instead.
  systemd.network.networks."10-dhcp-ethernet" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "yes";
  };

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "uhci_hcd"
      "virtio_pci"
      "usbhid"
      "usb_storage"
      "sr_mod"
    ];

    loader = {
      systemd-boot = {
        enable = true;
        # VMware, Parallels, and some UTM/QEMU paths are less noisy with this.
        consoleMode = "0";
      };
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
  };

  swapDevices = [ ];

  services.spice-vdagentd.enable = true;

  # UTM/QEMU aarch64 guests can lack working graphics acceleration.
  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";
}
