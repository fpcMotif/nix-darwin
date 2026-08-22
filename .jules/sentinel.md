## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-10-18 - Global sudo -E Alias
**Vulnerability:** A global shell alias `sudo = "sudo -E"` blindly preserves the entire user environment for all sudo commands.
**Learning:** Preserving the environment blindly using `-E` includes sensitive variables like `PATH` and `LD_PRELOAD`, which creates a severe privilege escalation risk when running commands as root, allowing user-controlled binaries or libraries to be executed with elevated privileges.
**Prevention:** Never globally alias `sudo` to `sudo -E`. Require users to explicitly pass `-E` only when absolutely necessary and safe.
