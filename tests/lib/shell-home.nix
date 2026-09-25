# A real Home Manager evaluation of only the interactive-shell modules, so a
# check can run the generated shell config in a sandboxed shell without
# building the whole host closure. `interactive` is martin.shell.interactive.
{ inputs, pkgs, lib }:
{ interactive ? "fish" }:

inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    ../../modules/home/session.nix
    ../../modules/home/shell/zsh.nix
    ../../modules/home/shell/fish.nix
    ../../modules/home/shell/direnv.nix
    ../../modules/home/shell/fzf.nix
    ../../modules/home/shell/zoxide.nix
    ../../modules/home/worktrunk.nix
    ../../modules/home/yazi.nix
    ../../modules/home/ai-cli.nix
    ../../modules/home/obsidian.nix
    {
      home = {
        username = "tester";
        homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/tester" else "/home/tester";
        stateVersion = "24.05";
      };
      martin.shell.interactive = lib.mkForce interactive;
    }
  ];
}
