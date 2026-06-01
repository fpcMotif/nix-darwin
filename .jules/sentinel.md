## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-06-01 - Remove Dangerous CLI Bypass Flags
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured in Home Manager with flags like `--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`, bypassing user permission prompts.
**Learning:** Using global bypasses for untrusted input processing (like AI generated code) exposes the system to RCE risks, violating the principle of least privilege.
**Prevention:** Never use global bypasses for permission prompts. Always enforce explicit user consent for potentially destructive AI actions.
