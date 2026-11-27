ctx:

let
  inherit (ctx) helpers lib toplevelEvaluatesOnNative x230Config vmConfig x230Home vmHome hasPackage;
in
[
  (toplevelEvaluatesOnNative "x230" "x86_64-linux" x230Config)
  (toplevelEvaluatesOnNative "vm-aarch64-utm" "aarch64-linux" vmConfig)

  (helpers.assertTest "x230-host-name"
    (x230Config.networking.hostName == "x230")
    "x230 host name should remain x230")

  (helpers.assertTest "x230-zsh-enabled"
    (x230Config.programs.zsh.enable == true)
    "x230/NixOS should enable zsh at the system level")

  (helpers.assertTest "vm-aarch64-utm-host-name"
    (vmConfig.networking.hostName == "vm-aarch64-utm")
    "aarch64 UTM VM host name should remain vm-aarch64-utm")

  (helpers.assertTest "vm-aarch64-utm-zsh-enabled"
    (vmConfig.programs.zsh.enable == true)
    "aarch64 UTM VM should enable zsh at the system level")

  (helpers.assertTest "linux-excludes-darwin-only-agent-packages"
    (!(hasPackage "sourcegraph-amp" x230Home.home.packages))
    "Linux Home Manager packages should not include Darwin-only agent packages")

  (helpers.assertTest "linux-excludes-drafts-mcp-activation"
    (!(lib.hasInfix "drafts-mcp-server" x230Home.home.activation.claudeMcp.data))
    "Linux Home Manager should not force the Darwin-only Drafts MCP server")

  (helpers.assertTest "linux-zed-editor-disabled"
    (
      x230Home.programs.zed-editor.enable == false
      && vmHome.programs.zed-editor.enable == false
    )
    "Linux Home Manager should leave programs.zed-editor off — zed-nightly-bin is Darwin-only")

  (helpers.assertTest "linux-excludes-zed-nightly-bin-package"
    (
      !(hasPackage "zed-nightly-bin" x230Home.home.packages)
      && !(hasPackage "zed-nightly-bin" vmHome.home.packages)
    )
    "Linux Home Manager package lists must never include the Darwin-only zed-nightly-bin")

  (helpers.assertTest "linux-excludes-sourcekit-lsp-package"
    (
      !(hasPackage "sourcekit-lsp" x230Home.home.packages)
      && !(hasPackage "sourcekit-lsp" vmHome.home.packages)
    )
    "Linux Home Manager package lists must not include sourcekit-lsp, whose swiftc is broken on Linux")
]
