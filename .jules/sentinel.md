## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-05-19 - AI CLI Global Permission Bypass
**Vulnerability:** AI CLI agents (Claude, Sourcegraph Amp) were configured with global permission bypasses (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`).
**Learning:** These settings allow AI agents to run arbitrary shell commands without user confirmation, exposing the system to Remote Code Execution (RCE) via prompt injection.
**Prevention:** Remove bypass flags like `--dangerously-skip-permissions` and ensure permission-requiring settings like `amp.dangerouslyAllowAll` are set to `false` so user prompts are strictly enforced.
