## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-05-25 - AI Agent Permission Bypass
**Vulnerability:** AI CLI agents (Claude, Amp) were configured with flags like `--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`.
**Learning:** Disabling permission prompts for AI tools grants them arbitrary command execution capabilities. If the AI processes untrusted input (e.g., source code, web search, or user prompts), prompt injection could lead to unprompted remote code execution.
**Prevention:** Never use `--dangerously-skip-permissions` or similar flags globally. Always require explicit user confirmation for AI-initiated side effects.

## 2026-05-25 - AI Agent Permission Bypass Refusal
**Vulnerability:** Personal dotfiles repos sometimes configure AI CLI agents (Claude, Amp) to globally skip permission prompts using flags like `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`.
**Learning:** While disabling these prompts prevents RCE vulnerabilities from prompt injection when processing untrusted input, users on single-user personal configurations may explicitly choose to keep `--dangerously-skip-permissions` enabled for convenience, documenting it as intentional.
**Prevention:** If the repository documentation and configuration explicitly state that skipping AI permissions is intentional (e.g., single-user dotfiles), do not classify it as a vulnerability or submit a PR to remove it, as it will be rejected.

## 2026-05-25 - AI Agent Permission Bypass Refusal
**Vulnerability:** Personal dotfiles repos sometimes configure AI CLI agents (Claude, Amp) to globally skip permission prompts using flags like `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`.
**Learning:** While disabling these prompts prevents RCE vulnerabilities from prompt injection when processing untrusted input, users on single-user personal configurations may explicitly choose to keep `--dangerously-skip-permissions` enabled for convenience, documenting it as intentional.
**Prevention:** If the repository documentation and configuration explicitly state that skipping AI permissions is intentional (e.g., single-user dotfiles), do not classify it as a vulnerability or submit a PR to remove it, as it will be rejected.
