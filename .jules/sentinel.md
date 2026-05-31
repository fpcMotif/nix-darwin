## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-31 - AI CLI Agent Global Permission Bypasses
**Vulnerability:** The configuration for Amp (`amp.dangerouslyAllowAll = true`) and Claude (`--dangerously-skip-permissions` in shell aliases) globally disabled permission prompts.
**Learning:** Hardcoding permission bypass flags for AI agents exposes the system to severe Remote Code Execution (RCE) risks if an agent encounters untrusted inputs (e.g., malicious prompts or code snippets). The agent could execute destructive shell commands without the user ever being notified.
**Prevention:** Never use global permission bypass flags (`--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`) in configurations. AI agents must always strictly require explicit user permission for potentially destructive actions.
