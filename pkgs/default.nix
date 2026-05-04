final: _prev:

{
  direnv = _prev.direnv.overrideAttrs (_old: {
    doCheck = false;
  });

  crush = _prev.crush.overrideAttrs (_old: rec {
    version = "0.65.2";

    src = final.fetchFromGitHub {
      owner = "charmbracelet";
      repo = "crush";
      tag = "v${version}";
      hash = "sha256-ASDzXUAIb6rc8S1/e62tvsEAAjevEdibZcMEvpQjsQ4=";
    };

    vendorHash = "sha256-eRLWNBSUMgrsFq0AeNzEb18Z68xOnASY9MwXZzONJqg=";

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
