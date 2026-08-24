## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2025-02-18 - Remove global sudo -E alias
**Vulnerability:** Shell configurations blindly aliasing `sudo` to `sudo -E` preserve the entire user environment.
**Learning:** The `-E` flag preserves potentially malicious environment variables (like `PATH` or `LD_PRELOAD`) when executing commands as root, creating a severe privilege escalation risk.
**Prevention:** Never globally alias `sudo` to `sudo -E`. Only preserve specific environment variables intentionally when required.
