## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-24 - Unsafe Sudo Alias in Zsh
**Vulnerability:** The `sudo` command was globally aliased to `sudo -E` in `modules/home/zsh.nix`.
**Learning:** The `-E` flag tells `sudo` to preserve the user's entire environment when elevating privileges. This is dangerous because it allows user-controlled environment variables (like `LD_PRELOAD`, `PATH`, or custom config paths) to influence root-level processes, creating vectors for privilege escalation.
**Prevention:** Remove the alias and enforce the default behavior of `sudo`, which securely sanitizes the environment. Users who genuinely need to preserve variables for a specific task must explicitly type `sudo -E` and understand the risks.
## 2024-05-24 - Cross-Platform Activation Script Failures
**Vulnerability:** CI failed on Linux because `drafts-mcp-server` (an AppleScript bridge) was being evaluated unconditionally.
**Learning:** Home Manager configurations often mix platform-specific (Darwin/Linux) derivations. If a Darwin-only package is evaluated within an activation script block, it causes Nix to throw an evaluation error on Linux builds, even if the script would not run or execute the package.
**Prevention:** When conditionally wrapping Home Manager activation DAG entries (like `lib.hm.dag.entryAfter`) for platform-specific tools, always wrap them in `lib.mkIf pkgs.stdenv.isDarwin` (or similar) to prevent Nix evaluation failures on unsupported platforms. Ensure the entire DAG function call and its arguments are enclosed in parentheses (e.g., `lib.mkIf ... (lib.hm.dag.entryAfter ...)`).
## 2024-05-24 - Cross-Platform List Evaluation Failures
**Vulnerability:** CI failed on Linux because `sourcekit-lsp` (Swift) was being evaluated unconditionally in a generic list.
**Learning:** Home Manager lists (like packages or `lspServers`) that are shared across platforms cannot unconditionally include Darwin-only or failing-on-Linux packages. This triggers a Nix evaluation error across the whole environment on unsupported platforms.
**Prevention:** Conditionally splice platform-specific packages into lists using `] ++ lib.optionals pkgs.stdenv.isDarwin [ ... ] ++ [`. Ensure you correctly close and reopen the array to avoid swallowing subsequent generic list elements into the conditional block.
