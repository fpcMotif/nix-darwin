## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-18 - Insecure Sudo Environment Preservation
**Vulnerability:** The alias sudo = "sudo -E" was present in the shell configuration.
**Learning:** The -E flag tells sudo to preserve the user's entire environment (including PATH, LD_PRELOAD, etc.) when running as root, which can lead to privilege escalation if malicious environment variables are set.
**Prevention:** Never globally alias sudo to preserve the environment. Pass variables explicitly when needed or configure env_keep in sudoers for specific variables.
