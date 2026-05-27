## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - AI CLI Global Permission Bypasses
**Vulnerability:** AI CLI tools (Claude, Sourcegraph Amp) were configured with global flags (`--dangerously-skip-permissions` or `amp.dangerouslyAllowAll = true`) that bypass user permission prompts.
**Learning:** Bypassing permission prompts globally for AI tools allows them to execute arbitrary commands without human oversight, creating a severe Remote Code Execution (RCE) risk, especially if the AI is fed malicious instructions or prompt injections.
**Prevention:** Always require human-in-the-loop permission prompts for AI CLIs. Never commit configurations that globally disable these safety features.
