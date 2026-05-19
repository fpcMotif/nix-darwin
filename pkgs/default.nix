final: _prev:

{
  direnv = _prev.direnv.overrideAttrs (_old: {
    doCheck = false;
  });

  codex = final.callPackage ./codex.nix { };

  martin = {
    mkAppFromZip = final.callPackage ./lib/mk-app-from-zip.nix { };

    dropbox = final.callPackage ./dropbox.nix { };
    google-drive = final.callPackage ./google-drive.nix { };
    hammerspoon = final.callPackage ./hammerspoon.nix { };
    raycast = final.callPackage ./raycast.nix { };

    bettermouse = final.callPackage ./bettermouse.nix { };
    mole = final.callPackage ./mole.nix { };
    sf-mono = final.callPackage ./sf-mono.nix { };
    sf-symbols = final.callPackage ./sf-symbols.nix { };
    squirrel = final.callPackage ./squirrel.nix { };

    gemini-cli-preview = final.callPackage ./gemini-cli-preview.nix { };
    oh-my-pi = final.callPackage ./oh-my-pi.nix { };
    pi-coding-agent = final.callPackage ./pi-coding-agent.nix { };
    sourcegraph-amp = final.callPackage ./sourcegraph-amp.nix { };
    droid = final.callPackage ./droid.nix { };
    opencode = final.callPackage ./opencode.nix { };
    opencode-electron = final.callPackage ./opencode-electron.nix { };
    zed-nightly-bin = final.callPackage ./zed-nightly-bin.nix { };
  };
}
