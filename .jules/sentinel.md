## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## $(date +%Y-%m-%d) - AI CLI Global Permission Bypasses Disabled
**Vulnerability:** Global bypass flags (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were hardcoded in CLI configurations for Claude and Amp.
**Learning:** Hardcoding skip-permissions flags for AI CLI tools inside shell configurations exposes the system to Remote Code Execution (RCE) if the CLI processes malicious input without prompting for user confirmation.
**Prevention:** Never use or commit global permission bypass flags (`--dangerously-skip-permissions`, `dangerouslyAllowAll = true`) in configuration files. Always enforce interactive permission prompts for AI-driven command execution.
