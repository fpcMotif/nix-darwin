## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-24 - AI CLI Global Permission Bypasses
**Vulnerability:** Global bypass flags (`--dangerously-skip-permissions` for Claude Code and `amp.dangerouslyAllowAll = true` for Sourcegraph Amp) were hardcoded in user shell environments (`modules/home/ai-cli.nix`, `modules/home/amp.nix`, `modules/home/zsh.nix`).
**Learning:** These global bypasses remove critical user confirmation prompts for all automated CLI agents, making the environment vulnerable to Remote Code Execution (RCE) via untrusted input (prompt injection).
**Prevention:** Never configure global bypass flags or configurations for AI CLI agents. Always require user permission prompts for tool execution to maintain defense in depth against prompt injection.
