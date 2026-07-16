## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2025-03-05 - Remove global AI CLI permission bypasses
**Vulnerability:** AI CLI agents (Claude, Amp) were configured with global permission bypasses (`--dangerously-skip-permissions` and `amp.dangerouslyAllowAll = true`) in Nix Home Manager configurations.
**Learning:** Global bypasses for AI agents expose the system to significant RCE risks from untrusted input, as the AI can execute commands without user prompting.
**Prevention:** Ensure AI agents strictly require user permission prompts. Prohibit global bypass configurations.
