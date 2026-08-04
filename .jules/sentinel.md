## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.
## 2024-08-04 - SSH Known Hosts Hashing
**Vulnerability:** SSH known_hosts file was stored in plaintext (HashKnownHosts = false).
**Learning:** Storing known hosts in plaintext allows an attacker who compromises the machine to map out the internal network and identify other targets for lateral movement.
**Prevention:** Set `HashKnownHosts = true;` in the SSH configuration to ensure hostnames and IPs are cryptographically hashed.
