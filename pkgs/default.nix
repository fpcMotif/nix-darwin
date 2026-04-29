final: _prev:

{
  martin = {
    dropbox = final.callPackage ./dropbox.nix { };
    google-drive = final.callPackage ./google-drive.nix { };
    raycast = final.callPackage ./raycast.nix { };

    gemini-cli-preview = final.callPackage ./gemini-cli-preview.nix { };
    oh-my-pi = final.callPackage ./oh-my-pi.nix { };
    pi-coding-agent = final.callPackage ./pi-coding-agent.nix { };
    pi-npm-bun = final.callPackage ./pi-npm-bun.nix { };
    sourcegraph-amp = final.callPackage ./sourcegraph-amp.nix { };
  };
}
