## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-08-12 - Insecure Sudo Environment Preservation
**Vulnerability:** Global alias `sudo="sudo -E"` preserving user environment.
**Learning:** Blindly preserving the user environment (including variables like `PATH` and `LD_PRELOAD`) when running commands as root creates a severe privilege escalation risk.
**Prevention:** Never globally alias `sudo` to `sudo -E`. Explicitly specify `-E` only when necessary for specific commands.
