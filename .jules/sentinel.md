## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-08-02 - Enable SSH HashKnownHosts
**Vulnerability:** OpenSSH client known_hosts was storing hostnames in plaintext.
**Learning:** Storing known_hosts in plaintext allows enumeration of visited hosts, creating a privacy and lateral-movement risk if the system is compromised.
**Prevention:** Set `HashKnownHosts = true;` in OpenSSH configuration to hash hostnames.
