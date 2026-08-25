## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-08-25 - Prevent Privilege Escalation via Sudo Environment Preservation
**Vulnerability:** Global alias `sudo="sudo -E"` preserves the entire user environment when executing commands as root.
**Learning:** Blindly preserving the environment (including variables like `PATH` or `LD_PRELOAD`) allows a compromised user account to execute malicious binaries or inject shared libraries under root privileges.
**Prevention:** Never alias `sudo` to `sudo -E`. Use explicit environment variables on a per-command basis when necessary.
