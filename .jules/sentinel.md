## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-07-19 - AI CLI Agents Sandbox Bypass
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypass flags (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`).
**Learning:** These flags disable the interactive security prompts designed to prevent untrusted AI input from autonomously executing malicious code, exposing the system to Remote Code Execution (RCE) risks.
**Prevention:** Ensure AI CLI tools always run with interactive permission prompts enabled by avoiding bypass flags.
