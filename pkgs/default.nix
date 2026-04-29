final: _prev:

{
  crush = _prev.crush.overrideAttrs (_old: rec {
    version = "0.63.0";

    src = final.fetchFromGitHub {
      owner = "charmbracelet";
      repo = "crush";
      tag = "v${version}";
      hash = "sha256-OAFdmBt7IHFym/anNs3Fu5RD3e/BtraPmanhTjowwFU=";
    };

    vendorHash = "sha256-7J2sQBRlPNNDewuNVETg8yDWe97v2TtUIUIj8yeDCuM=";

    ldflags = [
      "-s"
      "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
    ];
  });

  martin = {
    dropbox = final.callPackage ./dropbox.nix { };
    google-drive = final.callPackage ./google-drive.nix { };
    raycast = final.callPackage ./raycast.nix { };

    gemini-cli-preview = final.callPackage ./gemini-cli-preview.nix { };
    oh-my-pi = final.callPackage ./oh-my-pi.nix { };
    pi-coding-agent = final.callPackage ./pi-coding-agent.nix { };
    sourcegraph-amp = final.callPackage ./sourcegraph-amp.nix { };
    droid = final.callPackage ./droid.nix { };
    opencode = final.callPackage ./opencode.nix { };
    opencode-electron = final.callPackage ./opencode-electron.nix { };
  };
}
