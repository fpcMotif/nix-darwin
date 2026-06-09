## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-05 - AI CLI Dangerous Permission Bypasses
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`), allowing untrusted inputs to execute arbitrary code without user confirmation.
**Learning:** Global bypasses for AI agents remove critical user-in-the-loop safeguards, introducing Remote Code Execution (RCE) risks from potentially malicious AI-generated commands.
**Prevention:** Ensure AI CLI agents strictly require user permission prompts for executions. Never use flags or settings that dangerously skip permissions or allow all actions globally.
