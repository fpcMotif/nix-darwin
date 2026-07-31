## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - AI CLI Agent Permission Bypasses
**Vulnerability:** Global bypasses for AI CLI agents (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were enabled.
**Learning:** Permitting AI agents to bypass permission prompts globally exposes the system to Remote Code Execution (RCE) risks from untrusted inputs.
**Prevention:** Strictly require user permission prompts for AI CLI agents and avoid adding global bypass flags in the shell environment.
