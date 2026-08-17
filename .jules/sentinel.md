## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-19 - Global Sudo Environment Preservation
**Vulnerability:** Globally aliasing `sudo` to `sudo -E` in shell configurations.
**Learning:** The `-E` flag blindly preserves the entire user environment (including `PATH`, `LD_PRELOAD`, etc.) when running commands as root, which creates a severe privilege escalation risk.
**Prevention:** Never globally alias `sudo` to `sudo -E`. Explicitly use `sudo -E` only when strictly necessary and safe.
