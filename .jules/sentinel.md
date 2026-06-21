## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-06-21 - Remove AI CLI Permission Bypasses
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`).
**Learning:** Allowing AI agents to execute code or access files without explicit user permission prompts exposes the system to Remote Code Execution (RCE) vulnerabilities from untrusted input or prompt injection.
**Prevention:** Ensure all AI CLI tools require user permission prompts for potentially dangerous actions. Never use flags or settings that dangerously bypass these protections globally.
