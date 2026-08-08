## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-25 - Privilege Escalation Risk in Zsh Configuration
**Vulnerability:** Global Zsh alias mapped `sudo` to `sudo -E`.
**Learning:** The `-E` flag in `sudo` tells it to preserve the user's entire environment when executing commands as root. Aliasing `sudo` to `sudo -E` by default allows potentially malicious user-controlled environment variables (e.g., `PATH`, `LD_PRELOAD`) to be carried over into the privileged root execution context, which creates a severe privilege escalation risk.
**Prevention:** Remove the global alias `sudo = "sudo -E";` and force `sudo` to use its default, secure behavior (resetting the environment). If `-E` is required for specific tasks, it should be passed explicitly.
