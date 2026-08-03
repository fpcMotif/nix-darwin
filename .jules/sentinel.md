## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-08-03 - Enable SSH Known Hosts Hashing
**Vulnerability:** SSH known_hosts file was stored in plaintext (`HashKnownHosts = false;`).
**Learning:** Plaintext known_hosts files allow attackers who gain local access to easily enumerate other hosts the user connects to, revealing network topology and potential lateral movement targets.
**Prevention:** Set `HashKnownHosts = true;` in SSH configurations to cryptographically hash hostnames and IPs in the known_hosts file.
