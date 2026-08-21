## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-10-24 - Sudo Alias Privilege Escalation Risk
**Vulnerability:** Sudo was globally aliased to `sudo -E` in the zsh configuration.
**Learning:** The `-E` flag blindly preserves the entire user environment (including `PATH` and `LD_PRELOAD`), creating a severe privilege escalation risk when running commands as root.
**Prevention:** Never globally alias `sudo` to `sudo -E`. Only use `-E` explicitly for specific commands when absolutely necessary, or preferably use `sudo -i` or `sudo` without preserving environment.
