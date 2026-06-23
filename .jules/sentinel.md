## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2025-02-23 - Prevent AI CLI Agent RCE

**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) in Home Manager (`modules/home/ai-cli.nix`, `modules/home/amp.nix`, `modules/home/zsh.nix`). This exposes the local development environment to severe Remote Code Execution (RCE) risks if an agent is tricked into executing malicious commands by untrusted input.

**Learning:** Global bypass flags defeat the necessary prompt-based authorization flow required for safe local execution of AI tools. AI agents are inherently susceptible to prompt injection.

**Prevention:** Never use or commit flags like `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`. Always ensure agents require user permission prompts for shell commands and file access.
