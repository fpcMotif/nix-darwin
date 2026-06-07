## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-07 - AI CLI Permission Bypasses
**Vulnerability:** AI CLI tools (Claude, Amp) were configured with global permission bypasses (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`).
**Learning:** These settings allow AI agents to execute arbitrary commands without user confirmation, exposing the system to Remote Code Execution (RCE) risks if untrusted input is processed.
**Prevention:** Always require user permission prompts for AI CLI tools. Never commit global bypass flags to dotfiles or Home Manager configurations.
