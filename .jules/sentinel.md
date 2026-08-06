## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-24 - Unsafe Sudo Alias in Zsh
**Vulnerability:** The `sudo` command was globally aliased to `sudo -E` in `modules/home/zsh.nix`.
**Learning:** The `-E` flag tells `sudo` to preserve the user's entire environment when elevating privileges. This is dangerous because it allows user-controlled environment variables (like `LD_PRELOAD`, `PATH`, or custom config paths) to influence root-level processes, creating vectors for privilege escalation.
**Prevention:** Remove the alias and enforce the default behavior of `sudo`, which securely sanitizes the environment. Users who genuinely need to preserve variables for a specific task must explicitly type `sudo -E` and understand the risks.
