## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-18 - Global AI Agent Permission Bypasses Enabled by Default
**Vulnerability:** Several AI agents (`claude` in `ai-cli.nix`, `cmux claude-teams` in `zsh.nix`, and `amp` in `amp.nix`) had their strict permission requirements globally bypassed via flags like `--dangerously-skip-permissions` or `"amp.dangerouslyAllowAll" = true`.
**Learning:** Hardcoding permission bypasses for untrusted AI CLI tools introduces critical RCE (Remote Code Execution) risks. When an AI receives untrusted input and is allowed to execute actions without user confirmation, it can be trivially manipulated to execute malicious payloads on the host machine.
**Prevention:** Never configure AI agents to skip permission checks globally. Always require interactive user approval for actions, especially code execution and file modifications, to mitigate RCE risks from prompt injection or untrusted data processing.
