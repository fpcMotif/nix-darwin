## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-13 - Global AI CLI Permission Bypass
**Vulnerability:** Global RCE bypasses were enabled for AI agents (`--dangerously-skip-permissions` for Claude/Codex, `amp.dangerouslyAllowAll = true` for Amp).
**Learning:** These global configurations silently allow untrusted, external input (API responses) to automatically execute arbitrary shell commands without user confirmation.
**Prevention:** Always require manual user approval prompts for execution inside AI CLI tools.
