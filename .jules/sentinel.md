## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## $(date +%Y-%m-%d) - AI CLI Permission Bypasses (Contextual Acceptance)
**Vulnerability:** Global bypass flags (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) were hardcoded in shell aliases and configuration files for AI CLI tools.
**Learning:** While globally bypassing permissions creates an RCE risk in multi-user or generic environments, this specific repository is a personal dotfiles configuration for a single-user machine. The explicit inclusion of these bypasses (`cofficial()`, `cc`, `cct`, and `amp.dangerouslyAllowAll = true`) is an intentional, documented configuration choice to enable 'ultracode' as the default workflow, prioritizing friction-free automation over strict confirmation prompts.
**Prevention:** Always verify the context and intended use-case (e.g., personal dotfiles vs. production servers) before flagging intentional workflow configurations as critical vulnerabilities. Security findings must be contextualized to the target environment.
