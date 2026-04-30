## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2026-04-30 - SSH known_hosts Hashing
**Vulnerability:** Unhashed `known_hosts` file exposes infrastructure maps to attackers.
**Learning:** By default, SSH may store `known_hosts` in plaintext, allowing an attacker who compromises the local machine to easily discover other internal/external servers for lateral movement.
**Prevention:** Set `hashKnownHosts = true;` in `programs.ssh.matchBlocks."*"` in Home Manager configurations to cryptographically hash the hostnames in `~/.ssh/known_hosts`.
