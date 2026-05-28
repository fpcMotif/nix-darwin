## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-05-28 - [CRITICAL] Prevent RCE from Unrestricted AI CLI Tools
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp, Claude-Teams) were configured with flags like `--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`. These flags allow AI tools to execute shell commands and modify files without user confirmation. If an AI agent processes a malicious prompt (e.g., from an untrusted PR, codebase, or web search), it could lead to Remote Code Execution (RCE) on the developer's machine.
**Learning:** For convenience, global bypasses were added to Home Manager configurations (`modules/home/ai-cli.nix`, `modules/home/amp.nix`, `modules/home/zsh.nix`). However, this violates the principle of least privilege and introduces a massive security gap where untrusted input can hijack the AI's execution capabilities. The memory explicitly states that global bypasses like `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true` are prohibited to mitigate RCE risks from untrusted input.
**Prevention:** Never configure AI agents to bypass permission prompts globally. Always require explicit user consent before an AI agent executes commands or modifies files. Remove any `--dangerously-skip-permissions` or equivalent flags from aliases, functions, and configuration files. Ensure AI tools default to secure execution models.
