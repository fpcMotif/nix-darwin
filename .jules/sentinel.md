## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - SSH HashKnownHosts enabled
**Vulnerability:** SSH known_hosts file stored hostnames in plaintext by default, exposing frequently accessed servers for lateral movement if the machine is compromised.
**Learning:** Enumeration of SSH known hosts is a common post-exploitation technique used by attackers.
**Prevention:** Set `HashKnownHosts = true;` in SSH config so hostnames and IPs are cryptographically hashed in `~/.ssh/known_hosts`.
