## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-08-20 - Remove Insecure sudo -E Global Alias
**Vulnerability:** Globally aliasing `sudo` to `sudo -E` preserves the entire user environment.
**Learning:** Blindly preserving the user environment (including `PATH` and `LD_PRELOAD`) creates a severe privilege escalation risk when running commands as root.
**Prevention:** Do not use `sudo -E` globally. Explicitly pass only necessary environment variables or use `sudo` without `-E` on a per-command basis.
