## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-19 - AI CLI Global Permission Bypass
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`).
**Learning:** These settings allow AI agents to execute arbitrary shell commands without user confirmation, introducing a severe Remote Code Execution (RCE) risk from untrusted input or hallucinated commands.
**Prevention:** Ensure all AI tools strictly require user permission prompts. Global permission bypasses must never be enabled in configuration files.
