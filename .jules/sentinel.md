## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-06-12 - Prevented RCE risk via unprompted AI CLI permissions
**Vulnerability:** AI CLI tools (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`) inside Nix Home Manager profiles.
**Learning:** Hardcoding permission bypasses into dotfiles completely subverts the sandbox security models of these agents. Given these tools can execute local bash commands and write to disk, an untrusted prompt or context window injection could lead to silent Remote Code Execution (RCE) on the developer's machine without any interactive approval prompt.
**Prevention:** Never use global bypass flags (like `--dangerously-skip-permissions` or allow-all booleans) in default environments for AI agents capable of local system execution. Enforce interactive permission prompts for every critical action.
