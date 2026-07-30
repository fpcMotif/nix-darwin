## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-18 - Secure Default SSH Configurations
**Vulnerability:** Default NixOS SSH configurations allow root login and password authentication if `services.openssh.enable = true` is ever set.
**Learning:** In a modular architecture, enabling a service in one place without global defaults can expose systems to brute force attacks.
**Prevention:** Hardened `services.openssh.settings` globally in NixOS modules by setting `PermitRootLogin` to 'no' and `PasswordAuthentication` to false by default using `lib.mkDefault`.
## 2024-05-18 - CI Failures from macOS-only Dependencies
**Vulnerability:** Not a direct security vulnerability, but a reliability/CI failure issue where macOS-only dependencies (like `drafts-mcp-server`) were breaking Linux builds.
**Learning:** Home Manager configurations shared across platforms must use `lib.mkIf pkgs.stdenv.isDarwin` (or similar conditionals) around platform-specific activations to prevent evaluation failures on unsupported hosts.
**Prevention:** Always conditionally wrap platform-specific binaries or activation scripts in cross-platform modules to ensure safe evaluation.
