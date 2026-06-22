## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-22 - AI CLI Permission Bypasses
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (e.g., `--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`), completely disabling user approval prompts for system actions.
**Learning:** Hardcoding permission bypasses in shell aliases and configuration files for convenience disables critical security boundaries, exposing the system to Remote Code Execution (RCE) risks if an AI agent hallucinates or is maliciously instructed to run destructive commands.
**Prevention:** AI CLI agents must strictly require user permission prompts. Never use global bypasses like `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true` in Home Manager configurations or shell environments.
