## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-13 - AI CLI Permission Bypasses
**Vulnerability:** Global bypasses for AI CLI permissions (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were enabled.
**Learning:** These settings allow AI tools to bypass user confirmation prompts, creating a significant Remote Code Execution (RCE) risk from untrusted input (e.g. prompt injection).
**Prevention:** Never use global skip-permissions flags for AI CLI tools. Always require explicit user consent for potentially dangerous actions.
