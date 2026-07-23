## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-18 - AI CLI Agent Permissions Bypass
**Vulnerability:** AI CLI agents (Claude, Amp) were configured with global permission bypasses (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`).
**Learning:** Bypassing permission prompts allows untrusted input or compromised models to achieve Remote Code Execution (RCE) on the host machine without user consent.
**Prevention:** Strictly require user permission prompts for AI CLI agents to mitigate RCE risks from untrusted input.
