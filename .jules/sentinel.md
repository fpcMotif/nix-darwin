## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-06-04 - [Remove global bypasses for AI CLI permissions]
**Vulnerability:** Global bypass flags (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were used for AI CLI agents, allowing them to execute arbitrary code without user prompt.
**Learning:** AI CLI agents require user permission prompts to prevent RCE from untrusted input. Bypassing these globally introduces significant security risks.
**Prevention:** Ensure AI CLI agents always prompt for permissions and avoid using global bypass flags in configuration files.
