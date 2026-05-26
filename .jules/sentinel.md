## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-05-26 - AI CLI Global Permission Bypasses (RCE Risk)
**Vulnerability:** Global bypass flags (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were hardcoded in shell aliases and configuration files for AI CLI tools (Claude, Amp).
**Learning:** Hardcoding permission bypasses nullifies the tools' built-in safety mechanisms, granting AI models unchecked access to the local machine and creating a severe Remote Code Execution (RCE) risk from untrusted inputs.
**Prevention:** Never configure AI CLI tools to globally bypass permission prompts. Explicitly require user approval for actions, adhering to the principle of least privilege.
