## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - AI CLI Agent Permission Bypasses
**Vulnerability:** Global permission bypass flags (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were enabled for AI CLI agents in the home manager configuration.
**Learning:** Hardcoding permission bypasses for AI agents like Claude and Sourcegraph Amp introduces a severe Remote Code Execution (RCE) risk, as untrusted input or prompt injections could execute arbitrary system commands without user confirmation.
**Prevention:** Remove global bypass flags and enforce explicit user permission prompts for all AI CLI agents to ensure human oversight on command execution.
