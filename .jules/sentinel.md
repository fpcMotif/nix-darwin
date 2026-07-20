## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-24 - AI CLI Global Permission Bypasses
**Vulnerability:** Global bypasses for AI CLI agents (--dangerously-skip-permissions, dangerouslyAllowAll=true) were enabled in Home Manager.
**Learning:** These bypasses disable user prompts for AI actions, exposing the system to Remote Code Execution (RCE) if untrusted input is processed by the AI.
**Prevention:** Never use global permission bypasses for AI agents; always require interactive prompts for dangerous commands.
