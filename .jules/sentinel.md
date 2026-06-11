## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - AI Agent RCE Prevention
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`), allowing them to execute commands without user confirmation.
**Learning:** Global permission bypasses in AI tools create a significant Remote Code Execution (RCE) risk by allowing untrusted input to execute arbitrary code automatically.
**Prevention:** Never use global permission bypasses for AI agents. Always require user permission prompts to mitigate RCE risks from untrusted input.
