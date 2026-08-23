## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-08-23 - Remove global sudo -E alias
**Vulnerability:** Global alias `sudo="sudo -E"` in Zsh configuration blindly preserved the user environment.
**Learning:** Preserving the entire environment (including `PATH` and `LD_PRELOAD`) during `sudo` execution creates a severe privilege escalation risk.
**Prevention:** Never alias `sudo` to `sudo -E` globally; use it explicitly only when necessary for specific commands.
