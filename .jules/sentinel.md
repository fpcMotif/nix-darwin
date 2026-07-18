## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - AI CLI Agent Permissions
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`).
**Learning:** These tools can execute arbitrary code on the system. Granting them unchecked access introduces significant Remote Code Execution (RCE) risks from untrusted input.
**Prevention:** AI CLI tools must strictly require user permission prompts for any potentially dangerous actions. Never use `--dangerously-skip-permissions` or equivalent flags globally.
