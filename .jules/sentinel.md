## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-05-25 - AI Agent Permission Bypass
**Vulnerability:** AI CLI agents (Claude, Amp) were configured with flags like `--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`.
**Learning:** Disabling permission prompts for AI tools grants them arbitrary command execution capabilities. If the AI processes untrusted input (e.g., source code, web search, or user prompts), prompt injection could lead to unprompted remote code execution.
**Prevention:** Never use `--dangerously-skip-permissions` or similar flags globally. Always require explicit user confirmation for AI-initiated side effects.
