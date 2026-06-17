## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-19 - AI CLI Agents Permissions Bypass
**Vulnerability:** AI CLI agents (Claude, Amp) were configured with global permission bypasses (e.g., `--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`), allowing them to execute potentially destructive actions without user consent.
**Learning:** Global bypasses for AI agents expose the system to Remote Code Execution (RCE) risks if untrusted input is processed.
**Prevention:** Ensure AI CLI agents strictly require user permission prompts for actions and never configure global bypasses in Home Manager modules.
