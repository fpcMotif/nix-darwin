{ config, lib, pkgs, inputs, ... }:

let
  # zimfw builds a static init.zsh from .zimrc. Running that build here, with
  # the module as an absolute store path (which zimfw never installs, updates,
  # or compiles), leaves no ~/.zim state and no network or version check at
  # startup.
  #
  # Only `completion` reproduces retained behavior. `environment` would
  # override Home Manager's history sizes and add NO_CLOBBER; `input` binds
  # only the main keymap and misses prefix-history Up/Down.
  zimInit = pkgs.runCommandLocal "zim-init" { nativeBuildInputs = [ pkgs.zsh ]; } ''
    mkdir $out
    echo "zmodule ${inputs.zim-completion}" > $out/zimrc
    ZIM_HOME=$out ZIM_CONFIG_FILE=$out/zimrc zsh -f -c \
      "zstyle ':zim' disable-version-check yes; source ${pkgs.zimfw}/zimfw.zsh build"
    test -s $out/init.zsh
  '';
in
{
  options.martin.shell.zim.enable = lib.mkEnableOption "Zim's completion module, built into a static init.zsh at Nix build time" // {
    default = true;
  };

  # Takes Home Manager's compinit slot. The module rebuilds the dump only when
  # the completions on fpath change, then zcompiles it.
  config = lib.mkIf config.martin.shell.zim.enable {
    programs.zsh.completionInit = "source ${zimInit}/init.zsh";
  };
}
