## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - SSH Known Hosts Hashing
**Vulnerability:** SSH known_hosts file was storing hostnames and IP addresses in plaintext (`HashKnownHosts = false;`).
**Learning:** Unhashed known_hosts files expose network topology and server addresses if the local machine is compromised, facilitating lateral movement for attackers.
**Prevention:** Enforce `HashKnownHosts = true;` in SSH configuration to cryptographically hash the hostnames.
