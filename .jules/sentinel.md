## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-06 - AI CLI Agent Permission Bypasses
**Vulnerability:** AI CLI tools (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`).
**Learning:** Hardcoding global permission skips in shell aliases or dotfiles exposes the system to Remote Code Execution (RCE) if the AI models process untrusted input and execute commands autonomously.
**Prevention:** Never configure AI code assistants to globally bypass user confirmation prompts. Always require explicit user approval for tool execution.
