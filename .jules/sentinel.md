## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-03 - AI CLI Security Bypasses Removed
**Vulnerability:** Global bypasses for AI CLI agents (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were enabled.
**Learning:** Using global bypasses for AI tools introduces significant Remote Code Execution (RCE) risks from untrusted inputs by allowing the AI agent to execute arbitrary commands without user consent.
**Prevention:** Ensure all AI CLI tools explicitly require user permission prompts before executing actions. Never use `--dangerously-skip-permissions` or equivalent global allow flags.
