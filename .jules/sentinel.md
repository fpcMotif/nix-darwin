## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2025-02-14 - Prevent RCE from Untrusted Input in AI Agents
**Vulnerability:** AI CLI agents (e.g., Claude, Amp) were configured with global permission bypasses (e.g. `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`) in Home Manager modules.
**Learning:** Hardcoding permission bypasses for AI agents that evaluate or execute code enables Remote Code Execution (RCE) if the agent is fed malicious untrusted input. The default safety prompts for AI tools must not be bypassed globally in the environment config.
**Prevention:** Ensure any AI CLI configurations strictly require user permission prompts. Do not use `--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true` in the system dotfiles.
