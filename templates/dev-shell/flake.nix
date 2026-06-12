{
  description = "Per-project pinned dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      forEachSystem = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            # Project toolchain goes here. Everything resolves from the
            # flake.lock pin, so every machine gets identical versions.
            packages = [
              # pkgs.nodejs_22
              # pkgs.uv
              # pkgs.go
            ];
          };
        });
    };
}
