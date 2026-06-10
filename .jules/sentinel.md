## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-10 - Secure AI CLI Defaults
**Vulnerability:** Global permission bypass flags (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll`) were permanently enabled in AI CLI configurations.
**Learning:** Hardcoding permission bypasses for local AI tools creates a severe Remote Code Execution (RCE) risk, allowing arbitrary code execution from untrusted workspace inputs without user oversight.
**Prevention:** Strictly require user permission prompts for all local AI agents; never set global permission overrides in system dotfiles.
