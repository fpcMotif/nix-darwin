## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-11 - AI CLI Global Permission Bypasses
**Vulnerability:** AI CLI agents (e.g., Claude, Sourcegraph Amp) were configured with global bypasses like `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`.
**Learning:** These global bypasses allow AI agents to run commands without user permission, which introduces critical Remote Code Execution (RCE) risks from untrusted input.
**Prevention:** Strictly require user permission prompts for AI CLI agents. Remove `--dangerously-skip-permissions` flags and set `amp.dangerouslyAllowAll = false;`.
