## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-08 - AI CLI Permission Bypasses
**Vulnerability:** Global bypasses for AI CLI agent permission prompts (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`) were hardcoded in configuration files.
**Learning:** Using global bypasses for AI agents creates a high risk of Remote Code Execution (RCE) because untrusted input (e.g., from web searches or external files) could be executed as commands without user consent.
**Prevention:** Ensure AI CLI tools require explicit user permission for potentially destructive or unauthorized actions. Never hardcode permission bypasses in global configs or wrapper scripts.
