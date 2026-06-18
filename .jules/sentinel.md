## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-06-14 - AI CLI Permissions Bypass
**Vulnerability:** AI CLI agents (Claude, Amp) were configured with global permission bypasses (e.g., `--dangerously-skip-permissions`, `amp.dangerouslyAllowAll = true`), allowing them to execute potentially destructive actions without user consent.
**Learning:** Hardcoding permission bypasses for convenience in Home Manager modules exposes the system to RCE risks if an AI agent is compromised or fed malicious prompt instructions.
**Prevention:** Always require explicit user prompts for AI CLI actions by removing bypass flags from configurations, ensuring a human-in-the-loop security boundary.
